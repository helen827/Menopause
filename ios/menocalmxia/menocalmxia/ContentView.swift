//
//  ContentView.swift
//  menocalmxia
//
//  Created by Jiaying He on 2026/5/22.
//

import AVFoundation
import Combine
import Photos
import SwiftUI
import UIKit
import UserNotifications

private extension Notification.Name {
    static let meditationPracticeDidSave = Notification.Name("meditationPracticeDidSave")
}

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

                    Image("LoginLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                }

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
                    .foregroundStyle(AppTheme.inkSoft)
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
                    .shadow(color: AppTheme.rose.opacity(0.18), radius: 36, y: 24)

                Image(systemName: info.icon)
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(AppTheme.roseStrong)
            }

            VStack(spacing: 14) {
                Text(info.title)
                    .font(.system(size: 34, weight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.ink)

                Text(info.desc)
                    .font(.system(size: 19, weight: .bold))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.muted)
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
                        .foregroundStyle(AppTheme.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.cardStroke, lineWidth: 1)
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
                    .fill(index == selection ? AppTheme.roseStrong : Color.white.opacity(0.56))
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
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: AppTheme.rose.opacity(0.12), radius: 18, y: 10)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.26)
        appearance.shadowColor = .clear

        let normalIcon = UIColor(red: 0.45, green: 0.40, blue: 0.48, alpha: 0.92)
        let selectedIcon = UIColor(red: 0.80, green: 0.47, blue: 0.60, alpha: 1)
        let item = appearance.stackedLayoutAppearance
        item.normal.iconColor = normalIcon
        item.normal.titleTextAttributes = [.foregroundColor: normalIcon]
        item.selected.iconColor = selectedIcon
        item.selected.titleTextAttributes = [.foregroundColor: selectedIcon]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            AIChatView()
            .tabItem {
                Label("AI对话", systemImage: "bubble.left.and.bubble.right.fill")
            }

            MeditationBreathingView()
            .tabItem {
                Label("冥想练习", systemImage: "wind")
            }

            NavigationStack {
                TrendReportView(showsBackButton: false)
            }
            .tabItem {
                Label("趋势", systemImage: "chart.xyaxis.line")
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

private struct MeditationBreathingView: View {
    @State private var selectedMode = 1
    @State private var isRunning = true
    @State private var soundEnabled = true
    @State private var showCompletionSummary = false
    @State private var didInitializePracticeSession = false
    @State private var sessionPracticeId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    @State private var sessionModeIndex = 1
    @State private var sessionStartedAt = Date()
    @State private var activeSegmentStartedAt: Date?
    @State private var accumulatedRunningSeconds: TimeInterval = 0
    @State private var lastSavedDurationSeconds = 0
    @StateObject private var audioPlayer = MeditationAudioPlayer()

    private let modes = BreathMode.samples

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    Image(currentMode.backgroundImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.safeAreaInsets.bottom + 140)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.18),
                                    .black.opacity(0.40),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea()
                }
                .allowsHitTesting(false)

                BreathModeBackground(mode: currentMode)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                    )
                    .offset(y: -(geometry.safeAreaInsets.top / 2))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                if value.translation.width < -30 {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                        selectedMode = (selectedMode + 1) % modes.count
                                    }
                                } else if value.translation.width > 30 {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                        selectedMode = (selectedMode + modes.count - 1) % modes.count
                                    }
                                }
                            }
                    )

                LinearGradient(
                    colors: [
                        .black.opacity(0.22),
                        .clear,
                        .black.opacity(0.72),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar(mode: currentMode)
                        .padding(.horizontal, 22)
                        .padding(.top, geometry.safeAreaInsets.top + 14)

                    Spacer(minLength: 18)

                    BreathingOrb(mode: currentMode, isRunning: isRunning)
                        .frame(width: min(geometry.size.width * 0.72, 304), height: min(geometry.size.width * 0.72, 304))
                        .padding(.bottom, 24)

                    modeTitle(currentMode)
                        .padding(.bottom, 20)

                    modeSwitcher
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)

                    bottomControls
                        .padding(.horizontal, 22)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                }

                if showCompletionSummary {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    completionSummaryOverlay
                        .padding(.horizontal, 20)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .toolbarBackground(.hidden, for: .tabBar)
            .preferredColorScheme(.dark)
            .onAppear {
                beginSessionIfNeeded()
                audioPlayer.play(fileName: currentMode.audioFileName, enabled: soundEnabled && isRunning)
            }
            .onDisappear {
                audioPlayer.stop()
                Task {
                    await saveCurrentPractice(resetFor: selectedMode)
                }
            }
            .onChange(of: selectedMode) { newMode in
                let previousMode = sessionModeIndex
                Task {
                    await saveCurrentPractice(resetFor: newMode, modeIndexOverride: previousMode)
                }
                audioPlayer.play(fileName: currentMode.audioFileName, enabled: soundEnabled && isRunning)
            }
            .onChange(of: soundEnabled) { _ in
                audioPlayer.setEnabled(soundEnabled && isRunning, fileName: currentMode.audioFileName)
            }
            .onChange(of: isRunning) { running in
                updateRunningState(running)
                audioPlayer.setEnabled(soundEnabled && isRunning, fileName: currentMode.audioFileName)
            }
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                guard didInitializePracticeSession, isRunning else { return }
                Task {
                    await autosaveCurrentPracticeIfNeeded()
                }
            }
        }
    }

    private var currentMode: BreathMode {
        modes[selectedMode]
    }

    private func beginSessionIfNeeded() {
        guard !didInitializePracticeSession else { return }
        didInitializePracticeSession = true
        sessionPracticeId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        sessionModeIndex = selectedMode
        sessionStartedAt = Date()
        accumulatedRunningSeconds = 0
        lastSavedDurationSeconds = 0
        activeSegmentStartedAt = isRunning ? Date() : nil
    }

    private func updateRunningState(_ running: Bool) {
        beginSessionIfNeeded()
        let now = Date()
        if running {
            activeSegmentStartedAt = now
        } else if let activeSegmentStartedAt {
            accumulatedRunningSeconds += now.timeIntervalSince(activeSegmentStartedAt)
            self.activeSegmentStartedAt = nil
        }
    }

    private func saveCurrentPractice(resetFor newModeIndex: Int, modeIndexOverride: Int? = nil) async {
        beginSessionIfNeeded()

        let now = Date()
        let roundedSeconds = currentRoundedDuration(now: now)
        let modeIndex = modeIndexOverride ?? sessionModeIndex
        if roundedSeconds >= 2 {
            let mode = modes[modeIndex]
            let cycleCount = max(1, Int((Double(roundedSeconds) / max(mode.totalDuration, 1)).rounded()))
            let formatter = ISO8601DateFormatter()
            let startedAt = formatter.string(from: sessionStartedAt)
            let endedAt = formatter.string(from: now)
            do {
                _ = try await AuthAPI.shared.recordMeditationPractice(
                    practiceId: sessionPracticeId,
                    modeKey: mode.apiModeKey,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    durationSeconds: roundedSeconds,
                    cycleCount: cycleCount,
                    completed: true
                )
                lastSavedDurationSeconds = roundedSeconds
                NotificationCenter.default.post(name: .meditationPracticeDidSave, object: nil)
                print("[Meditation] saved practice \(sessionPracticeId) duration=\(roundedSeconds)s mode=\(mode.apiModeKey)")
            } catch {
                print("[Meditation] save failed for \(sessionPracticeId): \(error)")
            }
        }

        sessionModeIndex = newModeIndex
        sessionPracticeId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        sessionStartedAt = now
        accumulatedRunningSeconds = 0
        lastSavedDurationSeconds = 0
        activeSegmentStartedAt = isRunning ? now : nil
    }

    private func autosaveCurrentPracticeIfNeeded() async {
        let now = Date()
        let roundedSeconds = currentRoundedDuration(now: now)
        guard roundedSeconds >= 2, roundedSeconds > lastSavedDurationSeconds else { return }
        let mode = modes[sessionModeIndex]
        let cycleCount = max(1, Int((Double(roundedSeconds) / max(mode.totalDuration, 1)).rounded()))
        let formatter = ISO8601DateFormatter()
        let startedAt = formatter.string(from: sessionStartedAt)
        let endedAt = formatter.string(from: now)
        do {
            _ = try await AuthAPI.shared.recordMeditationPractice(
                practiceId: sessionPracticeId,
                modeKey: mode.apiModeKey,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: roundedSeconds,
                cycleCount: cycleCount,
                completed: true
            )
            lastSavedDurationSeconds = roundedSeconds
            NotificationCenter.default.post(name: .meditationPracticeDidSave, object: nil)
            print("[Meditation] autosaved practice \(sessionPracticeId) duration=\(roundedSeconds)s mode=\(mode.apiModeKey)")
        } catch {
            print("[Meditation] autosave failed for \(sessionPracticeId): \(error)")
        }
    }

    private func currentRoundedDuration(now: Date = Date()) -> Int {
        var totalSeconds = accumulatedRunningSeconds
        if let activeSegmentStartedAt {
            totalSeconds += now.timeIntervalSince(activeSegmentStartedAt)
        }
        return Int(totalSeconds.rounded())
    }

    private func topBar(mode: BreathMode) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("呼吸练习")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)

                Text("\(mode.title) · \(mode.rhythmText)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()
        }
    }

    private func modeTitle(_ mode: BreathMode) -> some View {
        VStack(spacing: 9) {
            Text(mode.sceneName)
                .font(.system(size: 29, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(mode.sceneLabel)
                .font(.system(size: 13, weight: .medium))
                .tracking(6)
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(1)

            Text(mode.compactRhythm)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.84))
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(.white.opacity(0.13), in: Capsule())
                .overlay {
                    Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
                }
        }
        .padding(.horizontal, 24)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedMode = index
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .black))
                        Text(mode.shortRhythm)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(index == selectedMode ? Color(red: 0.10, green: 0.14, blue: 0.20) : .white.opacity(0.78))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(index == selectedMode ? .white.opacity(0.92) : .white.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule().stroke(.white.opacity(index == selectedMode ? 0.22 : 0.13), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.title)，\(mode.rhythmText)")
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(modes.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedMode ? .white : .white.opacity(0.32))
                        .frame(width: index == selectedMode ? 28 : 7, height: 7)
                        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: selectedMode)
                }
            }

            HStack(spacing: 16) {
                BreathingControlButton(symbol: "chevron.left", label: "上一个模式") {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        selectedMode = (selectedMode + modes.count - 1) % modes.count
                    }
                }

                if isRunning {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isRunning = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 15, weight: .black))
                            Text("暂停")
                                .font(.system(size: 17, weight: .black))
                        }
                        .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.20))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(.white.opacity(0.94), in: Capsule())
                        .shadow(color: currentMode.accent.opacity(0.30), radius: 22, y: 10)
                    }
                    .accessibilityLabel("暂停呼吸练习")

                    BreathingControlButton(
                        symbol: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        label: soundEnabled ? "关闭声音" : "打开声音"
                    ) {
                        soundEnabled.toggle()
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showCompletionSummary = false
                            isRunning = true
                        }
                    } label: {
                        Text("继续")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.20))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(.white.opacity(0.94), in: Capsule())
                            .shadow(color: currentMode.accent.opacity(0.18), radius: 18, y: 10)
                    }
                    .accessibilityLabel("继续呼吸练习")

                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            showCompletionSummary = true
                        }
                    } label: {
                        Text("结束")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay {
                                Capsule().stroke(.white.opacity(0.22), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel("结束本次练习")
                }

                BreathingControlButton(symbol: "chevron.right", label: "下一个模式") {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        selectedMode = (selectedMode + 1) % modes.count
                    }
                }
            }
        }
    }

    private var completionSummaryOverlay: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.40))
                    .frame(width: 114, height: 114)

                Circle()
                    .fill(Color(red: 0.58, green: 0.48, blue: 0.63))
                    .frame(width: 50, height: 50)

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 14) {
                Text("今天你完成了")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color(red: 0.42, green: 0.40, blue: 0.49))

                Text(formattedDurationText(from: currentRoundedDuration()))
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(Color(red: 0.26, green: 0.25, blue: 0.36))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("每一次停下来照顾自己，都值得被记录。")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.54, blue: 0.62))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showCompletionSummary = false
                        isRunning = true
                    }
                } label: {
                    Text("继续练习")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(red: 0.26, green: 0.25, blue: 0.36))
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(.white.opacity(0.88), in: Capsule())
                        .overlay {
                            Capsule().stroke(.white.opacity(0.92), lineWidth: 1.5)
                        }
                }

                Button {
                    Task {
                        await saveCurrentPractice(resetFor: selectedMode)
                        await MainActor.run {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                showCompletionSummary = false
                            }
                        }
                    }
                } label: {
                    Text("完成并记录")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.66, green: 0.60, blue: 0.77),
                                    Color(red: 0.45, green: 0.50, blue: 0.72),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
        .frame(maxWidth: 760)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1.5)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
    }

    private func formattedDurationText(from totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分\(remainingSeconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(remainingSeconds)秒"
        }
        return "\(remainingSeconds)秒"
    }
}

