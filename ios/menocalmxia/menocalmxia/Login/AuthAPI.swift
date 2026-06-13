import Foundation
import UIKit

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

struct DailyQuoteResponse: Decodable {
    let blockId: String
    let blockKey: String
    let title: String
    let data: DailyQuote

    enum CodingKeys: String, CodingKey {
        case blockId = "block_id"
        case blockKey = "block_key"
        case title
        case data
    }
}

struct DailyQuote: Decodable, Equatable {
    let quote: String
    let source: String
    let speaker: String
    let sourceUrl: String?
    let speakerUrl: String?
    let citationEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case quote
        case source
        case speaker
        case sourceUrl = "source_url"
        case speakerUrl = "speaker_url"
        case citationEnabled = "citation_enabled"
    }
}

struct ChatActivityResponse: Decodable {
    let data: ChatActivityData
}

struct ChatActivityData: Decodable {
    let year: Int
    let month: Int
    let scopeTitle: String
    let checkinDays: [Int]
    let meditationDays: [Int]
    let consecutiveDays: Int
    let practiceCount: Int
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case year
        case month
        case scopeTitle = "scope_title"
        case checkinDays = "checkin_days"
        case meditationDays = "meditation_days"
        case consecutiveDays = "consecutive_days"
        case practiceCount = "practice_count"
        case tags
    }
}

struct MeditationPracticeRecordRequest: Encodable {
    let practiceId: String
    let modeKey: String
    let startedAt: String
    let endedAt: String?
    let durationSeconds: Int
    let cycleCount: Int
    let completed: Bool
    let source: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case practiceId = "practice_id"
        case modeKey = "mode_key"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case cycleCount = "cycle_count"
        case completed
        case source
        case note
    }
}

struct MeditationPracticeRecordResponse: Decodable {
    let success: Bool
    let data: MeditationPracticeRecordData
}

struct MeditationPracticeRecordData: Decodable {
    let practiceId: String
    let userEntityId: String
    let mode: MeditationPracticeModeData
    let startedAt: String
    let endedAt: String?
    let durationSeconds: Int
    let cycleCount: Int
    let completed: Bool
    let source: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case practiceId = "practice_id"
        case userEntityId = "user_entity_id"
        case mode
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case cycleCount = "cycle_count"
        case completed
        case source
        case note
    }
}

struct MeditationPracticeModeData: Decodable {
    let key: String
    let label: String
    let scene: String
    let rhythmText: String

    enum CodingKeys: String, CodingKey {
        case key
        case label
        case scene
        case rhythmText = "rhythm_text"
    }
}

struct MeditationPracticeSummaryResponse: Decodable {
    let data: MeditationPracticeSummaryData
}

struct MeditationPracticeSummaryData: Decodable {
    let year: Int
    let month: Int
    let practiceDays: [Int]
    let practiceCount: Int
    let practiceStreak: Int
    let totalDurationSeconds: Int
    let modeCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case year
        case month
        case practiceDays = "practice_days"
        case practiceCount = "practice_count"
        case practiceStreak = "practice_streak"
        case totalDurationSeconds = "total_duration_seconds"
        case modeCounts = "mode_counts"
    }
}

struct TrendReportLoadResponse: Decodable {
    let success: Bool?
    let data: TrendReportBlockData?
}

struct TrendReportBlockData: Decodable {
    let created: Bool?
    let blockId: String
    let userEntityId: String
    let body: TrendReportBlockBody

    enum CodingKeys: String, CodingKey {
        case created
        case blockId = "block_id"
        case userEntityId = "user_entity_id"
        case body
    }
}

struct TrendReportBlockBody: Decodable {
    let entityType: String?
    let blockId: String?
    let userEntityId: String?
    let title: String?
    let ranges: [String: TrendReportRangeData]

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case blockId = "block_id"
        case userEntityId = "user_entity_id"
        case title
        case ranges
    }
}

struct TrendReportRangeData: Decodable {
    let range: String
    let status: String?
    let anchorDate: String?
    let startDate: String?
    let endDate: String?
    let generatedAt: String?
    let generationMode: String?
    let generationError: String?
    let report: TrendReportPayload?

    enum CodingKeys: String, CodingKey {
        case range
        case status
        case anchorDate = "anchor_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case generatedAt = "generated_at"
        case generationMode = "generation_mode"
        case generationError = "generation_error"
        case report
    }
}

struct TrendReportPayload: Decodable {
    let title: String?
    let period: TrendReportPeriod?
    let overview: TrendReportOverview?
    let frequentSymptoms: TrendReportFrequentSymptoms?
    let trendCards: [TrendReportCard]
    let possibleTriggers: TrendReportTriggerSection?
    let recommendedNextSteps: TrendReportNextStepSection?
    let medicalChecklist: TrendReportMedicalChecklist?

