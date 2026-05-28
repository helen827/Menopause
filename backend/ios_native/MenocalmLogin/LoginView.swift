import SwiftUI

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

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.985, blue: 0.985),
                Color(red: 0.953, green: 0.918, blue: 0.941),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct BrandMark: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .frame(width: 106, height: 106)
                    .shadow(color: Color(red: 0.46, green: 0.34, blue: 0.41).opacity(0.22), radius: 36, y: 24)

                FlowerMark()
                    .fill(Color(red: 0.64, green: 0.48, blue: 0.56))
                    .frame(width: 58, height: 48)
            }
            .rotationEffect(.degrees(2))
            .padding(.bottom, 20)

            Text("潮安")
                .font(.system(size: 48, weight: .black))

            Text("登录后保存你的记录与报告")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.45, green: 0.41, blue: 0.44))
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
                .foregroundStyle(Color(red: 0.47, green: 0.41, blue: 0.44))
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
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.43, green: 0.34, blue: 0.40).opacity(0.12), radius: 30, y: 18)
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
            .foregroundStyle(Color(red: 0.43, green: 0.37, blue: 0.40))
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
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.91, green: 0.86, blue: 0.89), lineWidth: 1)
            }
    }
}

private struct SendCodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 116, height: 52)
            .background(Color(red: 0.64, green: 0.48, blue: 0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(red: 0.18, green: 0.16, blue: 0.18), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

#Preview {
    LoginView()
}