private struct BreathingControlButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.15), in: Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
        .accessibilityLabel(label)
    }
}

@MainActor
private final class MeditationAudioPlayer: NSObject, ObservableObject {
    private var player: AVAudioPlayer?
    private var currentFileName: String?

    func play(fileName: String, enabled: Bool) {
        guard enabled else {
            pause()
            return
        }

        if currentFileName == fileName, let player {
            if !player.isPlaying {
                player.play()
            }
            return
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let nextPlayer = try AVAudioPlayer(contentsOf: url)
            nextPlayer.numberOfLoops = -1
            nextPlayer.volume = 0.72
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            player = nextPlayer
            currentFileName = fileName
        } catch {
            player = nil
            currentFileName = nil
        }
    }

    func setEnabled(_ enabled: Bool, fileName: String) {
        if enabled {
            play(fileName: fileName, enabled: true)
        } else {
            pause()
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player = nil
        currentFileName = nil
    }
}

private struct BreathingOrb: View {
    let mode: BreathMode
    let isRunning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let step = mode.step(at: timeline.date, isRunning: isRunning)
            let scale = mode.scale(for: step)

            ZStack {
                Circle()
                    .fill(mode.accent.opacity(0.20))
                    .scaleEffect(scale + 0.18)
                    .blur(radius: 7)

                Circle()
                    .stroke(.white.opacity(0.58), lineWidth: 2)
                    .scaleEffect(scale + 0.10)
                    .shadow(color: .white.opacity(0.55), radius: 12)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.76),
                                mode.primary.opacity(0.86),
                                mode.deep.opacity(0.70),
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 168
                        )
                    )
                    .scaleEffect(scale)
                    .shadow(color: mode.accent.opacity(0.64), radius: 42)

                Circle()
                    .stroke(mode.accent.opacity(0.38), lineWidth: 24)
                    .scaleEffect(scale + 0.02)
                    .blur(radius: 1)

                VStack(spacing: 10) {
                    Image(systemName: step.phase.symbol)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(step.phase.title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("\(step.remaining)")
                        .font(.system(size: 44, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.86))

                    Text(step.phase.guidance(for: mode))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                }
                .scaleEffect(1 / max(scale, 0.1))
            }
            .animation(.easeInOut(duration: 0.35), value: isRunning)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("呼吸引导球")
    }
}

private struct BreathModeBackground: View {
    let mode: BreathMode

    var body: some View {
        ZStack {
            Image(mode.backgroundImageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    mode.deep.opacity(0.12),
                    .clear,
                    mode.deep.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.10), .black.opacity(0.66)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct MeadowBreathScene: View {
    let time: TimeInterval
    let mode: BreathMode

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Circle()
                    .fill(.white.opacity(0.34))
                    .frame(width: 86, height: 86)
                    .blur(radius: 10)
                    .position(x: width * 0.82, y: height * 0.15)

                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        let y = height * (0.40 + CGFloat(index) * 0.07)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addCurve(
                            to: CGPoint(x: width, y: y + 18),
                            control1: CGPoint(x: width * 0.32, y: y - 52),
                            control2: CGPoint(x: width * 0.70, y: y + 66)
                        )
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(mode.deep.opacity(0.22 + Double(index) * 0.08))
                    .blur(radius: CGFloat(index) * 1.6)
                }

                ForEach(0..<34, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 3) ? Color(red: 0.84, green: 0.93, blue: 0.45).opacity(0.78) : Color(red: 0.42, green: 0.68, blue: 0.24).opacity(0.72))
                        .frame(width: 3, height: 70 + CGFloat(index % 6) * 12)
                        .rotationEffect(.degrees(-8 + sin(time * 0.9 + Double(index)) * 8))
                        .blur(radius: index < 8 ? 2.4 : 0.3)
                        .position(
                            x: width * CGFloat((index * 29) % 100) / 100,
                            y: height * (0.58 + CGFloat((index * 17) % 38) / 100)
                        )
                }
            }
        }
    }
}

private struct SleepOrbitBreathScene: View {
    let time: TimeInterval
    let mode: BreathMode

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                ForEach(0..<42, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(0.28 + 0.18 * sin(time * 0.5 + Double(index))))
                        .frame(width: CGFloat(1 + index % 3), height: CGFloat(1 + index % 3))
                        .position(
                            x: width * CGFloat((index * 37) % 100) / 100,
                            y: height * CGFloat((index * 23) % 42) / 100
                        )
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.54, green: 0.73, blue: 0.92),
                                Color(red: 0.12, green: 0.27, blue: 0.46),
                                Color(red: 0.02, green: 0.04, blue: 0.08),
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(width: width * 1.55, height: width * 1.55)
                    .overlay {
                        Circle()
                            .stroke(mode.primary.opacity(0.55), lineWidth: 5)
                            .blur(radius: 4)
                    }
                    .position(x: width * 0.52, y: height * 0.76)
                    .shadow(color: mode.primary.opacity(0.45), radius: 26)

                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.10))
                        .frame(width: width * 0.72, height: 9)
                        .blur(radius: 7)
                        .rotationEffect(.degrees(-10 + Double(index) * 5))
                        .position(x: width * 0.52, y: height * (0.58 + CGFloat(index) * 0.045))
                }
            }
        }
    }
}

private struct CoolMistBreathScene: View {
    let time: TimeInterval
    let mode: BreathMode

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.13 : 0.08))
                        .frame(width: 150 + CGFloat(index * 22), height: 150 + CGFloat(index * 22))
                        .blur(radius: 20)
                        .position(
                            x: width * (0.12 + CGFloat(index) * 0.12),
                            y: height * (0.18 + 0.05 * sin(time * 0.22 + Double(index)))
                        )
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.58))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.54),
                        control1: CGPoint(x: width * 0.24, y: height * 0.47),
                        control2: CGPoint(x: width * 0.68, y: height * 0.68)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(mode.deep.opacity(0.40))
                .blur(radius: 6)

                ForEach(0..<16, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(width: 80 + CGFloat(index % 4) * 28, height: 3)
                        .blur(radius: 3)
                        .position(
                            x: (CGFloat(index) * 47 + CGFloat(time * 18).truncatingRemainder(dividingBy: width + 120)) - 60,
                            y: height * (0.34 + CGFloat(index % 7) * 0.055)
                        )
                }
            }
        }
    }
}

private struct BreathMode: Identifiable {
    let id = UUID()
    let title: String
    let sceneName: String
    let sceneLabel: String
    let rhythmText: String
    let shortRhythm: String
    let compactRhythm: String
    let phases: [BreathPhaseDuration]
    let kind: BreathModeKind
    let audioFileName: String
    let backgroundImageName: String
    let primary: Color
    let accent: Color
    let deep: Color
    let gradient: [Color]

    var apiModeKey: String {
        switch kind {
        case .meadow:
            return "mood"
        case .sleepOrbit:
            return "sleep"
        case .coolMist:
            return "hot_flash"
        }
    }

    var totalDuration: TimeInterval {
        phases.reduce(0) { $0 + $1.duration }
    }

    func step(at date: Date, isRunning: Bool) -> BreathStep {
        guard isRunning else {
            return BreathStep(phase: phases.first?.phase ?? .inhale, progress: 0, remaining: Int(phases.first?.duration ?? 1))
        }

        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)
        var cursor: TimeInterval = 0

