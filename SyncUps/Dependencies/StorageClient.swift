//
//  StorageClient.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/9/25.
//

struct StorageClient {
    var allSyncUps: @MainActor () -> [SyncUp]
    var saveSyncUp: @MainActor (SyncUp) -> Void
    var deleteSyncUp: @MainActor (SyncUp) -> Void
    var saveMeetingNotes: @MainActor (SyncUp, Meeting) -> Void
    var findSyncUp: @MainActor (SyncUp.ID) -> SyncUp?

    init() {
        allSyncUps = {
            Storage.shared.allSyncUps()
        }

        saveSyncUp = {
            Storage.shared.saveSyncUp($0)
        }

        deleteSyncUp = {
            Storage.shared.deleteSyncUp($0)
        }

        saveMeetingNotes = {
            Storage.shared.saveMeetingNotes($0, $1)
        }

        findSyncUp = {
            Storage.shared.findSyncUp($0)
        }
    }
}

private class Storage {
    nonisolated(unsafe) static let shared = Storage()

    private var syncUps: [SyncUp] = SyncUp.sampleList

    func allSyncUps() -> [SyncUp] {
        syncUps
    }

    func findSyncUp(_ id: SyncUp.ID) -> SyncUp? {
        syncUps.first { $0.id == id }
    }

    func saveSyncUp(_ syncUp: SyncUp) {
        if let index = syncUps.firstIndex(where: { $0.id == syncUp.id }) {
            syncUps[index] = syncUp
        }
        else {
            syncUps.append(syncUp)
        }
    }

    func deleteSyncUp(_ syncUp: SyncUp) {
        guard let index = syncUps.firstIndex(where: { $0.id == syncUp.id }) else {
            assertionFailure()
            return
        }
        syncUps.remove(at: index)
    }

    func saveMeetingNotes(_ syncUp: SyncUp, _ meeting: Meeting) {
        guard let index = syncUps.firstIndex(where: { $0.id == syncUp.id }) else {
            assertionFailure()
            return
        }
        syncUps[index].meetings.insert(meeting, at: 0)
    }
}
