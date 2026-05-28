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
                ProgressView("正在检查登录状态...")
                    .font(.system(size: 15, weight: .semibold))
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
    @Published private(set) var isCheckingLogin = false

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
            PlaceholderTab(
                title: "AI对话",
                subtitle: "记录症状、情绪和生活方式",
                symbol: "sparkles"
            )
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
