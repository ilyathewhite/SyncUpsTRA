//
//  AppEnvironment.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/6/25.
//

import UIKit
import TaskIsolatedEnv

struct AppEnvironment: TaskIsolatedEnvType {
    var speechClient: SpeechClient
    var soundEffectClient: SoundEffectClient
    var storageClient: StorageClient
    var now: @Sendable () -> Date
    var openSettings: @MainActor () -> Void

    static let speechClient = SpeechClient.liveValue
    static let soundEffectClient = SoundEffectClient.liveValue
    static let storageClient = StorageClient.liveValue
    static let now: @Sendable () -> Date = { Date.now }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            assertionFailure()
            return
        }
        UIApplication.shared.open(url)
    }

    static let liveValue = Self(
        speechClient: Self.speechClient,
        soundEffectClient: Self.soundEffectClient,
        storageClient: Self.storageClient,
        now: Self.now,
        openSettings: Self.openSettings
    )
}

var appEnv: AppEnvironment {
    currentTaskIsolatedEnv(AppEnvironment.self)
}
