import Foundation
import Combine

struct UserSession: Codable, Equatable {
    let mobile: String
    let login: String
    let blockId: String
    let database: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: UserSession?

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
