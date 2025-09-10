//
//  AppEnvironment.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/6/25.
//

import UIKit

struct AppEnvironment {
    var speechClient: SpeechClient
    var soundEffectClient: SoundEffectClient
    var storageClient: StorageClient
    var openSettings: @MainActor () -> Void

    init() {
        speechClient = SpeechClient.liveValue
        soundEffectClient = SoundEffectClient()
        storageClient = StorageClient()
        openSettings = {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                assertionFailure()
                return
            }
            UIApplication.shared.open(url)
        }
    }
}

#if !DEBUG
nonisolated(unsafe) let appEnv = AppEnvironment()
#else
nonisolated(unsafe) var appEnv = AppEnvironment()
#endif
