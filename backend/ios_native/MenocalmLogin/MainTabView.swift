import SwiftUI

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

#Preview {
    MainTabView()
        .environmentObject(SessionStore())
}
