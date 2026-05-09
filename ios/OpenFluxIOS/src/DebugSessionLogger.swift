import Foundation

/// Fire-and-forget NDJSON to Cursor debug ingest (works when Simulator can reach Mac localhost).
enum DebugSessionLogger {
    private static let sessionId = "551ec3"
    private static let endpoint = URL(string: "http://127.0.0.1:7254/ingest/191a84ab-8bf5-40cf-ab33-3f21c3060ba7")!

    private struct Payload: Encodable {
        let sessionId: String
        let timestamp: Int64
        let hypothesisId: String
        let location: String
        let message: String
        let data: [String: String]
    }

    // #region agent log
    static func log(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
        let payload = Payload(
            sessionId: sessionId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            hypothesisId: hypothesisId,
            location: location,
            message: message,
            data: data
        )
        guard let body = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(sessionId, forHTTPHeaderField: "X-Debug-Session-Id")
        req.httpBody = body
        URLSession.shared.dataTask(with: req).resume()
        #if DEBUG
        if let s = String(data: body, encoding: .utf8) {
            print("[agent-debug] \(s)")
        }
        #endif
    }
    // #endregion agent log
}
