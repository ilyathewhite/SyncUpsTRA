import Foundation
import SwiftUIExTesting
import Testing
@testable import SyncUps

extension ModelTests {
    @MainActor
    @Suite struct SyncUpListModelTests {}
}

extension ModelTests.SyncUpListModelTests {
    // MARK: - State Updates

    // Send reload mutation.
    // Expect list state to be replaced.
    @Test
    func reloadMutationReplacesSyncUpsState() {
        // Set up initial and updated sync-ups.
        let original = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Original"
        )
        let updated = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob Jr.")],
            title: "Updated"
        )
        let store = SyncUpList.store(syncUps: [original])

        // Send reload mutation.
        store.send(.mutating(.reload([updated])))
        // Expect list replaced.
        #expect(store.state.syncUps == [updated])
    }

    // MARK: - Effects

    // Trigger reload effect.
    // Expect state to update from allSyncUps.
    @Test
    func reloadEffectLoadsAllSyncUpsFromEnvironment() async throws {
        // Set up environment to return sync-ups.
        let expected = [
            SyncUp(
                id: SyncUp.ID(),
                attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
                title: "Engineering"
            ),
            SyncUp(
                id: SyncUp.ID(),
                attendees: [Attendee(id: Attendee.ID(), name: "Blob Jr.")],
                title: "Product"
            ),
        ]
        var allSyncUpsCallCount = 0
        let store = SyncUpList.store(syncUps: [])
        store.environment = .init(
            createSyncUp: { nil },
            allSyncUps: {
                allSyncUpsCallCount += 1
                return expected
            }
        )

        // Trigger reload effect.
        await store.send(.effect(.reload))?.value

        // Expect environment called and state updated.
        #expect(allSyncUpsCallCount == 1)
        #expect(store.state.syncUps == expected)
    }

    // Trigger add effect with successful creation.
    // Expect reload effect to refresh list state.
    @Test
    func addSyncUpEffectReloadsAllSyncUpsAfterCreation() async throws {
        // Set up creation and reload spies.
        let createdSyncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        var createCallCount = 0
        var allSyncUpsCallCount = 0

        let store = SyncUpList.store(syncUps: [])
        store.environment = .init(
            createSyncUp: {
                createCallCount += 1
                return createdSyncUp
            },
            allSyncUps: {
                allSyncUpsCallCount += 1
                return [createdSyncUp]
            }
        )

        // Trigger add flow.
        await store.send(.effect(.addSyncUp))?.value

        // Expect create then reload happened.
        #expect(createCallCount == 1)
        #expect(allSyncUpsCallCount == 1)
        #expect(store.state.syncUps == [createdSyncUp])
    }

    // Trigger add effect with cancelled creation.
    // Expect no reload and no list mutation.
    @Test
    func addSyncUpEffectDoesNotReloadWhenCreationIsCancelled() async throws {
        // Set up cancelled create path.
        var createCallCount = 0
        var allSyncUpsCallCount = 0

        let store = SyncUpList.store(syncUps: [])
        store.environment = .init(
            createSyncUp: {
                createCallCount += 1
                return nil
            },
            allSyncUps: {
                allSyncUpsCallCount += 1
                return [.mock]
            }
        )

        // Trigger add flow.
        await store.send(.effect(.addSyncUp))?.value

        // Expect no reload and no state change.
        #expect(createCallCount == 1)
        #expect(allSyncUpsCallCount == 0)
        #expect(store.state.syncUps.isEmpty)
    }
}
