import Foundation
import Hammer
import SwiftUI
import SwiftUIExTesting
import Testing

@testable import SyncUps

extension EventTests.UserEventTests {
    @MainActor
    @Suite(.serialized) struct SyncUpListUserEventTests {}
}

extension EventTests.UserEventTests.SyncUpListUserEventTests {
    private typealias Nsp = SyncUpList

    // MARK: - List Actions

    // Tap sync-up row.
    // Expect selected sync-up to publish.
    @Test
    func syncUpRowTapPublishesSelectedSyncUp() async throws {
        // Set up list store and event generator.
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Engineering"
        )
        let store = makeStore(syncUps: [syncUp])
        let eg = try await EventGenerator(
            view: NavigationStack {
                store.contentView
            }
        )

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Tap sync-up row.
        try eg.fingerTap(at: Nsp.row(syncUp.id))
        let value = try await valueTask.value

        // Expect selected sync-up published.
        #expect(value == syncUp)
    }

    // MARK: - Toolbar Actions

    // Tap add button.
    // Expect create and reload effects to update list state.
    @Test
    func addButtonTapCreatesSyncUpAndReloadsList() async throws {
        // Set up add flow dependencies.
        let (reloadCalls, reloadContinuation) = AsyncStream<Void>.makeStream()
        var reloadIterator = reloadCalls.makeAsyncIterator()
        let createdSyncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        var createCallCount = 0
        var allSyncUpsCallCount = 0

        let store = makeStore(syncUps: [])
        let eg = try await EventGenerator(
            view: NavigationStack {
                store.contentView
            }
        )
        store.environment = .init(
            createSyncUp: {
                createCallCount += 1
                return createdSyncUp
            },
            allSyncUps: {
                allSyncUpsCallCount += 1
                reloadContinuation.yield()
                reloadContinuation.finish()
                return [createdSyncUp]
            }
        )

        // Tap add button.
        try eg.fingerTap(at: Nsp.addButton)
        _ = await reloadIterator.next()

        // Expect list reloaded with created sync-up.
        #expect(createCallCount == 1)
        #expect(allSyncUpsCallCount == 1)
        #expect(store.state.syncUps == [createdSyncUp])
    }

    private func makeStore(syncUps: [SyncUp]) -> Nsp.Store {
        Nsp.store(syncUps: syncUps)
    }
}
