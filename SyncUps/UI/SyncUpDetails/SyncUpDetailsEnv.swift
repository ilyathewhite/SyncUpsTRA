//
//  SyncUpDetailsEnv.swift
//  SyncUps
//
//  Created by Codex on 2/13/26.
//

extension SyncUpDetails {
    @MainActor
    static func edit(syncUp: SyncUp, store: Store) async -> SyncUp? {
        let editStore = SyncUpForm.store(
            syncUp: syncUp,
            title: syncUp.title,
            saveTitle: "Done",
            cancelTitle: "Cancel"
        )
        return try? await store.run(editStore)
    }

    @MainActor
    static func save(syncUp: SyncUp) {
        appEnv.storageClient.saveSyncUp(syncUp)
    }

    @MainActor
    static func find(id: SyncUp.ID) -> SyncUp? {
        appEnv.storageClient.findSyncUp(id)
    }

    static func checkSpeechRecognitionAuthorization() -> AuthorizationStatus {
        switch appEnv.speechClient.authorizationStatus() {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        default:
            return .notDetermined
        }
    }

    @MainActor
    static func openSettings() {
        appEnv.openSettings()
    }
}