        for phase in phases {
            let next = cursor + phase.duration
            if elapsed < next {
                let local = elapsed - cursor
                let remaining = max(1, Int(ceil(phase.duration - local)))
                return BreathStep(phase: phase.phase, progress: local / phase.duration, remaining: remaining)
            }
            cursor = next
        }

        let last = phases.last ?? BreathPhaseDuration(phase: .exhale, duration: 1)
        return BreathStep(phase: last.phase, progress: 1, remaining: 1)
    }

    func scale(for step: BreathStep) -> CGFloat {
        switch step.phase {
        case .inhale:
            return 0.78 + CGFloat(smooth(step.progress)) * 0.28
        case .hold:
            return 1.06
        case .exhale:
            return 1.06 - CGFloat(smooth(step.progress)) * 0.28
        }
    }

    private func smooth(_ value: Double) -> Double {
        0.5 - cos(value * .pi) / 2
    }

    static let samples = [
        BreathMode(
            title: "舒缓心情",
            sceneName: "柔风麦田",
            sceneLabel: "MOOD RESET",
            rhythmText: "吸 4 秒，呼 6 秒",
            shortRhythm: "4-6",
            compactRhythm: "吸 4s  ·  呼 6s",
            phases: [
                BreathPhaseDuration(phase: .inhale, duration: 4),
                BreathPhaseDuration(phase: .exhale, duration: 6),
            ],
            kind: .meadow,
            audioFileName: "meadow",
            backgroundImageName: "MeditationMeadow",
            primary: Color(red: 0.71, green: 0.86, blue: 0.48),
            accent: Color(red: 0.95, green: 0.99, blue: 0.70),
            deep: Color(red: 0.14, green: 0.32, blue: 0.15),
            gradient: [
                Color(red: 0.45, green: 0.57, blue: 0.95),
                Color(red: 0.70, green: 0.78, blue: 0.96),
                Color(red: 0.55, green: 0.72, blue: 0.28),
                Color(red: 0.03, green: 0.10, blue: 0.03),
            ]
        ),
        BreathMode(
            title: "助眠安睡",
            sceneName: "深睡轨道",
            sceneLabel: "SLEEP RESET",
            rhythmText: "吸 4 秒，停 7 秒，呼 8 秒",
            shortRhythm: "4-7-8",
            compactRhythm: "吸 4s  ·  停 7s  ·  呼 8s",
            phases: [
                BreathPhaseDuration(phase: .inhale, duration: 4),
                BreathPhaseDuration(phase: .hold, duration: 7),
                BreathPhaseDuration(phase: .exhale, duration: 8),
            ],
            kind: .sleepOrbit,
            audioFileName: "night",
            backgroundImageName: "MeditationSleep",
            primary: Color(red: 0.55, green: 0.72, blue: 0.95),
            accent: Color(red: 0.72, green: 0.83, blue: 1.00),
            deep: Color(red: 0.04, green: 0.08, blue: 0.18),
            gradient: [
                Color(red: 0.01, green: 0.02, blue: 0.06),
                Color(red: 0.02, green: 0.05, blue: 0.12),
                Color(red: 0.07, green: 0.16, blue: 0.28),
                Color(red: 0.00, green: 0.01, blue: 0.03),
            ]
        ),
        BreathMode(
            title: "缓解潮热",
            sceneName: "清凉潮汐",
            sceneLabel: "HOT FLASH",
            rhythmText: "吸 5 秒，呼 5 秒",
            shortRhythm: "5-5",
            compactRhythm: "吸 5s  ·  呼 5s",
            phases: [
                BreathPhaseDuration(phase: .inhale, duration: 5),
                BreathPhaseDuration(phase: .exhale, duration: 5),
            ],
            kind: .coolMist,
            audioFileName: "hot-flush-waves",
            backgroundImageName: "MeditationBeach",
            primary: Color(red: 0.50, green: 0.77, blue: 0.94),
            accent: Color(red: 0.76, green: 0.91, blue: 1.00),
            deep: Color(red: 0.10, green: 0.23, blue: 0.34),
            gradient: [
                Color(red: 0.30, green: 0.49, blue: 0.63),
                Color(red: 0.50, green: 0.66, blue: 0.72),
                Color(red: 0.16, green: 0.30, blue: 0.38),
                Color(red: 0.02, green: 0.05, blue: 0.07),
            ]
        ),
    ]
}

private struct BreathPhaseDuration: Equatable {
    let phase: BreathPhase
    let duration: TimeInterval
}

private struct BreathStep: Equatable {
    let phase: BreathPhase
    let progress: Double
    let remaining: Int
}

private enum BreathPhase: Equatable {
    case inhale
    case hold
    case exhale

    var title: String {
        switch self {
        case .inhale:
            return "吸气"
        case .hold:
            return "停留"
        case .exhale:
            return "呼气"
        }
    }

    var symbol: String {
        switch self {
        case .inhale:
            return "wind"
        case .hold:
            return "moon.zzz.fill"
        case .exhale:
            return "sparkles"
        }
    }

    func guidance(for mode: BreathMode) -> String {
        switch (mode.kind, self) {
        case (.coolMist, .inhale):
            return "吸入清凉的空气"
        case (.coolMist, .exhale):
            return "让热感慢慢散开"
        case (.sleepOrbit, .hold):
            return "轻轻停住，不用用力"
        case (.sleepOrbit, .exhale):
            return "让肩颈向下沉一点"
        case (.meadow, .exhale):
            return "把烦躁随呼气放远"
        case (_, .inhale):
            return "把空气带到胸口"
        case (_, .hold):
            return "安静停在这一秒"
        case (_, .exhale):
            return "慢慢放松下来"
        }
    }
}

private enum BreathModeKind: Equatable {
    case meadow
    case sleepOrbit
    case coolMist
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
                        .opacity(0.16)
                        .padding(.top, 12)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                MedicalComplianceNotice()

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
                        .onChange(of: viewModel.comments) { comments in
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
                    .buttonStyle(AppGlassCircleButtonStyle(foreground: AppTheme.inkSoft, size: 44))
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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}

private struct ChatStatusHeader: View {
    @ObservedObject var viewModel: AIChatViewModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.56))
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    }

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.roseStrong)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.status)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
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
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
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
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 18)

            Text("daily greeting")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 42)
    }
}

private struct ChatBubble: View {
    let comment: ChatComment

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(comment.content)
                .font(.system(size: 16, weight: .semibold))
                .lineSpacing(3)
                .foregroundStyle(isAssistant ? AppTheme.ink : .white)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(
                    isAssistant
                    ? AnyShapeStyle(.regularMaterial)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [AppTheme.lavender.opacity(0.96), AppTheme.roseStrong.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isAssistant ? AppTheme.cardStroke : .clear, lineWidth: 1)
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.cardStroke, lineWidth: 1)
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
            .background(
                canSend
                ? LinearGradient(
                    colors: [AppTheme.lavender, AppTheme.roseStrong],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .disabled(!canSend)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.thinMaterial)
    }
}

private struct MineTab: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var dailyQuote: DailyQuote?
    @State private var dailyQuoteTitle = "每日一言"
    @State private var recordCalendarData = RecordCalendarData.currentEmpty()
    @State private var selectedCheckinRange = "30d"
    @State private var refreshStatusText: String?
    @State private var isRefreshing = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountConfirmation = false
    @State private var accountDeletionError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        DailyQuoteCard(title: dailyQuoteTitle, quote: dailyQuote)

                        RecordCalendarCard(
                            data: recordCalendarData,
                            selectedRange: $selectedCheckinRange
                        )

                        VStack(spacing: 14) {
                            ForEach(navItems) { item in
                                MineNavRow(item: item)
                            }
                        }
                        .padding(.top, 4)

                        Link(destination: appFilingURL) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 15, weight: .bold))

                                Text("App 备案号：沪ICP备2026034440号-2A")
                                    .font(.system(size: 13, weight: .semibold))

                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(AppTheme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("App 备案号沪ICP备2026034440号-2A，打开工信部备案系统")

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
                            .glassCard(cornerRadius: 18)
                            .padding(.top, 12)
                        }

                        Button("退出登录") {
                            sessionStore.signOut()
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.cardStroke, lineWidth: 1)
                        }
                        .padding(.top, 12)

                        Button(role: .destructive) {
                            showDeleteAccountConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                if isDeletingAccount {
                                    ProgressView()
                                        .tint(.red)
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .black))
                                }

                                Text(isDeletingAccount ? "正在删除账号..." : "删除账号")
                            }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(red: 0.72, green: 0.15, blue: 0.16))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(red: 1.0, green: 0.94, blue: 0.94), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color(red: 0.92, green: 0.56, blue: 0.56), lineWidth: 1)
                            }
                        }
                        .disabled(isDeletingAccount)

                        if let accountDeletionError {
                            Text(accountDeletionError)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.72, green: 0.15, blue: 0.16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(24)
                }
                .refreshable {
                    await performRefresh()
                }

                if let refreshStatusText {
                    VStack {
                        HStack(spacing: 8) {
                            if isRefreshing {
                                ProgressView()
                                    .tint(Color(red: 0.18, green: 0.16, blue: 0.18))
                                    .scaleEffect(0.9)
                            }

                            Text(refreshStatusText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.92), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 6)
                        .padding(.top, 10)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.86), value: refreshStatusText)
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await reloadMineData()
            }
            .onAppear {
                Task {
                    await reloadMineData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .meditationPracticeDidSave)) { _ in
                Task {
                    await loadRecordCalendar()
                }
            }
            .alert("删除账号？", isPresented: $showDeleteAccountConfirmation) {
                Button("取消", role: .cancel) {}
                Button("永久删除", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("这会删除当前手机号账号、个人资料、聊天记录、趋势报告和练习记录。删除后无法恢复。")
            }
        }
    }

    private func reloadMineData() async {
        await loadDailyQuote()
        await loadRecordCalendar()
    }

    private func performRefresh() async {
        await MainActor.run {
            isRefreshing = true
            refreshStatusText = "正在刷新"
        }

        await reloadMineData()

        await MainActor.run {
            isRefreshing = false
            refreshStatusText = "刷新已完成"
        }

        try? await Task.sleep(nanoseconds: 1_200_000_000)

        guard !Task.isCancelled else { return }
        await MainActor.run {
            if !isRefreshing {
                refreshStatusText = nil
            }
        }
    }

    private func loadDailyQuote() async {
        do {
            let response = try await AuthAPI.shared.dailyQuote()
            dailyQuoteTitle = response.title
            dailyQuote = response.data
        } catch {
            dailyQuote = DailyQuote(
                quote: "更年期是一个充满机会的阶段，就仿佛是第二个青春期。",
                source: "《更年期不是忍忍就好》",
                speaker: "辛西娅・尼克松",
                sourceUrl: nil,
                speakerUrl: nil,
                citationEnabled: false
            )
        }
    }

    private func loadRecordCalendar() async {
        do {
            let trendResponse = try await AuthAPI.shared.loadTrendReport()
            let nextData = RecordCalendarData(
                trendReport: trendResponse.data,
                meditationRecords: try? await AuthAPI.shared.meditationPracticeList(limit: 400).data
            )
            recordCalendarData = nextData
        } catch {
            recordCalendarData = RecordCalendarData.currentEmpty()
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        accountDeletionError = nil

        do {
            let response = try await AuthAPI.shared.deleteAccount()
            if response.deleted {
                sessionStore.signOut()
            } else {
                accountDeletionError = "账号删除未完成，请稍后重试"
            }
        } catch {
            accountDeletionError = error.localizedDescription
        }

        isDeletingAccount = false
    }

    private var navItems: [MineNavItem] {
        [
            MineNavItem(title: "就医清单", desc: "", icon: "cross.case.fill", route: "medical_checklist"),
            MineNavItem(title: "记录历史", desc: "", icon: "clock.arrow.circlepath", route: "record_history"),
            MineNavItem(title: "记录提醒", desc: reminderSummaryText, icon: "bell.fill", route: "record_reminder"),
            MineNavItem(title: "数据与隐私", desc: "查看隐私政策", icon: "shield.lefthalf.filled", route: "privacy"),
        ]
    }

    private var appFilingURL: URL {
        URL(string: "https://beian.miit.gov.cn/")!
    }

    private var reminderSummaryText: String {
        ReminderSettingsStore.summaryText()
    }
}

