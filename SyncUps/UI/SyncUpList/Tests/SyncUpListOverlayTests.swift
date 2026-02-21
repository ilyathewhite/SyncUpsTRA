import Foundation
import Hammer
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.OverlayTests {
    @MainActor
    @Suite(.serialized) struct SyncUpListOverlayTests {}
}

extension EventTests.OverlayTests.SyncUpListOverlayTests {
    // Trigger add effect and publish create-sheet result.
    // Expect child store to dismiss and list model to reload.
    @Test
    func addSyncUpEffectShowsCreateSheetAndReloadsAfterPublish() async throws {
        // Set up storage spy and isolated app environment.
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up list store and install real UI wiring.
            let listStore = SyncUpList.store(syncUps: [])
            _ = try await EventGenerator(
                view: NavigationStack {
                    listStore.contentView
                }
            )
            await Task.yield()
            #expect(listStore.environment != nil)

            // Trigger add flow.
            let addTask = listStore.send(.effect(.addSyncUp))
            await finishAnimation(.present, "sync-up form presentation")

            let formStore: SyncUpForm.Store? = listStore.child()
            #expect(formStore != nil)
            guard let formStore else { return }

            // Publish created sync-up from sheet.
            let createdSyncUp = SyncUp(
                id: formStore.state.syncUp.id,
                attendees: [Attendee(id: .init(), name: "Blob")],
                title: "Design"
            )
            await formStore.publishOnRequest(createdSyncUp)

            await addTask?.value
            await finishAnimation(.dismiss, "sync-up form dismissal")

            // Expect sheet dismisses and persisted values.
            let childStore: SyncUpForm.Store? = listStore.child()
            #expect(childStore == nil)
            #expect(listStore.state.syncUps == [createdSyncUp])
            #expect(spy.allSavedSyncUps() == [createdSyncUp])
        }
    }

    // Trigger add effect and cancel create-sheet result.
    // Expect child store to dismiss with no list-model changes.
    @Test
    func addSyncUpEffectShowsCreateSheetAndDoesNothingOnCancel() async throws {
        // Set up storage spy and isolated app environment.
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up list store and install real UI wiring.
            let listStore = SyncUpList.store(syncUps: [])
            _ = try await EventGenerator(
                view: NavigationStack {
                    listStore.contentView
                }
            )
            await Task.yield()
            #expect(listStore.environment != nil)

            // Trigger add flow.
            let addTask = listStore.send(.effect(.addSyncUp))
            await finishAnimation(.present, "sync-up form presentation")

            let formStore: SyncUpForm.Store? = listStore.child()
            #expect(formStore != nil)
            guard let formStore else { return }

            // Cancel from sheet.
            await formStore.cancelOnRequest()

            await addTask?.value
            await finishAnimation(.dismiss, "sync-up form dismissal")

            // Expect sheet dismisses with no model changes.
            let childStore: SyncUpForm.Store? = listStore.child()
            #expect(childStore == nil)
            #expect(spy.allSavedSyncUps().isEmpty)
            #expect(listStore.state.syncUps.isEmpty)
        }
    }

    private func withStorageSpyEnvironment(
        _ spy: StorageSpy,
        operation: @MainActor () async throws -> Void
    ) async throws {
        try await withTaskIsolatedEnv(
            AppEnvironment.self,
            override: { @Sendable env in
                env.storageClient = makeSyncUpListStorageClient(spy: spy)
            },
            operation: operation
        )
    }
}

private final class StorageSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var savedSyncUps: [SyncUp] = []

    func allSavedSyncUps() -> [SyncUp] {
        lock.lock()
        defer { lock.unlock() }
        return savedSyncUps
    }

    func appendSavedSyncUp(_ syncUp: SyncUp) {
        lock.lock()
        defer { lock.unlock() }
        savedSyncUps.append(syncUp)
    }
}

private func makeSyncUpListStorageClient(spy: StorageSpy) -> StorageClient {
    .init(
        allSyncUps: { spy.allSavedSyncUps() },
        saveSyncUp: { syncUp in
            spy.appendSavedSyncUp(syncUp)
        },
        deleteSyncUp: { _ in },
        saveMeetingNotes: { _, _ in },
        findSyncUp: { _ in nil }
    )
}
