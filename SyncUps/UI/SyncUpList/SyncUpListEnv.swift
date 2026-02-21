//
//  SyncUpListEnv.swift
//  SyncUps
//
//  Created by Codex on 2/13/26.
//

extension SyncUpList {
    @MainActor
    static func createSyncUp(store: Store) async -> SyncUp? {
        let formStore = SyncUpForm.store(
            syncUp: .init(id: .init(), attendees: [Attendee(id: .init())]),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )
        if let syncUp = try? await store.run(formStore) {
            appEnv.storageClient.saveSyncUp(syncUp)
            return syncUp
        }
        else {
            return nil
        }
    }

    @MainActor
    static func allSyncUps() -> [SyncUp] {
        appEnv.storageClient.allSyncUps()
    }
}
