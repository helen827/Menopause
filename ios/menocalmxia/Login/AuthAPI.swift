import Foundation

struct SendCodeResponse: Decodable {
    let success: Bool
    let mobile: String?
    let outId: String?
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case success
        case mobile
        case outId = "out_id"
        case requestId = "request_id"
    }
}

struct LoginResponse: Decodable {
    let success: Bool?
    let mobile: String?
    let login: String?
    let blockId: String?
    let database: String?
    let created: Bool?
    let data: EntityBody?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case mobile
        case login
        case blockId = "block_id"
        case database
        case created
        case data
        case message
    }
}

struct EntityBody: Decodable {
    let entityId: String
    let mobile: String
    let login: String

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case mobile
        case login
    }
}

struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}

enum AuthAPIError: LocalizedError {
    case badURL
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "接口地址无效"
        case .server(let message):
            return message
        case .invalidResponse:
            return "服务返回格式异常"
        }
    }
}

final class AuthAPI {
    static let shared = AuthAPI()

    // iOS Simulator can reach the Mac's localhost. Use your Mac LAN IP for a real device.
    var baseURL = URL(string: "http://127.0.0.1:8888")!

    private init() {}

    func sendCode(mobile: String) async throws -> SendCodeResponse {
        try await post(path: "/api/send_code", body: ["mobile": mobile])
    }

    func login(mobile: String, code: String, outId: String?) async throws -> LoginResponse {
        var body = [
            "mobile": mobile,
            "code": code,
        ]
        if let outId, !outId.isEmpty {
            body["out_id"] = outId
        }
        return try await post(path: "/api/login", body: body)
    }

    private func post<Response: Decodable>(path: String, body: [String: String]) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthAPIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AuthAPIError.server(apiError.error ?? apiError.message ?? "请求失败")
            }
            throw AuthAPIError.server("请求失败：\(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}
