import Foundation
import Hammer
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.OverlayTests {
    @MainActor
    @Suite(.serialized) struct SyncUpDetailsOverlayTests {}
}

extension EventTests.OverlayTests.SyncUpDetailsOverlayTests {
    // MARK: - Edit Sheet

    // Trigger edit effect and publish edit-sheet result.
    // Expect child store to dismiss and sync-up model to update.
    @Test
    func editSyncUpEffectShowsEditSheetAndUpdatesStateAfterPublish() async throws {
        // Set up storage spy and isolated app environment.
        let spy = StorageSpy()
        let syncUp = makeSyncUp(title: "Design")
        try await withStorageSpyEnvironment(spy, currentSyncUp: syncUp) {
            // Set up details store and install real UI wiring.
            let detailsStore = SyncUpDetails.store(syncUp)
            _ = try await EventGenerator(
                view: NavigationStack {
                    detailsStore.contentView
                }
            )
            await Task.yield()
            #expect(detailsStore.environment != nil)
            spy.resetSavedSyncUps()

            // Set up edited result.
            let editedSyncUp = SyncUp(
                id: syncUp.id,
                attendees: [Attendee(id: .init(), name: "Blob"), Attendee(id: .init(), name: "Blob Jr.")],
                title: "Design + Product"
            )

            // Trigger edit flow.
            let editTask = detailsStore.send(.effect(.editSyncUp(syncUp)))
            await finishAnimation(.present, "edit sync-up form presentation")

            let formStore: SyncUpForm.Store? = detailsStore.child()
            #expect(formStore != nil)
            guard let formStore else { return }

            // Publish edited sync-up from sheet.
            await formStore.publishOnRequest(editedSyncUp)

            await editTask?.value
            await finishAnimation(.dismiss, "edit sync-up form dismissal")

            // Expect sheet dismisses and saved value matches edited sync-up.
            let childStore: SyncUpForm.Store? = detailsStore.child()
            #expect(childStore == nil)
            #expect(detailsStore.state.syncUp == editedSyncUp)
            #expect(spy.allSavedSyncUps() == [editedSyncUp])
        }
    }

    // Trigger edit effect and cancel edit-sheet result.
    // Expect child store to dismiss with no sync-up model changes.
    @Test
    func editSyncUpEffectShowsEditSheetAndDoesNothingOnCancel() async throws {
        // Set up storage spy and isolated app environment.
        let spy = StorageSpy()
        let syncUp = makeSyncUp(title: "Design")
        try await withStorageSpyEnvironment(spy, currentSyncUp: syncUp) {
            // Set up details store and install real UI wiring.
            let detailsStore = SyncUpDetails.store(syncUp)
            _ = try await EventGenerator(
                view: NavigationStack {
                    detailsStore.contentView
                }
            )
            await Task.yield()
            #expect(detailsStore.environment != nil)
            spy.resetSavedSyncUps()

            // Trigger edit flow.
            let editTask = detailsStore.send(.effect(.editSyncUp(syncUp)))
            await finishAnimation(.present, "edit sync-up form presentation")

            let formStore: SyncUpForm.Store? = detailsStore.child()
            #expect(formStore != nil)
            guard let formStore else { return }

            // Cancel from sheet.
            await formStore.cancelOnRequest()

            await editTask?.value
            await finishAnimation(.dismiss, "edit sync-up form dismissal")

            // Expect sheet dismisses with no model changes.
            let childStore: SyncUpForm.Store? = detailsStore.child()
            #expect(childStore == nil)
            #expect(detailsStore.state.syncUp == syncUp)
            #expect(spy.allSavedSyncUps().isEmpty)
        }
    }

    private func makeSyncUp(title: String) -> SyncUp {
        SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: title
        )
    }

    private func withStorageSpyEnvironment(
        _ spy: StorageSpy,
        currentSyncUp: SyncUp,
        operation: @MainActor () async throws -> Void
    ) async throws {
        try await withTaskIsolatedEnv(
            AppEnvironment.self,
            override: { @Sendable env in
                env.storageClient = makeSyncUpDetailsStorageClient(
                    spy: spy,
                    currentSyncUp: currentSyncUp
                )
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

    func latestSavedSyncUp() -> SyncUp? {
        lock.lock()
        defer { lock.unlock() }
        return savedSyncUps.last
    }

    func resetSavedSyncUps() {
        lock.lock()
        defer { lock.unlock() }
        savedSyncUps.removeAll()
    }
}

private func makeSyncUpDetailsStorageClient(
    spy: StorageSpy,
    currentSyncUp: SyncUp
) -> StorageClient {
    .init(
        allSyncUps: {
            let savedSyncUps = spy.allSavedSyncUps()
            return savedSyncUps.isEmpty ? [currentSyncUp] : savedSyncUps
        },
        saveSyncUp: { syncUp in
            spy.appendSavedSyncUp(syncUp)
        },
        deleteSyncUp: { _ in },
        saveMeetingNotes: { _, _ in },
        findSyncUp: { id in
            if let latest = spy.latestSavedSyncUp(), latest.id == id {
                return latest
            }
            return id == currentSyncUp.id ? currentSyncUp : nil
        }
    )
}
