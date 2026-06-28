//
//  menocalmxiaApp.swift
//  menocalmxia
//
//  Created by Jiaying He on 2026/5/22.
//

import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = nil
        tabBarAppearance.backgroundColor = .clear
        tabBarAppearance.shadowColor = .clear
        tabBarAppearance.shadowImage = UIImage()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        ReminderNotificationManager.configureDelegate(self)
        Task {
            let status = await ReminderNotificationManager.authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else {
                return
            }
            let settings = ReminderSettingsStore.load()
            try? await ReminderNotificationManager.syncAll(settings: settings)
        }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }
}

@main
struct menocalmxiaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
