import Foundation

enum ActionPoll {
    private static let terminalSuccess: Set<String> = ["completed", "finished", "done", "success"]
    private static let terminalFailure: Set<String> = ["failed", "error", "cancelled", "canceled"]

    /// Polls `GET /api/v2/actions/{id}` until a terminal status or timeout.
    static func waitForCompletion(
        session: URLSession,
        base: URL,
        actionId: String,
        maxPolls: Int = 120,
        intervalNanoseconds: UInt64 = 500_000_000
    ) async throws {
        let b = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: b + "/api/v2/actions/\(actionId)") else {
            throw OpenFlexureClientError.invalidBaseURL
        }
        for _ in 0..<maxPolls {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw OpenFlexureClientError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let action = try JSONDecoder().decode(OpenFlexureAction.self, from: data)
            let st = (action.status ?? "").lowercased()
            if terminalSuccess.contains(st) { return }
            if terminalFailure.contains(st) {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw OpenFlexureClientError.actionFailed(actionId, body)
            }
            try await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        throw OpenFlexureClientError.actionTimeout(actionId)
    }
}
