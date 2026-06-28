import SwiftUI
import UIKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 58)

                BrandMark()

                Spacer(minLength: 42)

                LoginCard(viewModel: viewModel) { response in
                    sessionStore.save(loginResponse: response, fallbackMobile: viewModel.mobile)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

enum AppTheme {
    static let powderBlue = Color(red: 0.83, green: 0.90, blue: 0.98)
    static let lavenderGray = Color(red: 0.88, green: 0.87, blue: 0.93)
    static let dustyPink = Color(red: 0.90, green: 0.77, blue: 0.81)
    static let orbHighlight = Color.white.opacity(0.86)
    static let orbShadow = Color(red: 0.86, green: 0.76, blue: 0.86).opacity(0.62)
    static let ink = Color(red: 0.23, green: 0.18, blue: 0.26)
    static let inkSoft = Color(red: 0.41, green: 0.35, blue: 0.44)
    static let muted = Color(red: 0.49, green: 0.44, blue: 0.52)
    static let rose = Color(red: 0.84, green: 0.55, blue: 0.67)
    static let roseStrong = Color(red: 0.78, green: 0.47, blue: 0.60)
    static let lavender = Color(red: 0.66, green: 0.58, blue: 0.79)
    static let blue = Color(red: 0.40, green: 0.65, blue: 0.90)
    static let cardStroke = Color.white.opacity(0.82)
}

struct AppBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.powderBlue,
                        AppTheme.lavenderGray,
                        AppTheme.dustyPink,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.42),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.7
                )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.orbHighlight,
                                Color.white.opacity(0.58),
                                AppTheme.orbShadow,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.42), lineWidth: 2)
                    }
                    .frame(width: min(geometry.size.width * 1.02, 520), height: min(geometry.size.width * 1.02, 520))
                    .blur(radius: 1.2)
                    .position(x: geometry.size.width * 0.52, y: geometry.size.height * 0.82)
                    .shadow(color: Color.white.opacity(0.32), radius: 40, y: -8)
            }
            .ignoresSafeArea()
        }
    }
}

struct BrandMark: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .frame(width: 106, height: 106)
                    .shadow(color: AppTheme.rose.opacity(0.16), radius: 36, y: 24)

                Image("LoginLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
            .padding(.bottom, 20)

            Text("潮安")
                .font(.system(size: 48, weight: .black))
                .foregroundStyle(AppTheme.ink)

            Text("登录后保存你的记录与报告")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.muted)
        }
    }
}

private struct LoginCard: View {
    @ObservedObject var viewModel: LoginViewModel
    let onLoginSuccess: (LoginResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("手机号登录")
                .font(.system(size: 28, weight: .black))
                .padding(.bottom, 8)

            Text("输入手机号，获取验证码后开始访问。")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
                .padding(.bottom, 22)

            FieldTitle("手机号")
            TextField("13800138000", text: $viewModel.mobile)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .onChange(of: viewModel.mobile) { _, _ in viewModel.normalizeMobile() }
                .textFieldStyle(LoginTextFieldStyle())

            FieldTitle("验证码")
                .padding(.top, 16)

            HStack(spacing: 10) {
                TextField("6 位验证码", text: $viewModel.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: viewModel.code) { _, _ in viewModel.normalizeCode() }
                    .textFieldStyle(LoginTextFieldStyle())

                Button(viewModel.isCodeSending ? "发送中" : "获取验证码") {
                    Task { await viewModel.sendCode() }
                }
                .buttonStyle(SendCodeButtonStyle())
                .disabled(viewModel.isCodeSending)
            }

            Button(viewModel.isLoading ? "访问中..." : "开始访问") {
                Task {
                    if let response = await viewModel.login() {
                        onLoginSuccess(response)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            .padding(.top, 24)

            Text(viewModel.status)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            if let result = viewModel.loginResult {
                ResultPanel(result: result)
                    .padding(.top, 14)
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 30)
    }

    private var statusColor: Color {
        if viewModel.status.contains("成功") || viewModel.status.contains("已发送") {
            return Color(red: 0.09, green: 0.45, blue: 0.27)
        }
        if viewModel.status.contains("失败") || viewModel.status.contains("请输入") || viewModel.status.contains("failed") {
            return Color(red: 0.70, green: 0.14, blue: 0.09)
        }
        return Color(red: 0.47, green: 0.41, blue: 0.44)
    }
}

private struct FieldTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.inkSoft)
            .padding(.bottom, 8)
    }
}

private struct ResultPanel: View {
    let result: LoginResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("登录结果")
                .font(.system(size: 13, weight: .bold))
            Text("block_id: \(result.blockId ?? "-")")
            Text("database: \(result.database ?? "-")")
            Text("login: \(result.login ?? "-")")
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(Color(red: 0.23, green: 0.19, blue: 0.21))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
        }
    }
}

struct FlowerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.36, width: w * 0.38, height: h * 0.48))
        path.addEllipse(in: CGRect(x: w * 0.50, y: h * 0.36, width: w * 0.38, height: h * 0.48))
        path.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.08, width: w * 0.28, height: h * 0.48))
        return path
    }
}

private struct LoginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 15)
            .frame(height: 52)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
    }
}

private struct SendCodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.roseStrong)
            .frame(width: 116, height: 52)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
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

struct AppGlassCircleButtonStyle: ButtonStyle {
    var foreground: Color = AppTheme.ink
    var size: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: Color.white.opacity(0.16), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 28) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            }
            .shadow(color: AppTheme.rose.opacity(0.10), radius: 26, y: 16)
    }
}

#Preview {
    LoginView()
}
