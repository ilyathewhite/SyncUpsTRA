//
//  SyncUpsApp.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/6/25.
//

import SwiftUI
import ReducerArchitecture

@main
struct SyncUpsApp: App {
    init() {
        _ = appEnv // reference appEnv to force initialization
        // storeLifecycleLog.enabled = true
    }

    var body: some Scene {
        WindowGroup {
            AppFlowContainer()
        }
    }
}
