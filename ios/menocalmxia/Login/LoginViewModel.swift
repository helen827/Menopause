import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var mobile = ""
    @Published var code = ""
    @Published var status = "等待输入手机号"
    @Published var isLoading = false
    @Published var isCodeSending = false
    @Published var showingForm = false
    @Published var loginResult: LoginResponse?

    private var outId = ""

    var canSendCode: Bool {
        mobile.range(of: #"^\d{11}$"#, options: .regularExpression) != nil
    }

    var canLogin: Bool {
        canSendCode && code.range(of: #"^\d{4,8}$"#, options: .regularExpression) != nil
    }

    func openForm(message: String = "等待输入手机号") {
        showingForm = true
        status = message
    }

    func closeForm() {
        showingForm = false
        status = "等待输入手机号"
        loginResult = nil
    }

    func normalizeMobile() {
        mobile = String(mobile.filter(\.isNumber).prefix(11))
    }

    func normalizeCode() {
        code = String(code.filter(\.isNumber).prefix(8))
    }

    func sendCode() async {
        guard canSendCode else {
            status = "请输入 11 位手机号"
            return
        }

        isCodeSending = true
        status = "正在发送验证码..."
        defer { isCodeSending = false }

        do {
            let response = try await AuthAPI.shared.sendCode(mobile: mobile)
            outId = response.outId ?? ""
            status = response.success ? "验证码已发送，请查看短信" : "发送失败"
        } catch {
            status = error.localizedDescription
        }
    }

    func login() async {
        guard canLogin else {
            status = "请输入正确的手机号和验证码"
            return
        }

        isLoading = true
        status = "正在登录..."
        defer { isLoading = false }

        do {
            let response = try await AuthAPI.shared.login(mobile: mobile, code: code, outId: outId)
            loginResult = response
            status = "登录成功"
        } catch {
            status = error.localizedDescription
        }
    }
}