private struct RecordCalendarData {
    let ranges: [String: RecordCalendarRangeData]
    let defaultRange = "30d"

    static func currentEmpty() -> RecordCalendarData {
        RecordCalendarData(ranges: RecordCalendarRangeData.emptyRanges())
    }

    init(ranges: [String: RecordCalendarRangeData]) {
        self.ranges = ranges
    }

    init(trendReport: TrendReportBlockData?, meditationRecords: [MeditationPracticeListItem]?) {
        let apiRanges = trendReport?.body.ranges ?? [:]
        var nextRanges = RecordCalendarRangeData.emptyRanges()

        for key in ["7d", "30d", "90d"] {
            nextRanges[key] = RecordCalendarRangeData(
                range: key,
                trendRange: apiRanges[key],
                meditationRecords: meditationRecords ?? []
            )
        }

        self.ranges = nextRanges
    }

    func rangeData(for range: String) -> RecordCalendarRangeData {
        ranges[range] ?? ranges[defaultRange] ?? RecordCalendarRangeData.empty(range: range)
    }
}

private struct RecordCalendarRangeData {
    let range: String
    let title: String
    let startDate: Date
    let endDate: Date
    let aiChatDates: Set<Date>
    let meditationDurationsByDate: [Date: Int]

    init(
        range: String,
        title: String,
        startDate: Date,
        endDate: Date,
        aiChatDates: Set<Date>,
        meditationDurationsByDate: [Date: Int]
    ) {
        self.range = range
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.aiChatDates = aiChatDates
        self.meditationDurationsByDate = meditationDurationsByDate
    }

    static func emptyRanges() -> [String: RecordCalendarRangeData] {
        [
            "7d": .empty(range: "7d"),
            "30d": .empty(range: "30d"),
            "90d": .empty(range: "90d"),
        ]
    }

    static func empty(range: String) -> RecordCalendarRangeData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = RecordCalendarRangeData.dayCount(for: range)
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        return RecordCalendarRangeData(
            range: range,
            title: RecordCalendarRangeData.title(for: range),
            startDate: startDate,
            endDate: today,
            aiChatDates: [],
            meditationDurationsByDate: [:]
        )
    }

    init(range: String, trendRange: TrendReportRangeData?, meditationRecords: [MeditationPracticeListItem]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let fallbackDays = RecordCalendarRangeData.dayCount(for: range)

        let resolvedEndDate =
            trendRange?.endDate.flatMap(Self.parseDayString)
            ?? trendRange?.anchorDate.flatMap(Self.parseDayString)
            ?? today
        let resolvedStartDate =
            trendRange?.startDate.flatMap(Self.parseDayString)
            ?? calendar.date(byAdding: .day, value: -(fallbackDays - 1), to: resolvedEndDate)
            ?? resolvedEndDate

        let aiDates = Set((trendRange?.source?.recordedDates ?? []).compactMap(Self.parseDayString))
        var durations: [Date: Int] = [:]

        for record in meditationRecords {
            guard let startedAt = record.startedAt,
                  let practiceDate = Self.parseTimestamp(startedAt).map({ calendar.startOfDay(for: $0) }),
                  practiceDate >= resolvedStartDate,
                  practiceDate <= resolvedEndDate else {
                continue
            }
            durations[practiceDate, default: 0] += max(record.durationSeconds, 0)
        }

        self.range = range
        self.title = Self.title(for: range)
        self.startDate = resolvedStartDate
        self.endDate = resolvedEndDate
        self.aiChatDates = aiDates
        self.meditationDurationsByDate = durations
    }

    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var aiChatDayCount: Int {
        aiChatDates.count
    }

    var meditationPracticeCount: Int {
        meditationDurationsByDate.count
    }

    var meditationMinutes: Int {
        meditationDurationsByDate.values.reduce(0, +) / 60
    }

    var maxMeditationDuration: Int {
        max(meditationDurationsByDate.values.max() ?? 0, 1)
    }

    var cells: [RecordCalendarDayCellData?] {
        let calendar = Calendar.current
        let weekdaysFromMonday = ["一", "二", "三", "四", "五", "六", "日"]
        _ = weekdaysFromMonday

        let leadingBlankCount = (calendar.component(.weekday, from: startDate) + 5) % 7
        let dayCount = max(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0, 0) + 1

        var items: [RecordCalendarDayCellData?] = Array(repeating: nil, count: leadingBlankCount)

        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            let label: String
            if calendar.isDate(dayStart, equalTo: startDate, toGranularity: .month) || calendar.component(.day, from: dayStart) == 1 {
                label = "\(calendar.component(.month, from: dayStart))/\(calendar.component(.day, from: dayStart))"
            } else {
                label = "\(calendar.component(.day, from: dayStart))"
            }

            items.append(
                RecordCalendarDayCellData(
                    date: dayStart,
                    dayLabel: label,
                    hasAIChat: aiChatDates.contains(dayStart),
                    meditationDurationSeconds: meditationDurationsByDate[dayStart] ?? 0,
                    maxMeditationDuration: maxMeditationDuration
                )
            )
        }

        return items
    }

    nonisolated private static func title(for range: String) -> String {
        switch range {
        case "7d":
            return "7天"
        case "90d":
            return "90天"
        default:
            return "30天"
        }
    }

    nonisolated private static func dayCount(for range: String) -> Int {
        switch range {
        case "7d":
            return 7
        case "90d":
            return 90
        default:
            return 30
        }
    }

    nonisolated private static func parseDayString(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value).map { Calendar.current.startOfDay(for: $0) }
    }

    nonisolated private static func parseTimestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}

private struct RecordCalendarDayCellData: Identifiable {
    let date: Date
    let dayLabel: String
    let hasAIChat: Bool
    let meditationDurationSeconds: Int
    let maxMeditationDuration: Int

    var id: TimeInterval {
        date.timeIntervalSince1970
    }

    var hasMeditation: Bool {
        meditationDurationSeconds > 0
    }

    var meditationFillOpacity: Double {
        guard hasMeditation else { return 0 }
        let progress = Double(meditationDurationSeconds) / Double(max(maxMeditationDuration, 1))
        return min(0.84, max(0.26, 0.26 + progress * 0.50))
    }
}

private struct RecordCalendarCard: View {
    let data: RecordCalendarData
    @Binding var selectedRange: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private let rangeOptions = [("7天", "7d"), ("30天", "30d"), ("90天", "90d")]

    var body: some View {
        let current = data.rangeData(for: selectedRange)

        VStack(alignment: .leading, spacing: 16) {
            rangePicker

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(red: 0.75, green: 0.48, blue: 0.64))
                                .frame(width: 30, height: 30)
                                .background(.white.opacity(0.7), in: Circle())

                            Text("身心打卡")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))
                        }

                        HStack(spacing: 10) {
                            legendDot(stroke: Color(red: 0.42, green: 0.66, blue: 0.92), fill: .clear, showsStroke: true, label: "与 AI 聊过")
                            legendDot(stroke: .clear, fill: Color(red: 0.78, green: 0.63, blue: 0.79).opacity(0.55), showsStroke: false, label: "冥想练习")
                        }
                    }

                    Spacer()

                    Text(current.dateRangeText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                }

                HStack(spacing: 12) {
                    RecordMetricCard(value: current.aiChatDayCount, label: "AI 对话天数")
                    RecordMetricCard(value: current.meditationPracticeCount, label: "冥想次数")
                    RecordMetricCard(value: current.meditationMinutes, label: "冥想分钟")
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.56, green: 0.50, blue: 0.54))
                            .frame(height: 20)
                    }

                    ForEach(Array(current.cells.enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            CalendarDayCell(data: cell)
                        } else {
                            Color.clear
                                .frame(height: 46)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.46),
                        AppTheme.dustyPink.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1.2)
            }
            .shadow(color: AppTheme.rose.opacity(0.10), radius: 20, y: 12)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 10) {
            ForEach(rangeOptions, id: \.1) { option in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        selectedRange = option.1
                    }
                } label: {
                    Text(option.0)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(selectedRange == option.1 ? Color(red: 0.25, green: 0.22, blue: 0.28) : Color(red: 0.46, green: 0.42, blue: 0.48))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedRange == option.1 ? .white.opacity(0.94) : .clear)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    selectedRange == option.1
                                    ? Color(red: 0.84, green: 0.70, blue: 0.78)
                                    : .clear,
                                    lineWidth: 2
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
    }

    private func legendDot(stroke: Color, fill: Color, showsStroke: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(stroke, lineWidth: showsStroke ? 2 : 0)
                }

            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.50, green: 0.43, blue: 0.47))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct CalendarDayCell: View {
    let data: RecordCalendarDayCellData

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.42))

            if data.hasMeditation {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.76, green: 0.60, blue: 0.80).opacity(data.meditationFillOpacity))
                    .padding(3.5)
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    data.hasAIChat ? Color(red: 0.42, green: 0.66, blue: 0.92) : Color.white.opacity(0.6),
                    lineWidth: data.hasAIChat ? 2 : 1
                )

            Text(data.dayLabel)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.34, green: 0.30, blue: 0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 2)
        }
        .frame(height: 46)
    }
}

