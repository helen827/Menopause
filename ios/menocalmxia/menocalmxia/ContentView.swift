//
//  ContentView.swift
//  menocalmxia
//
//  Created by Jiaying He on 2026/5/22.
//

import SwiftUI
import Combine

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var sessionStore = SessionStore()

    var body: some View {
        Group {
            if sessionStore.isCheckingLogin {
                LaunchLoadingView()
            } else if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if sessionStore.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(sessionStore)
        .task {
            await sessionStore.refreshFromCookie()
        }
    }
}

#Preview {
    ContentView()
}

struct UserSession: Codable, Equatable {
    let mobile: String
    let login: String
    let blockId: String
    let database: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published private(set) var isCheckingLogin = true

    private let defaults = UserDefaults.standard
    private let storageKey = "menocalmxia.userSession"

    init() {
        session = Self.loadSession(defaults: defaults, key: storageKey)
    }

    var isLoggedIn: Bool {
        session != nil
    }

    func save(loginResponse: LoginResponse, fallbackMobile: String) {
        let nextSession = UserSession(
            mobile: loginResponse.mobile ?? loginResponse.data?.mobile ?? fallbackMobile,
            login: loginResponse.login ?? loginResponse.data?.login ?? "",
            blockId: loginResponse.blockId ?? loginResponse.data?.entityId ?? "",
            database: loginResponse.database ?? ""
        )
        session = nextSession

        if let data = try? JSONEncoder().encode(nextSession) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func save(checkResponse: CheckLoginResponse) {
        guard checkResponse.loggedIn else {
            signOut()
            return
        }

        let nextSession = UserSession(
            mobile: checkResponse.mobile ?? "",
            login: checkResponse.login ?? "",
            blockId: checkResponse.blockId ?? "",
            database: checkResponse.database ?? ""
        )
        session = nextSession

        if let data = try? JSONEncoder().encode(nextSession) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func refreshFromCookie() async {
        isCheckingLogin = true
        defer { isCheckingLogin = false }

        do {
            let response = try await AuthAPI.shared.checkLogin()
            save(checkResponse: response)
        } catch {
            signOut()
        }
    }

    func signOut() {
        session = nil
        defaults.removeObject(forKey: storageKey)
    }

    private static func loadSession(defaults: UserDefaults, key: String) -> UserSession? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white.opacity(0.94))
                        .frame(width: 104, height: 104)
                        .shadow(color: Color(red: 0.46, green: 0.34, blue: 0.41).opacity(0.2), radius: 34, y: 22)

                    FlowerMark()
                        .fill(Color(red: 0.64, green: 0.48, blue: 0.56))
                        .frame(width: 56, height: 46)
                }
                .rotationEffect(.degrees(2))

                Text("潮安")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.17))

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color(red: 0.64, green: 0.48, blue: 0.56))

                    Text("正在启动...")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                }
                .padding(.top, 6)

                Text("检查登录状态和本地会话")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
            }
            .padding(28)
        }
    }
}

struct AppStartInfo: Identifiable {
    let id = UUID()
    let title: String
    let desc: String
    let icon: String
    let flags: [AppStartFlag]
}

struct AppStartFlag: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
}

enum AppStartData {
    static let pages: [AppStartInfo] = [
        AppStartInfo(
            title: "先看懂更年期",
            desc: "帮助你理解身体变化，减少焦虑",
            icon: "leaf.fill",
            flags: [
                AppStartFlag(label: "潮热", icon: "thermometer.sun.fill"),
                AppStartFlag(label: "脑雾", icon: "cloud.fill"),
                AppStartFlag(label: "漏尿", icon: "drop.fill"),
                AppStartFlag(label: "脑雾", icon: "cloud.fill"),
            ]
        ),
        AppStartInfo(
            title: "每天记录",
            desc: "和AI对话记录症状、情绪和生活方式，自动生成报告和趋势",
            icon: "text.bubble.fill",
            flags: []
        ),
        AppStartInfo(
            title: "呼吸练习",
            desc: "通过呼吸冥想方式改善症状",
            icon: "wind",
            flags: []
        ),
    ]
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selection = 0

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("跳过") {
                        onFinish()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.39, blue: 0.43))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                TabView(selection: $selection) {
                    ForEach(Array(AppStartData.pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingCard(info: page)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                PageDots(count: AppStartData.pages.count, selection: selection)
                    .padding(.bottom, 22)

                Button(selection == AppStartData.pages.count - 1 ? "开始访问" : "下一步") {
                    if selection == AppStartData.pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            selection += 1
                        }
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            }
        }
    }
}

