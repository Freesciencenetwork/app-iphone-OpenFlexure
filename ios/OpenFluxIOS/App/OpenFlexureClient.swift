import Foundation

nonisolated private struct OpenFlexureThingForm {
    let href: String
    let opValues: [String]
    let methodName: String?
    let contextPath: String

    var isInvokeAction: Bool {
        opValues.contains("invokeaction") || methodName?.uppercased() == "POST"
    }

    var searchHaystack: String {
        ([contextPath, href] + opValues + [methodName ?? ""])
            .joined(separator: " ")
            .lowercased()
    }
}

/// Thin OpenFlexure microscope server v2 HTTP client.
actor OpenFlexureClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, timeoutSeconds: TimeInterval = 15) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds * 4
        self.session = URLSession(configuration: config)
    }

    private func url(_ path: String) -> URL {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let p = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let u = URL(string: base + "/" + p) else {
            fatalError("invalid URL join")
        }
        return u
    }

    private func url(fromHref href: String) throws -> URL {
        if let absolute = URL(string: href), absolute.scheme != nil {
            return absolute
        }
        if href.hasPrefix("/") {
            guard let absolute = URL(string: href, relativeTo: baseURL)?.absoluteURL else {
                throw OpenFlexureClientError.invalidBaseURL
            }
            return absolute
        }
        return url(href)
    }

    private func jsonObject(for path: String) async throws -> Any {
        let requestURL = url(path)
        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func collectForms(from object: Any, path: [String] = []) -> [OpenFlexureThingForm] {
        var forms: [OpenFlexureThingForm] = []

        if let dictionary = object as? [String: Any] {
            if let formObjects = dictionary["forms"] as? [[String: Any]] {
                for formObject in formObjects {
                    guard let href = formObject["href"] as? String else { continue }

                    let opField = formObject["op"]
                    let opValues: [String]
                    if let opString = opField as? String {
                        opValues = [opString.lowercased()]
                    } else if let opList = opField as? [String] {
                        opValues = opList.map { $0.lowercased() }
                    } else {
                        opValues = []
                    }

                    forms.append(
                        OpenFlexureThingForm(
                            href: href,
                            opValues: opValues,
                            methodName: formObject["htv:methodName"] as? String,
                            contextPath: path.joined(separator: "/")
                        )
                    )
                }
            }

            for (key, value) in dictionary {
                forms.append(contentsOf: collectForms(from: value, path: path + [key]))
            }
        } else if let list = object as? [Any] {
            for (index, value) in list.enumerated() {
                forms.append(contentsOf: collectForms(from: value, path: path + ["[\(index)]"]))
            }
        }

        return forms
    }

    private func actionPath(
        matching ruleSets: [[String]],
        in forms: [OpenFlexureThingForm]
    ) -> String? {
        for terms in ruleSets {
            if let match = forms.first(where: { form in
                let haystack = form.searchHaystack
                return terms.allSatisfy { haystack.contains($0.lowercased()) }
            }) {
                return match.href
            }
        }
        return nil
    }

    func discoverAutomationCapabilities() async throws -> MicroscopeAutomationCapabilities {
        let thingDescription = try await jsonObject(for: "api/v2/")
        let actionForms = collectForms(from: thingDescription).filter { $0.isInvokeAction }

        return MicroscopeAutomationCapabilities(
            autofocusActionPath: actionPath(
                matching: [
                    ["autofocus", "fast_autofocus"],
                    ["autofocus", "fast-autofocus"],
                    ["autofocus", "looping_autofocus"],
                    ["autofocus"]
                ],
                in: actionForms
            ),
            cameraStageCalibrationActionPath: actionPath(
                matching: [
                    ["camera-stage-mapping", "calibrate_xy"],
                    ["camera_stage_mapping", "calibrate_xy"],
                    ["camera-stage-mapping", "calibrate"],
                    ["camera_stage_mapping", "calibrate"]
                ],
                in: actionForms
            ),
            autoGainExposureActionPath: actionPath(
                matching: [
                    ["gain", "exposure"],
                    ["gain", "shutter"],
                    ["auto", "exposure"],
                    ["auto", "shutter"]
                ],
                in: actionForms
            ),
            cameraAutoCalibrationActionPath: actionPath(
                matching: [
                    ["auto", "calib"],
                    ["flat", "field"],
                    ["white", "balance"]
                ],
                in: actionForms
            )
        )
    }

    func invokeDiscoveredAction(href: String) async throws {
        let requestURL = try url(fromHref: href)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        if let action = try? JSONDecoder().decode(OpenFlexureAction.self, from: data),
           let id = action.id,
           !id.isEmpty {
            try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
        }
    }

    func getStagePosition() async throws -> StagePosition {
        let u = url("api/v2/instrument/state/stage/position")
        var req = URLRequest(url: u)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(StagePosition.self, from: data)
    }

    /// POST stage move; polls until the returned action completes.
    func moveStage(_ body: StageMoveRequest) async throws {
        let u = url("api/v2/actions/stage/move/")
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
        guard let id = action.id, !id.isEmpty else { throw OpenFlexureClientError.noActionId }
        try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
    }

    func zeroStage() async throws {
        let u = url("api/v2/actions/stage/zero/")
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("{}".utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
        guard let id = action.id, !id.isEmpty else { throw OpenFlexureClientError.noActionId }
        try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
    }

    func fetchSnapshotJPEG() async throws -> Data {
        let u = url("api/v2/streams/snapshot")
        var req = URLRequest(url: u)
        req.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard data.count >= 2, data[0] == 0xFF, data[1] == 0xD8 else {
            throw OpenFlexureClientError.notJPEG
        }
        return data
    }

    func capture(filename: String) async throws {
        let u = url("api/v2/actions/camera/capture/")
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(CaptureRequest(filename: filename))
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
        guard let id = action.id, !id.isEmpty else { throw OpenFlexureClientError.noActionId }
        try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
    }

    func startGPUPreview(window: [Int]) async throws {
        let u = url("api/v2/actions/camera/preview/start/")
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(PreviewStartRequest(window: window))
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
        guard let id = action.id, !id.isEmpty else { throw OpenFlexureClientError.noActionId }
        try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
    }

    func stopGPUPreview() async throws {
        let u = url("api/v2/actions/camera/preview/stop/")
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = Data("{}".utf8)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
        guard let id = action.id, !id.isEmpty else { throw OpenFlexureClientError.noActionId }
        try await ActionPoll.waitForCompletion(session: session, base: baseURL, actionId: id)
    }

    /// Lightweight connectivity check.
    func ping() async throws {
        let u = url("api/v2/instrument/state")
        var req = URLRequest(url: u)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenFlexureClientError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}
