//
//  menocalmxiaTests.swift
//  menocalmxiaTests
//
//  Created by Jiaying He on 2026/5/22.
//

import Foundation
import Testing
@testable import menocalmxia

struct menocalmxiaTests {

    @MainActor
    @Test func loginValidationRequiresAnElevenDigitMobile() {
        let viewModel = LoginViewModel()
        viewModel.mobile = "13800138000"
        #expect(viewModel.canSendCode)
        viewModel.mobile = "1380013800"
        #expect(!viewModel.canSendCode)
    }

    @MainActor
    @Test func loginValidationAcceptsFourToEightDigitCodes() {
        let viewModel = LoginViewModel()
        viewModel.mobile = "13800138000"
        viewModel.code = "1234"
        #expect(viewModel.canLogin)
        viewModel.code = "123456789"
        #expect(!viewModel.canLogin)
    }

    @MainActor
    @Test func inputNormalizationKeepsOnlySupportedDigits() {
        let viewModel = LoginViewModel()
        viewModel.mobile = "138-0013-8000-extra"
        viewModel.code = "12 34 56 78 90"
        viewModel.normalizeMobile()
        viewModel.normalizeCode()
        #expect(viewModel.mobile == "13800138000")
        #expect(viewModel.code == "12345678")
    }

    @MainActor
    @Test func loginResponseDecodesSnakeCaseFields() throws {
        let json = #"{"success":true,"mobile":"13800138000","block_id":"abc","database":"helen1"}"#.data(using: .utf8)!
        let response = try JSONDecoder().decode(LoginResponse.self, from: json)
        #expect(response.success == true)
        #expect(response.blockId == "abc")
        #expect(response.database == "helen1")
    }

}
