//
//  AppFlowContainer.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/9/25.
//

import SwiftUI
import ReducerArchitecture
import AsyncNavigation

struct AppFlowContainer: View {
    var body: some View {
        UIKitNavigationFlow(SyncUpList.store(syncUps: appEnv.storageClient.allSyncUps())) { syncUp, proxy in
            await AppFlow(rootIndex: 0, syncUp: syncUp, proxy: proxy).run()
        }
    }
}
