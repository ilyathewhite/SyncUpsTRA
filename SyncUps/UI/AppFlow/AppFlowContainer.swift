//
//  AppFlowContainer.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/9/25.
//

import SwiftUI
import ReducerArchitecture

struct AppFlowContainer: View {
    var body: some View {
        UIKitNavigationFlow(root: SyncUpList.store(syncUps: appEnv.storageClient.allSyncUps())) { syncUp, env in
            await AppFlow(rootIndex: 0, syncUp: syncUp, env: env).run()
        }
    }
}