private struct OnboardingCard: View {
    let info: AppStartInfo

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 36)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.white.opacity(0.9))
                    .frame(width: 132, height: 132)
                    .shadow(color: Color(red: 0.46, green: 0.34, blue: 0.41).opacity(0.22), radius: 36, y: 24)

                Image(systemName: info.icon)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))
            }

            VStack(spacing: 14) {
                Text(info.title)
                    .font(.system(size: 34, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.17))

                Text(info.desc)
                    .font(.system(size: 19, weight: .bold))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                    .padding(.horizontal, 8)
            }

            if !info.flags.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(info.flags) { flag in
                        HStack(spacing: 8) {
                            Image(systemName: flag.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(flag.label)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.42))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.white.opacity(0.78), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 28)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let selection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? Color(red: 0.18, green: 0.16, blue: 0.18) : Color(red: 0.79, green: 0.72, blue: 0.76))
                    .frame(width: index == selection ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selection)
            }
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(red: 0.18, green: 0.16, blue: 0.18), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        TabView {
            AIChatView()
            .tabItem {
                Label("AI对话", systemImage: "bubble.left.and.bubble.right.fill")
            }

            PlaceholderTab(
                title: "社区内容",
                subtitle: "查看经验分享和精选内容",
                symbol: "person.3.fill"
            )
            .tabItem {
                Label("社区内容", systemImage: "person.3.fill")
            }

            PlaceholderTab(
                title: "冥想练习",
                subtitle: "用呼吸和冥想放松身体",
                symbol: "wind"
            )
            .tabItem {
                Label("冥想练习", systemImage: "wind")
            }

            MineTab()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(Color(red: 0.64, green: 0.48, blue: 0.56))
    }
}

private struct PlaceholderTab: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 18) {
                    Image(systemName: symbol)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))
                        .frame(width: 96, height: 96)
                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color(red: 0.46, green: 0.34, blue: 0.41).opacity(0.16), radius: 24, y: 14)

                    Text(title)
                        .font(.system(size: 30, weight: .black))

                    Text(subtitle)
                        .font(.system(size: 17, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                }
                .padding(28)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AIChatView: View {
    @StateObject private var viewModel = AIChatViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    ChatStatusHeader(viewModel: viewModel)
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    Divider()
                        .opacity(0.45)
                        .padding(.top, 12)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.isLoading && viewModel.comments.isEmpty {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .tint(Color(red: 0.64, green: 0.48, blue: 0.56))
                                        Text("正在加载对话...")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 280)
                                } else {
                                    if viewModel.shouldShowDailyGreeting {
                                        DailyGreetingBubble()
                                    }

                                    ForEach(viewModel.comments) { comment in
                                        ChatBubble(comment: comment)
                                            .id(comment.id)
                                    }

                                    if viewModel.comments.isEmpty {
                                        EmptyChatState()
                                            .padding(.top, 20)
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                        }
                        .onChange(of: viewModel.comments) { _, comments in
                            guard let last = comments.last else { return }
                            withAnimation(.easeOut(duration: 0.22)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    ChatComposer(
                        text: $viewModel.draft,
                        isSending: viewModel.isSending,
                        canSend: viewModel.canSend
                    ) {
                        Task { await viewModel.send() }
                    }
                }
            }
            .navigationTitle("AI对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.start()
            }
            .onDisappear {
                viewModel.stopSocket()
            }
        }
    }
}

@MainActor
private final class AIChatViewModel: ObservableObject {
    @Published var comments: [ChatComment] = []
    @Published var draft = ""
    @Published var status = "准备连接"
    @Published var chatId: String?
    @Published var blockId: String?
    @Published var totalComments = 0
    @Published var isLoading = false
    @Published var isSending = false
    @Published var isSocketConnected = false

    private var socketTask: URLSessionWebSocketTask?
    private var socketLoopTask: Task<Void, Never>?
    private var hasStarted = false

    var canSend: Bool {
        chatId != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var shortChatId: String {
        guard let chatId else { return "未创建" }
        return "\(chatId.prefix(8))..."
    }

    var shouldShowDailyGreeting: Bool {
        !comments.contains { comment in
            guard let date = Self.parseDate(comment.createtime) else {
                return false
            }
            return Calendar.current.isDateInToday(date)
        }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let chat = try await AuthAPI.shared.ensureChat()
            chatId = chat.chatId
            totalComments = chat.totalComments
            status = chat.created ? "已创建新对话" : "已连接对话"
            try await loadLatest(chatId: chat.chatId)
            connectSocket(blockId: chat.chatId)
        } catch {
            status = error.localizedDescription
        }
    }

    func send() async {
        guard let chatId else {
            status = "请先等待对话初始化"
            return
        }
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        do {
            let response = try await AuthAPI.shared.submitChat(chatId: chatId, content: content)
            applySubmit(response)
            draft = ""
            status = "已发送"
        } catch {
            status = error.localizedDescription
        }
        isSending = false
    }

    func stopSocket() {
        socketLoopTask?.cancel()
        socketLoopTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        isSocketConnected = false
    }

    private func loadLatest(chatId: String) async throws {
        let response = try await AuthAPI.shared.loadChat(chatId: chatId)
        guard let data = response.data else {
            comments = []
            blockId = nil
            totalComments = 0
            return
        }
        comments = uniqueComments(data.comments)
        blockId = data.blockId
        totalComments = data.totalComments
    }

