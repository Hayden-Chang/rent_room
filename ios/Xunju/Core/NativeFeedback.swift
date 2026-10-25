import Foundation

struct NativeFeedback: Sendable {
    var transport: any AuthTransport = URLSessionAuthTransport()
    func submit(_ value: JSONValue) async throws -> String {
        let id = value["requestId"].string
        guard !id.isEmpty else { throw CoreFailure(message: "反馈编号无效") }
        var request = URLRequest(url: URL(string: "https://api.keeline.xyz/api/rent-room/feedback")!)
        request.httpMethod = "POST"; request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(value)
        let response = try await transport.send(request)
        guard (200...299).contains(response.status),
              let result = try? JSONDecoder().decode(JSONValue.self, from: response.data), result["receipt"].string == id else {
            throw CoreFailure(message: "反馈未提交成功，内容已保留，请重试。")
        }
        return id
    }
}