private struct RecordMetricCard: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(AppTheme.ink)

            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .glassCard(cornerRadius: 18)
    }
}

private struct MineNavItem: Identifiable {
    let id = UUID()
    let title: String
    let desc: String
    let icon: String
    let route: String
}

private struct MineNavRow: View {
    let item: MineNavItem

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 18) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.roseStrong)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppTheme.ink)

                    if !item.desc.isEmpty {
                        Text(item.desc)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 0.62, green: 0.56, blue: 0.60))
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 84)
            .glassCard(cornerRadius: 28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var destination: some View {
        if item.route == "medical_checklist" {
            MedicalChecklistView(initialRange: "30d")
        } else if item.route == "record_reminder" {
            RecordReminderSettingsView()
        } else if item.route == "privacy" {
            PrivacyDetailView()
        } else {
            MinePlaceholderDetail(item: item)
        }
    }
}

private struct TrendReportView: View {
    @Environment(\.dismiss) private var dismiss
    let showsBackButton: Bool
    @State private var selectedRange = "30d"
    @State private var trendReportBlock: TrendReportBlockData?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showMedicalChecklist = false

    private let ranges = [
        TrendRange(label: "7天", value: "7d"),
        TrendRange(label: "30天", value: "30d"),
        TrendRange(label: "90天", value: "90d"),
    ]

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    MedicalComplianceNotice()
                    rangePicker
                    if isLoading {
                        trendLoadingCard
                    } else if let loadError {
                        trendErrorCard(message: loadError)
                    } else if currentReport != nil {
                        overviewCard
                        symptomTrendCard
                        frequentSymptomsCard
                        possibleTriggersCard
                        nextStepCard
                        medicalChecklistButton
                    } else {
                        trendEmptyCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showMedicalChecklist) {
            MedicalChecklistView(initialRange: selectedRange)
        }
        .task {
            await loadTrendReport()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsBackButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                }
                .buttonStyle(AppGlassCircleButtonStyle(foreground: AppTheme.inkSoft, size: 42))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("身体趋势")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("基于你的日常记录生成，仅供自我观察")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.inkSoft)
            }

            Spacer(minLength: 0)

            if !showsBackButton {
                Button {} label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(AppGlassCircleButtonStyle(foreground: AppTheme.inkSoft, size: 48))
            }
        }
    }

    private var currentRangeData: TrendReportRangeData? {
        trendReportBlock?.body.ranges[selectedRange]
    }

    private var currentReport: TrendReportPayload? {
        currentRangeData?.report
    }

    private var currentSymptoms: [TrendReportSymptomItem] {
        currentReport?.frequentSymptoms?.items ?? []
    }

    private var currentTrendCard: TrendReportCard? {
        currentReport?.trendCards.first(where: { $0.key == "symptom_trend" })
        ?? currentReport?.trendCards.first(where: { $0.key == "sleep_trend" })
        ?? currentReport?.trendCards.first
    }

    private var currentTriggers: [TrendReportTriggerItem] {
        currentReport?.possibleTriggers?.items ?? []
    }

    private var currentNextSteps: [TrendReportNextStepItem] {
        currentReport?.recommendedNextSteps?.items ?? []
    }

    private var rangePicker: some View {
        HStack(spacing: 10) {
            ForEach(ranges) { range in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        selectedRange = range.value
                    }
                } label: {
                    Text(range.label)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(selectedRange == range.value ? AppTheme.ink : AppTheme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule(style: .continuous).fill(selectedRange == range.value ? .white.opacity(0.94) : .clear))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    selectedRange == range.value
                                    ? LinearGradient(
                                        colors: [AppTheme.lavender.opacity(0.95), AppTheme.rose.opacity(0.95)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 2
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(overviewTitle, icon: "chart.line.uptrend.xyaxis")

            Text(currentReport?.overview?.summary ?? "最近这一段时间的记录还在整理中。")
                .font(.system(size: 18, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let summary = currentTrendCard?.summary {
                HStack(spacing: 0) {
                    trendSummaryMetric(
                        title: "记录",
                        value: "\(summary.recordedDays ?? 0)",
                        unit: "天",
                        tint: AppTheme.ink
                    )
                    trendSummaryDivider
                    trendSummaryMetric(
                        title: "潮热",
                        value: "\(summary.hotFlashTotal ?? 0)",
                        unit: "次",
                        tint: AppTheme.ink
                    )
                    trendSummaryDivider
                    trendSummaryMetric(
                        title: "平均睡眠",
                        value: String(format: "%.1f", summary.averageSleep ?? 0),
                        unit: "小时",
                        tint: AppTheme.ink
                    )
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.50), AppTheme.lavender.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.92), AppTheme.rose.opacity(0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: AppTheme.rose.opacity(0.10), radius: 20, y: 12)
    }

    private var frequentSymptomsCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("高频症状", icon: "flame.fill")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(currentSymptoms.prefix(4).enumerated()), id: \.element.id) { index, symptom in
                        TrendSymptomTile(
                            symptom: symptom,
                            tint: index == 0
                            ? Color(red: 0.89, green: 0.57, blue: 0.66)
                            : Color(red: 0.46, green: 0.60, blue: 0.86),
                            highlighted: index == 0
                        )
                    }
                }
            }
        }
    }

    private var symptomTrendCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle(currentTrendCard?.title ?? "症状变化", icon: "waveform.path.ecg")

                    Spacer()

                    if let badgeText = currentTrendCard?.badgeText, !badgeText.isEmpty {
                        Text(badgeText)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(AppTheme.roseStrong)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.78),
                                        AppTheme.lavender.opacity(0.28),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                }

                if let card = currentTrendCard,
                   let series = card.series,
                   !series.isEmpty {
                    SymptomTrendChartCard(card: card, series: series)
                } else {
                    legacySleepBars
                }
            }
        }
    }

    private var legacySleepBars: some View {
        HStack(alignment: .bottom, spacing: 22) {
            ForEach(currentTrendCard?.dataPoints ?? []) { bar in
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.89, green: 0.58, blue: 0.60),
                                    Color(red: 0.94, green: 0.78, blue: 0.80),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 16, height: max(36, CGFloat(bar.value) / 5 * 118))

                    Text(bar.label)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 152)
    }

    private func trendSummaryMetric(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.inkSoft)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(tint)

                Text(unit)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendSummaryDivider: some View {
        Rectangle()
            .fill(AppTheme.cardStroke)
            .frame(width: 1, height: 68)
            .padding(.horizontal, 14)
    }

    private var possibleTriggersCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("可能触发因素", icon: "lightbulb")

                VStack(spacing: 14) {
                    ForEach(currentTriggers) { trigger in
                        VStack(spacing: 8) {
                            Text(trigger.text)
                                .font(.system(size: 18, weight: .bold))
                                .lineSpacing(6)
                                .foregroundStyle(Color(hex: "#3f3b4f") ?? AppTheme.ink)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            if currentTriggers.first?.id == trigger.id {
                                Text("建议继续观察作息与潮热之间的关系")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.inkSoft)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var nextStepCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("推荐下一步", icon: "checkmark.circle")

                VStack(spacing: 0) {
                    ForEach(Array(currentNextSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 14) {
                            Image(systemName: step.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.inkSoft)
                                .frame(width: 24)

                            Text(step.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.ink)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                        .padding(.vertical, 16)

                        if index < currentNextSteps.count - 1 {
                            Rectangle()
                                .fill(AppTheme.cardStroke.opacity(0.9))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var medicalChecklistButton: some View {
        Button {
            showMedicalChecklist = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 18, weight: .black))

                Text(currentReport?.medicalChecklist?.buttonTitle ?? "生成就医清单")
                    .font(.system(size: 21, weight: .black))
            }
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.92), Color.white.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), AppTheme.cardStroke],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: AppTheme.rose.opacity(0.08), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var trendLoadingCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("趋势报告加载中")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                Text("正在读取你和 AI 对话生成的最近趋势。")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
            }
        }
    }

    private func trendErrorCard(message: String) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("趋势报告暂时没读到")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                Text(message)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.62, green: 0.24, blue: 0.20))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trendEmptyCard: some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("趋势报告还没有内容")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                Text("先去和 AI 聊一聊身体、心情或睡眠，系统就会开始为你生成趋势。")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func color(for style: String?) -> Color {
        switch style {
        case "warning":
            return Color(red: 0.62, green: 0.23, blue: 0.08)
        case "info":
            return Color(red: 0.02, green: 0.22, blue: 0.74)
        default:
            return Color(red: 0.38, green: 0.34, blue: 0.36)
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AppTheme.roseStrong)
                .frame(width: 34, height: 34)
                .background(.regularMaterial, in: Circle())

            Text(title)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(AppTheme.ink)
        }
    }

    private func loadTrendReport() async {
        isLoading = true
        loadError = nil
        do {
            let response = try await AuthAPI.shared.loadTrendReport()
            trendReportBlock = response.data
            if response.data?.body.ranges[selectedRange] == nil,
               let fallback = ranges.first(where: { response.data?.body.ranges[$0.value] != nil }) {
                selectedRange = fallback.value
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private var overviewTitle: String {
        switch selectedRange {
        case "7d":
            return "近 7 天概况"
        case "90d":
            return "近 90 天概况"
        default:
            return "近 30 天概况"
        }
    }
}

private struct SymptomTrendChartCard: View {
    let card: TrendReportCard
    let series: [TrendReportSeries]

    private let chartHeight: CGFloat = 220
    private let plotTopInset: CGFloat = 62

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 22) {
                    ForEach(series) { item in
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(color(for: item))
                                .frame(width: 36, height: 4)

                            Text(item.label)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(red: 0.46, green: 0.42, blue: 0.48))
                        }
                    }
                }

                Text("\(card.metric?.label ?? "症状次数")（\(card.metric?.unit ?? "次")）")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                    .padding(.bottom, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geometry in
                    let maxValue = max(
                        card.metric?.max ?? 0,
                        Double(series.flatMap(\.dataPoints).map(\.value).max() ?? 0),
                        1
                    )

                    ZStack {
                        VStack(spacing: 0) {
                            ForEach(Array(gridValues.enumerated()), id: \.offset) { index, value in
                                HStack(spacing: 8) {
                                    Text("\(Int(value))")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(red: 0.67, green: 0.61, blue: 0.64))
                                        .frame(width: 22, alignment: .leading)

                                    Rectangle()
                                        .fill(Color(red: 0.88, green: 0.84, blue: 0.90))
                                        .frame(height: index == gridValues.count - 1 ? 1.2 : 1)
                                        .overlay(alignment: .top) {
                                            if index != gridValues.count - 1 {
                                                Rectangle()
                                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                                    .foregroundStyle(Color(red: 0.90, green: 0.87, blue: 0.92))
                                            }
                                        }
                                }
                                .frame(height: chartHeight / CGFloat(max(gridValues.count - 1, 1)), alignment: .top)
                            }
                        }
                        .padding(.top, plotTopInset)

                        ForEach(series) { item in
                            TrendSeriesPath(
                                points: normalizedPoints(for: item, width: geometry.size.width - 30, height: chartHeight, maxValue: maxValue)
                            )
                            .stroke(color(for: item), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .offset(x: 30, y: plotTopInset)

                            ForEach(Array(normalizedPoints(for: item, width: geometry.size.width - 30, height: chartHeight, maxValue: maxValue).enumerated()), id: \.offset) { _, point in
                                Circle()
                                    .fill(color(for: item))
                                    .frame(width: 12, height: 12)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                    }
                                    .position(x: point.x + 30, y: point.y + plotTopInset)
                            }
                        }
                    }
                    .frame(height: chartHeight + plotTopInset)
                }
                .frame(height: chartHeight + plotTopInset)

                HStack(alignment: .top, spacing: 0) {
                    Spacer()
                        .frame(width: 30)

                    ForEach(0..<max(series.first?.dataPoints.count ?? 0, 1), id: \.self) { index in
                        Text(series.first?.dataPoints[index].label ?? "")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.40))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                .padding(.top, -20)
            }
        }
    }

    private var gridValues: [Double] {
        let maximum = max(
            card.metric?.max ?? 0,
            Double(series.flatMap(\.dataPoints).map(\.value).max() ?? 0),
            1
        )
        let roundedMax = max(5.0, ceil(maximum / 5.0) * 5.0)
        return stride(from: roundedMax, through: 0, by: -roundedMax / 3.0).map { $0 }
    }

    private func normalizedPoints(for series: TrendReportSeries, width: CGFloat, height: CGFloat, maxValue: Double) -> [CGPoint] {
        let points = series.dataPoints
        guard !points.isEmpty else { return [] }
        let stepX = points.count > 1 ? width / CGFloat(points.count - 1) : 0
        return points.enumerated().map { index, point in
            let ratio = maxValue > 0 ? point.value / maxValue : 0
            let y = height - (CGFloat(ratio) * (height - 12)) - 6
            let x = CGFloat(index) * stepX
            return CGPoint(x: x, y: y)
        }
    }

    private func color(for series: TrendReportSeries) -> Color {
        Color(hex: series.color) ?? (
            series.key == "hot_flash"
            ? Color(red: 0.84, green: 0.47, blue: 0.60)
            : Color(red: 0.36, green: 0.57, blue: 0.85)
        )
    }
}