    enum CodingKeys: String, CodingKey {
        case title
        case period
        case overview
        case frequentSymptoms = "frequent_symptoms"
        case trendCards = "trend_cards"
        case possibleTriggers = "possible_triggers"
        case recommendedNextSteps = "recommended_next_steps"
        case medicalChecklist = "medical_checklist"
    }
}

struct TrendReportPeriod: Decodable {
    let activeRange: String?
    let anchorDate: String?
    let startDate: String?
    let endDate: String?
    let recordedDays: Int?
    let totalDays: Int?

    enum CodingKeys: String, CodingKey {
        case activeRange = "active_range"
        case anchorDate = "anchor_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case recordedDays = "recorded_days"
        case totalDays = "total_days"
    }
}

struct TrendReportOverview: Decodable {
    let icon: String?
    let title: String?
    let summary: String?
    let confidence: String?
    let highlightSymptomKeys: [String]?

    enum CodingKeys: String, CodingKey {
        case icon
        case title
        case summary
        case confidence
        case highlightSymptomKeys = "highlight_symptom_keys"
    }
}

struct TrendReportFrequentSymptoms: Decodable {
    let title: String?
    let items: [TrendReportSymptomItem]
}

struct TrendReportSymptomItem: Decodable, Identifiable {
    let key: String
    let label: String
    let icon: String
    let count: Int
    let unit: String?

    var id: String { key }
}

struct TrendReportCard: Decodable, Identifiable {
    let key: String
    let title: String?
    let description: String?
    let dataPoints: [TrendReportDataPoint]

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case description
        case dataPoints = "data_points"
    }
}

struct TrendReportDataPoint: Decodable, Identifiable {
    let label: String
    let date: String?
    let value: Double

    var id: String { "\(label)-\(date ?? "")" }
}

struct TrendReportTriggerSection: Decodable {
    let title: String?
    let items: [TrendReportTriggerItem]
}

struct TrendReportTriggerItem: Decodable, Identifiable {
    let type: String?
    let icon: String
    let style: String?
    let text: String

    var id: String { "\(icon)-\(text)" }
}

struct TrendReportNextStepSection: Decodable {
    let title: String?
    let items: [TrendReportNextStepItem]
}

struct TrendReportNextStepItem: Decodable, Identifiable {
    let key: String
    let title: String
    let desc: String
    let icon: String

    var id: String { key }
}

struct TrendReportMedicalChecklist: Decodable {
    let buttonTitle: String?

    enum CodingKeys: String, CodingKey {
        case buttonTitle = "button_title"
    }
}

struct MedicalChecklistLoadResponse: Decodable {
    let success: Bool?
    let data: MedicalChecklistData?
}

struct MedicalChecklistData: Decodable {
    let blockId: String
    let userEntityId: String
    let range: String
    let rangeLabel: String
    let title: String
    let statusCard: MedicalChecklistStatusCard
    let summarySection: MedicalChecklistSummarySection
    let attentionSection: MedicalChecklistAttentionSection
    let questionSection: MedicalChecklistQuestionSection
    let preview: MedicalChecklistPreview
    let savedState: MedicalChecklistSavedState?
    let historySection: MedicalChecklistHistorySection?
    let meta: MedicalChecklistMeta

    enum CodingKeys: String, CodingKey {
        case blockId = "block_id"
        case userEntityId = "user_entity_id"
        case range
        case rangeLabel = "range_label"
        case title
        case statusCard = "status_card"
        case summarySection = "summary_section"
        case attentionSection = "attention_section"
        case questionSection = "question_section"
        case preview
        case savedState = "saved_state"
        case historySection = "history_section"
        case meta
    }
}

struct MedicalChecklistStatusCard: Decodable {
    let icon: String
    let title: String
    let subtitle: String
}

struct MedicalChecklistSummarySection: Decodable {
    let title: String
    let items: [MedicalChecklistSymptomItem]
}

struct MedicalChecklistSymptomItem: Decodable, Identifiable {
    let key: String
    let label: String
    let icon: String
    let count: Int
    let unit: String
    let previewNote: String

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key
        case label
        case icon
        case count
        case unit
        case previewNote = "preview_note"
    }
}

struct MedicalChecklistAttentionSection: Decodable {
    let title: String
    let items: [MedicalChecklistAttentionItem]
}

struct MedicalChecklistAttentionItem: Decodable, Identifiable {
    let icon: String
    let text: String

