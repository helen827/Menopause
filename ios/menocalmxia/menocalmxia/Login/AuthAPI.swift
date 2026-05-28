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

struct CheckLoginResponse: Decodable {
    let loggedIn: Bool
    let mobile: String?
    let login: String?
    let blockId: String?
    let database: String?

    enum CodingKeys: String, CodingKey {
        case loggedIn = "logged_in"
        case mobile
        case login
        case blockId = "block_id"
        case database
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

struct ChatEnsureResponse: Decodable {
    let chatId: String
    let userEntityId: String?
    let headBlockId: String?
    let tailBlockId: String?
    let totalComments: Int
    let created: Bool

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userEntityId = "user_entity_id"
        case headBlockId = "head_block_id"
        case tailBlockId = "tail_block_id"
        case totalComments = "total_comments"
        case created
    }
}

struct ChatComment: Codable, Identifiable, Equatable {
    let commentId: String
    let role: String?
    let content: String
    let wsBlockIds: [String]
    let createtime: String?
    let systemPrompt: ChatPromptSnapshot?

    var id: String { commentId }

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case role
        case content
        case wsBlockIds = "ws_block_ids"
        case createtime
        case systemPrompt = "system_prompt"
    }
}

struct ChatPromptSnapshot: Codable, Equatable {
    let promptId: String
    let title: String?
    let desc: String?
    let systemPrompt: String?
    let showoff: Bool?
    let createtime: String?

    enum CodingKeys: String, CodingKey {
        case promptId = "prompt_id"
        case title
        case desc
        case systemPrompt = "system_prompt"
        case showoff
        case createtime
    }
}

struct ChatBlockData: Decodable {
    let chatId: String
    let blockId: String?
    let prevBlockId: String?
    let nextBlockId: String?
    let comments: [ChatComment]
    let totalComments: Int

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case blockId = "block_id"
        case prevBlockId = "prev_block_id"
        case nextBlockId = "next_block_id"
        case comments
        case totalComments = "total_comments"
    }
}

struct ChatLoadResponse: Decodable {
    let data: ChatBlockData?

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try? container.decode(ChatBlockData.self, forKey: .data)
    }
}

struct ChatSubmitResponse: Decodable {
    let success: Bool
    let aiSuccess: Bool?
    let chatId: String
    let blockId: String
    let comment: ChatComment
    let assistant: ChatAppendResponse?
    let blockCommentCount: Int
    let totalComments: Int

    enum CodingKeys: String, CodingKey {
        case success
        case aiSuccess = "ai_success"
        case chatId = "chat_id"
        case blockId = "block_id"
        case comment
        case assistant
        case blockCommentCount = "block_comment_count"
        case totalComments = "total_comments"
    }
}

struct ChatAppendResponse: Decodable {
    let chatId: String
    let blockId: String
    let comment: ChatComment
    let blockCommentCount: Int
    let totalComments: Int

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case blockId = "block_id"
        case comment
        case blockCommentCount = "block_comment_count"
        case totalComments = "total_comments"
    }
}

private struct ChatSubmitRequest: Encodable {
    let chatId: String
    let uuid: String
    let content: String
    let wsBlockIds: [String]

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case uuid
        case content
        case wsBlockIds = "ws_block_ids"
    }
}

struct ChatSocketEvent: Decodable {
    let type: String
    let chatId: String?
    let blockId: String?
    let comment: ChatComment?
    let totalComments: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case chatId = "chat_id"
        case blockId = "block_id"
        case comment
        case totalComments = "total_comments"
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

    func checkLogin() async throws -> CheckLoginResponse {
        try await get(path: "/api/check_login")
    }

    func ensureChat() async throws -> ChatEnsureResponse {
        try await postJSON(path: "/api/chat/ensure", body: EmptyRequest())
    }

    func loadChat(chatId: String, lastCommentId: String? = nil) async throws -> ChatLoadResponse {
        var components = URLComponents()
        components.path = "/api/chat/load"
        components.queryItems = [URLQueryItem(name: "chat_id", value: chatId)]
        if let lastCommentId, !lastCommentId.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "last_comment_id", value: lastCommentId))
        }
        return try await get(path: components.string ?? "/api/chat/load?chat_id=\(chatId)")
    }

    func submitChat(chatId: String, content: String, wsBlockIds: [String] = []) async throws -> ChatSubmitResponse {
        let request = ChatSubmitRequest(
            chatId: chatId,
            uuid: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            content: content,
            wsBlockIds: wsBlockIds
        )
        return try await postJSON(path: "/api/chat/submit", body: request)
    }

    func webSocketURL(blockId: String) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/api/ws"
        components?.queryItems = [URLQueryItem(name: "block_id", value: blockId)]
        guard let url = components?.url else {
            throw AuthAPIError.badURL
        }
        return url
    }

    private func post<Response: Decodable>(path: String, body: [String: String]) async throws -> Response {
        try await postJSON(path: path, body: body)
    }

    private func get<Response: Decodable>(path: String) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthAPIError.badURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        return try decodeResponse(data: data, response: response)
    }

    private func postJSON<Response: Decodable, Body: Encodable>(path: String, body: Body) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthAPIError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(data: data, response: response)
    }

    private func decodeResponse<Response: Decodable>(data: Data, response: URLResponse) throws -> Response {
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

private struct EmptyRequest: Encodable {}