private struct TrendSeriesPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midPoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midPoint, control: CGPoint(x: midPoint.x, y: previous.y))
            path.addQuadCurve(to: current, control: CGPoint(x: midPoint.x, y: current.y))
        }
        return path
    }
}

private struct TrendSymptomTile: View {
    let symptom: TrendReportSymptomItem
    let tint: Color
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symptom.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(symptom.label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(highlighted ? tint : AppTheme.inkSoft)

            Spacer(minLength: 6)

            Text("\(symptom.count)\(symptom.unit ?? "次")")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(highlighted ? tint : AppTheme.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background(
            LinearGradient(
                colors: highlighted
                ? [tint.opacity(0.12), Color.white.opacity(0.42)]
                : [Color.white.opacity(0.34), Color.white.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((highlighted ? tint.opacity(0.32) : AppTheme.cardStroke), lineWidth: 1.1)
        }
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex else { return nil }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

private struct MedicalChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: String
    @State private var checklistData: MedicalChecklistData?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedQuestions: Set<String> = []
    @State private var customQuestion = ""
    @State private var toastMessage: String?
    @State private var savedAtText: String?

    private let ranges = [
        TrendRange(label: "近7天", value: "7d"),
        TrendRange(label: "近30天", value: "30d"),
        TrendRange(label: "近90天", value: "90d"),
    ]

    init(initialRange: String = "30d") {
        _selectedRange = State(initialValue: initialRange)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    checklistHeader
                    MedicalComplianceNotice()
                    checklistRangePicker

                    if isLoading {
                        medicalChecklistInfoCard(title: "就医清单生成中", body: "正在根据趋势报告整理适合就诊沟通的重点。")
                    } else if let loadError {
                        medicalChecklistInfoCard(title: "就医清单暂时没读到", body: loadError, tint: Color(red: 0.62, green: 0.24, blue: 0.20))
                    } else if let checklistData {
                        statusCard(checklistData.statusCard)
                        summaryCard(checklistData)
                        attentionCard(checklistData)
                        questionCard(checklistData)
                        previewCard(checklistData)
                        historyCard(checklistData)
                        actionButtons
                    } else {
                        medicalChecklistInfoCard(title: "就医清单还没有内容", body: "先去和 AI 聊一聊身体、心情或睡眠，系统会自动整理就诊时可用的内容。")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }

            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadMedicalChecklist()
        }
        .onChange(of: selectedRange) { _ in
            Task {
                await loadMedicalChecklist()
            }
        }
    }

    private var checklistHeader: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color(red: 0.38, green: 0.34, blue: 0.36))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Text(checklistData?.title ?? "就医沟通清单")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()
        }
    }