    var id: String { "\(icon)-\(text)" }
}

struct MedicalChecklistQuestionSection: Decodable {
    let title: String
    let subtitle: String
    let suggestions: [String]
}

struct MedicalChecklistPreview: Decodable {
    let title: String
    let periodLabel: String
    let symptomLines: [String]
    let questionPrefix: String

    enum CodingKeys: String, CodingKey {
        case title
        case periodLabel = "period_label"
        case symptomLines = "symptom_lines"
        case questionPrefix = "question_prefix"
    }
}

struct MedicalChecklistMeta: Decodable {
    let recordedDays: Int
    let totalDays: Int
    let anchorDate: String?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case recordedDays = "recorded_days"
        case totalDays = "total_days"
        case anchorDate = "anchor_date"
        case generatedAt = "generated_at"
    }
}

struct MedicalChecklistSavedState: Decodable {
    let range: String
    let versionId: String?
    let selectedQuestions: [String]
    let customQuestion: String
    let previewText: String
    let savedAt: String?
    let questionCount: Int?

    enum CodingKeys: String, CodingKey {
        case range
        case versionId = "version_id"
        case selectedQuestions = "selected_questions"
        case customQuestion = "custom_question"
        case previewText = "preview_text"
        case savedAt = "saved_at"
        case questionCount = "question_count"
    }
}

struct MedicalChecklistHistorySection: Decodable {
    let title: String
    let items: [MedicalChecklistSavedState]
}

struct MedicalChecklistSaveRequest: Encodable {
    let range: String
    let selectedQuestions: [String]
    let customQuestion: String
    let previewText: String

    enum CodingKeys: String, CodingKey {
        case range
        case selectedQuestions = "selected_questions"
        case customQuestion = "custom_question"
        case previewText = "preview_text"
    }
}

struct MedicalChecklistSaveResponse: Decodable {
    let success: Bool?
    let data: MedicalChecklistSavedState?
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

    // For local development, point both Simulator and real devices to the Mac's LAN address.
    // If your Wi-Fi changes and the Mac gets a new IP, update this one line.
    var baseURL = URL(string: "http://192.168.3.70:8888")!

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

    func dailyQuote() async throws -> DailyQuoteResponse {
        try await get(path: "/api/app/daily_quote")
    }

    func chatActivity(year: Int, month: Int, tzOffsetMinutes: Int) async throws -> ChatActivityResponse {
        var components = URLComponents()
        components.path = "/api/chat/activity"
        components.queryItems = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "month", value: "\(month)"),
            URLQueryItem(name: "tz_offset_minutes", value: "\(tzOffsetMinutes)"),
        ]
        return try await get(path: components.string ?? "/api/chat/activity")
    }

    func recordMeditationPractice(
        modeKey: String,
        startedAt: String,
        endedAt: String?,
        durationSeconds: Int,
        cycleCount: Int,
        completed: Bool = true,
        note: String? = nil
    ) async throws -> MeditationPracticeRecordResponse {
        try await postJSON(
            path: "/api/meditation/practice/record",
            body: MeditationPracticeRecordRequest(
                practiceId: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                modeKey: modeKey,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                cycleCount: cycleCount,
                completed: completed,
                source: "ios",
                note: note
            )
        )
    }

    func meditationPracticeSummary(year: Int, month: Int, tzOffsetMinutes: Int) async throws -> MeditationPracticeSummaryResponse {
        var components = URLComponents()
        components.path = "/api/meditation/practice/summary"
        components.queryItems = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "month", value: "\(month)"),
            URLQueryItem(name: "tz_offset_minutes", value: "\(tzOffsetMinutes)"),
        ]
        return try await get(path: components.string ?? "/api/meditation/practice/summary")
    }

    func loadTrendReport() async throws -> TrendReportLoadResponse {
        try await get(path: "/api/trend_report/load")
    }

    func loadMedicalChecklist(range: String) async throws -> MedicalChecklistLoadResponse {
        var components = URLComponents()
        components.path = "/api/medical_checklist/load"
        components.queryItems = [
            URLQueryItem(name: "range", value: range),
        ]
        return try await get(path: components.string ?? "/api/medical_checklist/load?range=\(range)")
    }

    func saveMedicalChecklist(range: String, selectedQuestions: [String], customQuestion: String, previewText: String) async throws -> MedicalChecklistSaveResponse {
        try await postJSON(
            path: "/api/medical_checklist/save",
            body: MedicalChecklistSaveRequest(
                range: range,
                selectedQuestions: selectedQuestions,
                customQuestion: customQuestion,
                previewText: previewText
            )
        )
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