    private func connectSocket(blockId: String) {
        stopSocket()

        do {
            let url = try AuthAPI.shared.webSocketURL(blockId: blockId)
            let task = URLSession.shared.webSocketTask(with: url)
            socketTask = task
            task.resume()
            isSocketConnected = true
            socketLoopTask = Task { [weak self, task] in
                await self?.receiveSocketMessages(from: task)
            }
        } catch {
            status = error.localizedDescription
        }
    }

    private func receiveSocketMessages(from task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handleSocketText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleSocketText(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                isSocketConnected = false
                return
            }
        }
    }

    private func handleSocketText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(ChatSocketEvent.self, from: data) else {
            return
        }
        guard event.type == "chat.submit", let comment = event.comment else {
            return
        }
        appendUnique(comment)
        if let blockId = event.blockId {
            self.blockId = blockId
        }
        if let totalComments = event.totalComments {
            self.totalComments = totalComments
        }
        status = "收到新消息"
    }

    private func applySubmit(_ response: ChatSubmitResponse) {
        appendUnique(response.comment)
        blockId = response.blockId
        totalComments = response.totalComments
        if let assistant = response.assistant {
            appendUnique(assistant.comment)
            blockId = assistant.blockId
            totalComments = assistant.totalComments
        }
    }

    private func appendUnique(_ comment: ChatComment) {
        guard !comments.contains(where: { $0.commentId == comment.commentId }) else {
            return
        }
        comments.append(comment)
    }

    private func uniqueComments(_ comments: [ChatComment]) -> [ChatComment] {
        var seen = Set<String>()
        return comments.filter { comment in
            seen.insert(comment.commentId).inserted
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }
        if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: value) {
            return date
        }
        return ISO8601DateFormatter.withInternetDateTime.date(from: value)
    }
}

private struct ChatStatusHeader: View {
    @ObservedObject var viewModel: AIChatViewModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.86))
                    .frame(width: 52, height: 52)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.status)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.22))
                    .lineLimit(1)

                Text("chat: \(viewModel.shortChatId) · \(viewModel.totalComments) 条")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.50, green: 0.43, blue: 0.47))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isSocketConnected ? Color(red: 0.09, green: 0.47, blue: 0.28) : Color(red: 0.68, green: 0.35, blue: 0.08))
                    .frame(width: 8, height: 8)
                Text(viewModel.isSocketConnected ? "WS" : "离线")
                    .font(.system(size: 12, weight: .black))
            }
            .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(0.72), in: Capsule())
        }
    }
}

private struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))

            Text("开始你的第一条记录")
                .font(.system(size: 24, weight: .black))

            Text("可以记录症状、情绪、睡眠或今天想问 AI 的问题。")
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                .padding(.horizontal, 24)
        }
    }
}

private struct DailyGreetingBubble: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今天过得怎么样？可以随便说说身体、心情或者睡眠，想到什么说什么就好。")
                .font(.system(size: 16, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                }

            Text("daily greeting")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 42)
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ChatBubble: View {
    let comment: ChatComment

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(comment.content)
                .font(.system(size: 16, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(isAssistant ? Color(red: 0.18, green: 0.16, blue: 0.18) : .white)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(isAssistant ? .white.opacity(0.88) : Color(red: 0.18, green: 0.16, blue: 0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isAssistant ? Color(red: 0.91, green: 0.86, blue: 0.89) : .clear, lineWidth: 1)
                }

            Text("\(comment.role ?? "user") · \(comment.commentId.prefix(8))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
        }
        .frame(maxWidth: .infinity, alignment: isAssistant ? .leading : .trailing)
        .padding(.leading, isAssistant ? 0 : 42)
        .padding(.trailing, isAssistant ? 42 : 0)
    }

    private var isAssistant: Bool {
        comment.role == "assistant"
    }
}

private struct ChatComposer: View {
    @Binding var text: String
    let isSending: Bool
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("记录今天的状态...", text: $text, axis: .vertical)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                }

            Button {
                onSend()
            } label: {
                if isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 48, height: 48)
                }
            }
            .foregroundStyle(.white)
            .background(canSend ? Color(red: 0.18, green: 0.16, blue: 0.18) : Color(red: 0.70, green: 0.65, blue: 0.68), in: Circle())
            .disabled(!canSend)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.white.opacity(0.72))
    }
}

private struct MineTab: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))
                        .padding(.bottom, 8)

                    Text("我的")
                        .font(.system(size: 30, weight: .black))

                    if let session = sessionStore.session {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("mobile: \(session.mobile)")
                            Text("login: \(session.login)")
                            Text("block_id: \(session.blockId)")
                            Text("database: \(session.database)")
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(red: 0.26, green: 0.21, blue: 0.24))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 12)
                    }

                    Button("退出登录") {
                        sessionStore.signOut()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(red: 0.18, green: 0.16, blue: 0.18), in: Capsule())
                    .padding(.top, 12)
                }
                .padding(24)
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