    private var checklistRangePicker: some View {
        HStack(spacing: 14) {
            ForEach(ranges) { range in
                Button {
                    selectedRange = range.value
                } label: {
                    Text(range.label)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(selectedRange == range.value ? .white : Color(red: 0.42, green: 0.37, blue: 0.40))
                        .frame(width: 96, height: 50)
                        .background(
                            Capsule()
                                .fill(selectedRange == range.value ? Color(red: 0.88, green: 0.66, blue: 0.59) : .white.opacity(0.62))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 4)
    }

    private func statusCard(_ card: MedicalChecklistStatusCard) -> some View {
        TrendCard {
            HStack(spacing: 16) {
                Image(systemName: card.icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.78), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                    Text(card.subtitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                }

                Spacer()
            }
        }
    }

    private func summaryCard(_ data: MedicalChecklistData) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 28) {
                Text(data.summarySection.title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                ForEach(data.summarySection.items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                            .frame(width: 28)

                        Text(item.label)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 0.44, green: 0.39, blue: 0.42))

                        Spacer()

                        Text("出现 \(item.count)\(item.unit)")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color(red: 0.44, green: 0.39, blue: 0.42))
                    }
                }
            }
        }
    }

    private func attentionCard(_ data: MedicalChecklistData) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 22) {
                Text(data.attentionSection.title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(data.attentionSection.items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                                .frame(width: 24)

                            Text(item.text)
                                .font(.system(size: 16, weight: .bold))
                                .lineSpacing(6)
                                .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(18)
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.93, green: 0.88, blue: 0.91), lineWidth: 1)
                }
            }
        }
    }

    private func questionCard(_ data: MedicalChecklistData) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(data.questionSection.title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                Text(data.questionSection.subtitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))

                FlowQuestionChips(
                    questions: data.questionSection.suggestions,
                    selectedQuestions: selectedQuestions,
                    onTap: toggleQuestion
                )

                TextEditor(text: $customQuestion)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.22))
                    .frame(minHeight: 104)
                    .padding(14)
                    .scrollContentBackground(.hidden)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.90, green: 0.86, blue: 0.89), lineWidth: 1)
                    }
                    .overlay(alignment: .topLeading) {
                        if customQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("添加你自己的问题...")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(red: 0.72, green: 0.67, blue: 0.70))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 28)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    private func previewCard(_ data: MedicalChecklistData) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(data.preview.title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                VStack(alignment: .leading, spacing: 12) {
                    Text(previewText)
                        .font(.system(size: 16, weight: .bold))
                        .lineSpacing(7)
                        .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.40))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.93, green: 0.88, blue: 0.91), lineWidth: 1)
                }

                if let savedAtText {
                    Text(savedAtText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.65, green: 0.59, blue: 0.62))
                }
            }
        }
    }

    private func historyCard(_ data: MedicalChecklistData) -> some View {
        guard let historySection = data.historySection, !historySection.items.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            TrendCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(historySection.title)
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                    ForEach(historySection.items.prefix(5), id: \.versionId) { item in
                        Button {
                            restoreHistory(item)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatSavedAt(item.savedAt) ?? "历史版本")
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundStyle(Color(red: 0.30, green: 0.27, blue: 0.30))

                                    Text("共 \(item.questionCount ?? 0) 个问题")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(red: 0.62, green: 0.56, blue: 0.60))
                                }

                                Spacer()

                                Text("恢复")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Color(red: 0.88, green: 0.66, blue: 0.59))
                            }
                            .padding(16)
                            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color(red: 0.93, green: 0.88, blue: 0.91), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    UIPasteboard.general.string = previewText
                    showToast("已复制到剪贴板")
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(.white.opacity(0.74), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await saveChecklist()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("保存")
                    }
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(Color(red: 0.88, green: 0.66, blue: 0.59), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                Task {
                    await savePreviewImageToPhotos()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                    Text("保存为图片")
                }
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(.white.opacity(0.74), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func medicalChecklistInfoCard(title: String, body: String, tint: Color = Color(red: 0.58, green: 0.52, blue: 0.56)) -> some View {
        TrendCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                Text(body)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var orderedSelectedQuestions: [String] {
        let suggestions = checklistData?.questionSection.suggestions ?? []
        var ordered = suggestions.filter { selectedQuestions.contains($0) }
        let custom = customQuestion
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        ordered.append(contentsOf: custom)
        return ordered
    }

    private var previewText: String {
        guard let checklistData else {
            return ""
        }

        var lines: [String] = []
        lines.append("症状记录（\(checklistData.preview.periodLabel)）：")
        lines.append(contentsOf: checklistData.preview.symptomLines)

        if !checklistData.attentionSection.items.isEmpty {
            lines.append("")
            lines.append("需要特别说明的情况：")
            lines.append(contentsOf: checklistData.attentionSection.items.map { "- \($0.text)" })
        }

        if !orderedSelectedQuestions.isEmpty {
            lines.append("")
            lines.append(checklistData.preview.questionPrefix)
            lines.append(contentsOf: orderedSelectedQuestions.enumerated().map { "\($0.offset + 1). \($0.element)" })
        }

        lines.append("")
        lines.append(MedicalComplianceText.shortExport)

        return lines.joined(separator: "\n")
    }

    private func loadMedicalChecklist() async {
        isLoading = true
        loadError = nil
        do {
            let response = try await AuthAPI.shared.loadMedicalChecklist(range: selectedRange)
            checklistData = response.data
            applyDraft()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleQuestion(_ question: String) {
        if selectedQuestions.contains(question) {
            selectedQuestions.remove(question)
        } else {
            selectedQuestions.insert(question)
        }
    }

    private func applyDraft() {
        if let savedState = checklistData?.savedState {
            let suggestionSet = Set(checklistData?.questionSection.suggestions ?? [])
            selectedQuestions = Set(savedState.selectedQuestions.filter { suggestionSet.contains($0) })
            customQuestion = savedState.customQuestion
            savedAtText = formatSavedAt(savedState.savedAt)
        } else {
            selectedQuestions = []
            customQuestion = ""
            savedAtText = nil
        }
    }

    private func exportPreviewImage() -> UIImage? {
        let renderer = ImageRenderer(
            content:
                MedicalChecklistShareCard(
                    title: checklistData?.title ?? "就医沟通清单",
                    rangeLabel: checklistData?.rangeLabel ?? "",
                    savedAtText: savedAtText,
                    previewText: previewText
                )
                .frame(width: 720)
        )
        renderer.scale = 3
        return renderer.uiImage
    }

    private func savePreviewImageToPhotos() async {
        guard let image = exportPreviewImage() else {
            showToast("图片生成失败，请重试")
            return
        }

        do {
            try await PhotoAlbumSaver.save(image: image)
            showToast("已保存到系统相册")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func saveChecklist() async {
        do {
            let response = try await AuthAPI.shared.saveMedicalChecklist(
                range: selectedRange,
                selectedQuestions: (checklistData?.questionSection.suggestions ?? []).filter { selectedQuestions.contains($0) },
                customQuestion: customQuestion,
                previewText: previewText
            )
            savedAtText = formatSavedAt(response.data?.savedAt)
            showToast("已保存到当前账号")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func restoreHistory(_ item: MedicalChecklistSavedState) {
        let suggestionSet = Set(checklistData?.questionSection.suggestions ?? [])
        selectedQuestions = Set(item.selectedQuestions.filter { suggestionSet.contains($0) })
        customQuestion = item.customQuestion
        savedAtText = formatSavedAt(item.savedAt)
        showToast("已恢复到这个版本")
    }

    private func formatSavedAt(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let date = formatter.date(from: value) ?? fallback.date(from: value)
        guard let date else {
            return nil
        }
        let output = DateFormatter()
        output.locale = Locale(identifier: "zh_CN")
        output.dateFormat = "已保存于 M月d日 HH:mm"
        return output.string(from: date)
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct TrendCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.90), AppTheme.cardStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: AppTheme.rose.opacity(0.10), radius: 20, y: 12)
    }
}

private enum MedicalComplianceText {
    static let title = "医疗提示"
    static let full = "本 App 内容用于自我观察和就医沟通准备，不是医学诊断，不是治疗建议，不能替代医生判断。若出现紧急、严重或持续加重的症状，请及时就医或联系当地急救服务。"
    static let shortExport = "说明：以上内容仅用于自我观察和就医沟通准备，不是医学诊断，不是治疗建议；如有紧急、严重或持续加重症状，请及时就医。"
}

private struct MedicalComplianceNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(red: 0.62, green: 0.30, blue: 0.34))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.70), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(MedicalComplianceText.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)

                Text(MedicalComplianceText.full)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.93, green: 0.86, blue: 0.88), lineWidth: 1)
        }
    }
}

private struct FlowQuestionChips: View {
    let questions: [String]
    let selectedQuestions: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(questions, id: \.self) { question in
                Button {
                    onTap(question)
                } label: {
                    Text(question)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selectedQuestions.contains(question) ? .white : Color(red: 0.44, green: 0.39, blue: 0.42))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(selectedQuestions.contains(question) ? Color(red: 0.88, green: 0.66, blue: 0.59) : .white.opacity(0.70))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    selectedQuestions.contains(question) ? Color.clear : Color(red: 0.91, green: 0.86, blue: 0.89),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MedicalChecklistShareCard: View {
    let title: String
    let rangeLabel: String
    let savedAtText: String?
    let previewText: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.96),
                    Color(red: 0.95, green: 0.96, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                    HStack(spacing: 10) {
                        Text(rangeLabel)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.88, green: 0.66, blue: 0.59), in: Capsule())

                        if let savedAtText {
                            Text(savedAtText)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                        }
                    }
                }

                Text(previewText)
                    .font(.system(size: 24, weight: .bold))
                    .lineSpacing(10)
                    .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.40))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(30)
                    .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
                    }

                HStack {
                    Spacer()
                    Text("Menocalm · 就医沟通整理")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.62, green: 0.57, blue: 0.60))
                }
            }
            .padding(36)
        }
    }
}

private struct TrendRange: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct TrendSymptom: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let count: Int
}

private struct TrendBar: Identifiable {
    let id = UUID()
    let label: String
    let value: CGFloat
}

private enum PhotoAlbumSaveError: LocalizedError {
    case denied
    case restricted
    case failed

    var errorDescription: String? {
        switch self {
        case .denied:
            return "没有相册权限，请到系统设置里允许保存图片"
        case .restricted:
            return "当前设备不允许访问相册"
        case .failed:
            return "保存到相册失败，请稍后重试"
        }
    }
}

private enum PhotoAlbumSaver {
    static func save(image: UIImage) async throws {
        let status = await requestStatus()
        switch status {
        case .authorized, .limited:
            break
        case .denied:
            throw PhotoAlbumSaveError.denied
        case .restricted:
            throw PhotoAlbumSaveError.restricted
        case .notDetermined:
            throw PhotoAlbumSaveError.failed
        @unknown default:
            throw PhotoAlbumSaveError.failed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var completed = false
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                guard !completed else { return }
                completed = true
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoAlbumSaveError.failed)
                }
            }
        }
    }

    private static func requestStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current != .notDetermined {
            return current
        }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}

private struct TrendInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
}

private struct TrendNextStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let desc: String
}

enum ReminderKind: String {
    case dailyRecord = "daily_record"
    case sleepPractice = "sleep_practice"
    case weeklyReport = "weekly_report"

    var identifier: String { "menocalm.reminder.\(rawValue)" }

    var title: String {
        switch self {
        case .dailyRecord:
            return "每日记录提醒"
        case .sleepPractice:
            return "睡前练习提醒"
        case .weeklyReport:
            return "周报提醒"
        }
    }

    var body: String {
        switch self {
        case .dailyRecord:
            return "今天也记录一下身体、心情或睡眠吧。"
        case .sleepPractice:
            return "该留一点时间给自己，做一次睡前练习了。"
        case .weeklyReport:
            return "这周的记录可以回看一下，看看身体变化趋势。"
        }
    }
}

struct ReminderPreference: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int
    var weekday: Int

    var date: Date {
        get {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            hour = components.hour ?? hour
            minute = components.minute ?? minute
        }
    }
}

struct ReminderSettings: Codable, Equatable {
    var dailyRecord: ReminderPreference
    var sleepPractice: ReminderPreference
    var weeklyReport: ReminderPreference

    static let `default` = ReminderSettings(
        dailyRecord: ReminderPreference(enabled: false, hour: 21, minute: 0, weekday: 2),
        sleepPractice: ReminderPreference(enabled: false, hour: 22, minute: 0, weekday: 2),
        weeklyReport: ReminderPreference(enabled: false, hour: 10, minute: 0, weekday: 2)
    )

    func preference(for kind: ReminderKind) -> ReminderPreference {
        switch kind {
        case .dailyRecord:
            return dailyRecord
        case .sleepPractice:
            return sleepPractice
        case .weeklyReport:
            return weeklyReport
        }
    }

    mutating func setEnabled(_ enabled: Bool, for kind: ReminderKind) {
        switch kind {
        case .dailyRecord:
            dailyRecord.enabled = enabled
        case .sleepPractice:
            sleepPractice.enabled = enabled
        case .weeklyReport:
            weeklyReport.enabled = enabled
        }
    }
}

enum ReminderSettingsStore {
    private static let key = "menocalmxia.reminderSettings"

    static func load() -> ReminderSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: ReminderSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func summaryText() -> String {
        let settings = load()
        var items: [String] = []
        if settings.dailyRecord.enabled {
            items.append("每日 \(timeText(hour: settings.dailyRecord.hour, minute: settings.dailyRecord.minute))")
        }
        if settings.sleepPractice.enabled {
            items.append("睡前 \(timeText(hour: settings.sleepPractice.hour, minute: settings.sleepPractice.minute))")
        }
        if settings.weeklyReport.enabled {
            let weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][max(0, min(6, settings.weeklyReport.weekday - 1))]
            items.append("\(weekday) \(timeText(hour: settings.weeklyReport.hour, minute: settings.weeklyReport.minute))")
        }
        return items.isEmpty ? "全部关闭" : items.joined(separator: " · ")
    }

    private static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

