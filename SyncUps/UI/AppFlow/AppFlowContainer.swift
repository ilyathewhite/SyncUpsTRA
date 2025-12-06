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
    func syncUpList() -> RootNavigationNode<SyncUpList> {
        .init(SyncUpList.store(syncUps: appEnv.storageClient.allSyncUps()))
    }

    var body: some View {
        NavigationFlow(syncUpList()) { syncUp, proxy in
            await AppFlow(rootIndex: 0, syncUp: syncUp, proxy: proxy).run()
        }
    }
}