private enum ReminderNotificationError: LocalizedError {
    case denied

    var errorDescription: String? {
        "没有通知权限，请到系统设置里打开通知"
    }
}

enum ReminderNotificationManager {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func configureDelegate(_ delegate: UNUserNotificationCenterDelegate) {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func ensurePermission() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            throw ReminderNotificationError.denied
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    static func sync(settings: ReminderSettings, kind: ReminderKind) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [kind.identifier])
        let preference = settings.preference(for: kind)
        guard preference.enabled else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.sound = .default
        content.interruptionLevel = .active

        var components = DateComponents()
        components.hour = preference.hour
        components.minute = preference.minute
        if kind == .weeklyReport {
            components.weekday = preference.weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: kind.identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func syncAll(settings: ReminderSettings) async throws {
        for kind in [ReminderKind.dailyRecord, .sleepPractice, .weeklyReport] {
            try await sync(settings: settings, kind: kind)
        }
    }

    static func sendTestNotification(after seconds: TimeInterval = 5) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "提醒测试"
        content.body = "如果你看到了这条，说明本机通知已经正常工作。"
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "menocalm.reminder.test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: ["menocalm.reminder.test"])
        try await center.add(request)
    }
}

private struct RecordReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ReminderSettingsStore.load()
    @State private var toastMessage: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let weekdaySymbols = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if notificationStatus == .denied {
                        permissionBanner
                    }

                    TrendCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("提醒")
                                .font(.system(size: 23, weight: .black))
                                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                            reminderCard(
                                icon: "bell.fill",
                                title: "每日记录提醒",
                                subtitle: "每天 \(timeLabel(for: settings.dailyRecord))",
                                isOn: Binding(
                                    get: { settings.dailyRecord.enabled },
                                    set: { value in
                                        settings.dailyRecord.enabled = value
                                        Task { await updateReminder(.dailyRecord) }
                                    }
                                ),
                                time: dateBinding(for: \.dailyRecord)
                            )

                            reminderCard(
                                icon: "moon.fill",
                                title: "睡前练习提醒",
                                subtitle: "每天 \(timeLabel(for: settings.sleepPractice))",
                                isOn: Binding(
                                    get: { settings.sleepPractice.enabled },
                                    set: { value in
                                        settings.sleepPractice.enabled = value
                                        Task { await updateReminder(.sleepPractice) }
                                    }
                                ),
                                time: dateBinding(for: \.sleepPractice)
                            )

                            weeklyReminderCard

                            Button {
                                Task { await sendTestNotification() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "bell.badge")
                                        .font(.system(size: 16, weight: .black))
                                    Text("5秒后发送测试提醒")
                                        .font(.system(size: 16, weight: .black))
                                }
                                .foregroundStyle(Color(red: 0.36, green: 0.28, blue: 0.30))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.98, green: 0.95, blue: 0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color(red: 0.90, green: 0.84, blue: 0.87), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }

            if let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .padding(.top, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            notificationStatus = await ReminderNotificationManager.authorizationStatus()
            if notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .ephemeral {
                try? await ReminderNotificationManager.syncAll(settings: settings)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color(red: 0.38, green: 0.34, blue: 0.36))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Text("设置")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

            Spacer()
        }
    }

    private var weeklyReminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("周报提醒")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                    Text("\(weekdaySymbols[max(0, min(6, settings.weeklyReport.weekday - 1))] ) · \(timeLabel(for: settings.weeklyReport))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.weeklyReport.enabled },
                    set: { value in
                        settings.weeklyReport.enabled = value
                        Task { await updateReminder(.weeklyReport) }
                    }
                ))
                .labelsHidden()
                .tint(Color(red: 0.88, green: 0.66, blue: 0.59))
            }

            HStack {
                Picker("星期", selection: $settings.weeklyReport.weekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(red: 0.44, green: 0.39, blue: 0.42))

                Spacer()

                DatePicker("", selection: dateBinding(for: \.weeklyReport), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            .onChange(of: settings.weeklyReport.weekday) { _ in
                Task { await updateReminder(.weeklyReport) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(red: 0.69, green: 0.42, blue: 0.32))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("通知权限未开启")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(red: 0.32, green: 0.24, blue: 0.24))

                Text("请到系统设置里允许通知，否则提醒不会真正送达。")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.43, blue: 0.40))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.92, blue: 0.90).opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.92, green: 0.82, blue: 0.80), lineWidth: 1)
        }
    }

    private func reminderCard(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 0.56, green: 0.49, blue: 0.53))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.18))

                    Text(subtitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.58, green: 0.52, blue: 0.56))
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color(red: 0.88, green: 0.66, blue: 0.59))
            }

            HStack {
                Spacer()
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
        }
    }

    private func dateBinding(for keyPath: WritableKeyPath<ReminderSettings, ReminderPreference>) -> Binding<Date> {
        Binding(
            get: { settings[keyPath: keyPath].date },
            set: { newValue in
                settings[keyPath: keyPath].date = newValue
                Task { await updateReminder(reminderKind(for: keyPath)) }
            }
        )
    }

    private func reminderKind(for keyPath: WritableKeyPath<ReminderSettings, ReminderPreference>) -> ReminderKind {
        switch keyPath {
        case \.dailyRecord:
            return .dailyRecord
        case \.sleepPractice:
            return .sleepPractice
        default:
            return .weeklyReport
        }
    }

    private func timeLabel(for preference: ReminderPreference) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: preference.date)
    }

    private func updateReminder(_ kind: ReminderKind) async {
        let previous = ReminderSettingsStore.load()
        do {
            if settings.preference(for: kind).enabled {
                let granted = try await ReminderNotificationManager.ensurePermission()
                notificationStatus = await ReminderNotificationManager.authorizationStatus()
                if !granted {
                    settings.setEnabled(false, for: kind)
                    showToast("请先允许通知权限")
                    return
                }
            }
            ReminderSettingsStore.save(settings)
            try await ReminderNotificationManager.sync(settings: settings, kind: kind)
            notificationStatus = await ReminderNotificationManager.authorizationStatus()
            showToast(settings.preference(for: kind).enabled ? "提醒已更新" : "提醒已关闭")
        } catch {
            settings = previous
            notificationStatus = await ReminderNotificationManager.authorizationStatus()
            showToast(error.localizedDescription)
        }
    }

    private func sendTestNotification() async {
        do {
            let granted = try await ReminderNotificationManager.ensurePermission()
            notificationStatus = await ReminderNotificationManager.authorizationStatus()
            guard granted else {
                showToast("请先允许通知权限")
                return
            }
            try await ReminderNotificationManager.sendTestNotification()
            showToast("测试提醒已安排，5秒后送达")
        } catch {
            notificationStatus = await ReminderNotificationManager.authorizationStatus()
            showToast(error.localizedDescription)
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct MinePlaceholderDetail: View {
    let item: MineNavItem

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(red: 0.64, green: 0.48, blue: 0.56))

                Text(item.title)
                    .font(.system(size: 28, weight: .black))

                if !item.desc.isEmpty {
                    Text(item.desc)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.45, green: 0.39, blue: 0.43))
                }
            }
            .padding(24)
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyDetailView: View {
    private let links = [
        LegalLinkItem(title: "隐私政策", subtitle: "查看数据收集、使用、共享和保存方式", path: "/privacy", icon: "hand.raised.fill"),
        LegalLinkItem(title: "用户协议", subtitle: "查看账号、服务和使用规则", path: "/terms", icon: "doc.text.fill"),
        LegalLinkItem(title: "数据删除/撤回同意", subtitle: "申请删除记录或撤回 AI/健康数据处理同意", path: "/data-deletion", icon: "trash.fill"),
        LegalLinkItem(title: "AI/健康建议免责声明", subtitle: "了解 AI 回复和趋势报告的使用边界", path: "/ai-health-disclaimer", icon: "heart.text.square.fill"),
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("数据与隐私")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(AppTheme.ink)

                        Text("潮安会收集手机号、聊天内容、健康/症状记录和冥想记录。部分聊天和健康记录会发送给 AI 服务处理，用于生成回复、趋势报告和就医沟通清单。")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.inkSoft)
                    }
                    .padding(22)
                    .glassCard(cornerRadius: 24)

                    VStack(spacing: 12) {
                        ForEach(links) { item in
                            Link(destination: item.url) {
                                HStack(spacing: 16) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(AppTheme.roseStrong)
                                        .frame(width: 40, height: 40)
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.system(size: 17, weight: .black))
                                            .foregroundStyle(AppTheme.ink)

                                        Text(item.subtitle)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color(red: 0.54, green: 0.49, blue: 0.53))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.forward")
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(Color(red: 0.62, green: 0.56, blue: 0.60))
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(cornerRadius: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("AI 回复和健康趋势仅用于记录、科普和就医沟通准备，不替代医生诊断、治疗、处方或急救。")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.50, green: 0.38, blue: 0.43))
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 20)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("数据与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalLinkItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let path: String
    let icon: String

    var url: URL {
        URL(string: path, relativeTo: AuthAPI.shared.baseURL) ?? AuthAPI.shared.baseURL
    }
}

private struct DailyQuoteCard: View {
    let title: String
    let quote: DailyQuote?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(AppTheme.inkSoft)

                Spacer()

                if let source = quote?.source, !source.isEmpty {
                    if citationEnabled, let url = url(from: quote?.sourceUrl) {
                        Link("出处 \(source)", destination: url)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.inkSoft)
                            .lineLimit(1)
                    } else {
                        Text("出处 \(source)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.inkSoft)
                            .lineLimit(1)
                    }
                }
            }

            Text("“\(quote?.quote ?? "更年期是一个充满机会的阶段，就仿佛是第二个青春期。")”")
                .font(.system(size: 22, weight: .black))
                .lineSpacing(6)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let speaker = quote?.speaker, !speaker.isEmpty {
                if citationEnabled, let url = url(from: quote?.speakerUrl) {
                    Link("—— \(speaker)", destination: url)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.inkSoft)
                } else {
                    Text("—— \(speaker)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.vertical, 26)
        .glassCard(cornerRadius: 28)
    }

    private var citationEnabled: Bool {
        quote?.citationEnabled == true
    }

    private func url(from value: String?) -> URL? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(string: value)
    }
}
