import Foundation
import SwiftUIExTesting
import Testing

@testable import SyncUps

extension ModelTests {
    @MainActor
    @Suite struct SyncUpDetailsModelTests {}
}

extension ModelTests.SyncUpDetailsModelTests {
    // MARK: - State Updates

    // Delete meeting by id.
    // Expect meeting removed and sync-up saved.
    @Test
    func deleteMeetingMutationRemovesMeetingAndSavesSyncUp() {
        // Set up sync-up with two meetings.
        let meeting1 = Meeting(id: Meeting.ID(), date: Date(timeIntervalSince1970: 111), transcript: "One")
        let meeting2 = Meeting(id: Meeting.ID(), date: Date(timeIntervalSince1970: 222), transcript: "Two")
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            meetings: [meeting1, meeting2],
            title: "Design"
        )
        var savedSyncUp: SyncUp?
        let store = SyncUpDetails.store(syncUp)
        store.environment = makeEnvironment(save: { syncUp in
            savedSyncUp = syncUp
        })

        // Delete first meeting.
        store.send(.mutating(.deleteMeeting(meeting1.id)))

        // Expect meeting removed and sync-up saved.
        #expect(store.state.syncUp.meetings == [meeting2])
        #expect(savedSyncUp == store.state.syncUp)
    }

    // Send update mutation with same sync-up id.
    // Expect state replacement and save call.
    @Test
    func updateMutationReplacesSyncUpAndSavesSyncUp() {
        // Set up initial and updated sync-up values.
        let id = SyncUp.ID()
        let initial = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            theme: .bubblegum,
            title: "Design"
        )
        let updated = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob Jr")],
            duration: .seconds(60 * 10),
            meetings: [
                Meeting(id: Meeting.ID(), date: Date(timeIntervalSince1970: 333), transcript: "Updated")
            ],
            theme: .appOrange,
            title: "Engineering"
        )
        var savedSyncUp: SyncUp?
        let store = SyncUpDetails.store(initial)
        store.environment = makeEnvironment(save: { syncUp in
            savedSyncUp = syncUp
        })

        // Update sync-up state.
        store.send(.mutating(.update(updated)))

        // Expect state replaced and saved.
        #expect(store.state.syncUp == updated)
        #expect(savedSyncUp == updated)
    }

    // MARK: - Effects

    // Trigger edit effect and return edited sync-up.
    // Expect state update and save call.
    @Test
    func editSyncUpEffectUpdatesStateAndSavesWhenEdited() async throws {
        // Set up edit flow that returns updated sync-up.
        let id = SyncUp.ID()
        let initial = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        let updated = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            theme: .lavender,
            title: "Engineering"
        )
        var savedSyncUp: SyncUp?
        var editCallCount = 0
        let store = SyncUpDetails.store(initial)
        store.environment = makeEnvironment(
            edit: { _ in
                editCallCount += 1
                return updated
            },
            save: { syncUp in
                savedSyncUp = syncUp
            }
        )

        // Trigger edit effect.
        await store.send(.effect(.editSyncUp(initial)))?.value

        // Expect edit ran once and updated model.
        #expect(editCallCount == 1)
        #expect(store.state.syncUp == updated)
        #expect(savedSyncUp == updated)
    }

    // Trigger edit effect and return nil.
    // Expect no state update and no save call.
    @Test
    func editSyncUpEffectDoesNothingWhenEditCancelled() async throws {
        // Set up edit flow that returns nil.
        let initial = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        var saveCallCount = 0
        var editCallCount = 0
        let store = SyncUpDetails.store(initial)
        store.environment = makeEnvironment(
            edit: { _ in
                editCallCount += 1
                return nil
            },
            save: { _ in
                saveCallCount += 1
            }
        )

        // Trigger edit effect.
        await store.send(.effect(.editSyncUp(initial)))?.value

        // Expect no save and no model change.
        #expect(editCallCount == 1)
        #expect(saveCallCount == 0)
        #expect(store.state.syncUp == initial)
    }

    // Trigger delete confirmation and confirm.
    // Expect delete action to publish.
    @Test
    func confirmDeleteSyncUpEffectPublishesDeleteWhenConfirmed() async throws {
        // Set up confirm-delete to return true.
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(confirmDelete: { true })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Trigger delete confirmation effect.
        await store.send(.effect(.confirmDeleteSyncUp))?.value
        let value = try await valueTask.value

        // Expect delete action published.
        #expect(isDeleteSyncUp(value))
    }

    // Trigger delete confirmation and cancel.
    // Expect no published action.
    @Test
    func confirmDeleteSyncUpEffectDoesNothingWhenCancelled() async throws {
        // Set up confirm-delete to return false.
        var confirmDeleteCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(confirmDelete: {
            confirmDeleteCallCount += 1
            return false
        })

        // Trigger delete confirmation effect.
        await store.send(.effect(.confirmDeleteSyncUp))?.value

        // Expect prompt was shown once.
        #expect(confirmDeleteCallCount == 1)
    }

    // Trigger save effect.
    // Expect save callback to receive same sync-up.
    @Test
    func saveSyncUpEffectInvokesSaveCallback() async throws {
        // Set up sync-up and save spy.
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        var savedSyncUp: SyncUp?
        let store = SyncUpDetails.store(syncUp)
        store.environment = makeEnvironment(save: { value in
            savedSyncUp = value
        })

        // Trigger save effect.
        await store.send(.effect(.saveSyncUp(syncUp)))?.value
        // Expect save callback invoked.
        #expect(savedSyncUp == syncUp)
    }

    // Trigger update-sync-up effect.
    // Expect state update from find and save call.
    @Test
    func updateSyncUpEffectLoadsFoundSyncUpAndSaves() async throws {
        // Set up find to return updated sync-up.
        let id = SyncUp.ID()
        let initial = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        let found = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob Jr")],
            duration: .seconds(60 * 15),
            theme: .appOrange,
            title: "Engineering"
        )
        var savedSyncUp: SyncUp?
        let store = SyncUpDetails.store(initial)
        store.environment = makeEnvironment(
            save: { syncUp in
                savedSyncUp = syncUp
            },
            find: { _ in found }
        )

        // Trigger update-sync-up effect.
        await store.send(.effect(.updateSyncUp))?.value

        // Expect state loaded and saved.
        #expect(store.state.syncUp == found)
        #expect(savedSyncUp == found)
    }

    // Trigger start meeting with authorized speech access.
    // Expect start meeting action to publish.
    @Test
    func startMeetingEffectPublishesWhenAuthorized() async throws {
        // Set up authorized status.
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(authorizationStatus: { .authorized })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value
        let value = try await valueTask.value

        // Expect start-meeting published.
        #expect(isStartMeeting(value))
    }

    // Trigger start meeting with not-determined speech access.
    // Expect start meeting action to publish.
    @Test
    func startMeetingEffectPublishesWhenNotDetermined() async throws {
        // Set up not-determined status.
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(authorizationStatus: { .notDetermined })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value
        let value = try await valueTask.value

        // Expect start-meeting published.
        #expect(isStartMeeting(value))
    }

    // Trigger start meeting with restricted speech access and continue.
    // Expect restricted alert and start meeting publish.
    @Test
    func startMeetingEffectRestrictedCanPublishStartMeetingFromAlert() async throws {
        // Set up restricted status and alert response.
        var restrictedAlertCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(
            authorizationStatus: { .restricted },
            showRestrictedAlert: {
                restrictedAlertCallCount += 1
                return .startMeeting
            }
        )

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value
        let value = try await valueTask.value

        // Expect alert shown and start-meeting published.
        #expect(restrictedAlertCallCount == 1)
        #expect(isStartMeeting(value))
    }

    // Trigger start meeting with restricted speech access and cancel.
    // Expect restricted alert without publish.
    @Test
    func startMeetingEffectRestrictedNoActionFromAlertDoesNothing() async throws {
        // Set up restricted status and no-action alert response.
        var restrictedAlertCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(
            authorizationStatus: { .restricted },
            showRestrictedAlert: {
                restrictedAlertCallCount += 1
                return .noAction
            }
        )

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value

        // Expect alert shown with no publish.
        #expect(restrictedAlertCallCount == 1)
    }

    // Trigger start meeting with denied speech access and open settings.
    // Expect denied alert and open settings callback.
    @Test
    func startMeetingEffectDeniedCanOpenSettingsFromAlert() async throws {
        // Set up denied status and open-settings alert response.
        var deniedAlertCallCount = 0
        var openSettingsCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(
            authorizationStatus: { .denied },
            showDeniedAlert: {
                deniedAlertCallCount += 1
                return .openSettings
            },
            openSettings: {
                openSettingsCallCount += 1
            }
        )

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value

        // Expect alert shown and settings opened.
        #expect(deniedAlertCallCount == 1)
        #expect(openSettingsCallCount == 1)
    }

    // Trigger start meeting with denied speech access and continue.
    // Expect denied alert and start meeting publish.
    @Test
    func startMeetingEffectDeniedCanPublishStartMeetingFromAlert() async throws {
        // Set up denied status and alert response.
        var deniedAlertCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(
            authorizationStatus: { .denied },
            showDeniedAlert: {
                deniedAlertCallCount += 1
                return .startMeeting
            }
        )

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value
        let value = try await valueTask.value

        // Expect alert shown and start-meeting published.
        #expect(deniedAlertCallCount == 1)
        #expect(isStartMeeting(value))
    }

    // Trigger start meeting with denied speech access and cancel.
    // Expect denied alert and no open settings callback.
    @Test
    func startMeetingEffectDeniedNoActionFromAlertDoesNothing() async throws {
        // Set up denied status and no-action alert response.
        var deniedAlertCallCount = 0
        var openSettingsCallCount = 0
        let store = SyncUpDetails.store(.mock)
        store.environment = makeEnvironment(
            authorizationStatus: { .denied },
            showDeniedAlert: {
                deniedAlertCallCount += 1
                return .noAction
            },
            openSettings: {
                openSettingsCallCount += 1
            }
        )

        // Start meeting.
        await store.send(.effect(.startMeeting))?.value

        // Expect alert shown and settings not opened.
        #expect(deniedAlertCallCount == 1)
        #expect(openSettingsCallCount == 0)
    }

    private func makeEnvironment(
        edit: @escaping (SyncUp) async -> SyncUp? = { _ in nil },
        save: @escaping (SyncUp) -> Void = { _ in },
        find: @escaping (SyncUp.ID) -> SyncUp? = { _ in nil },
        confirmDelete: @escaping () async throws -> Bool = { false },
        authorizationStatus: @escaping () -> SyncUpDetails.AuthorizationStatus = { .authorized },
        showRestrictedAlert: @escaping () async throws -> SyncUpDetails.SpeechRecognitionRestrictedAlertResult = {
            .noAction
        },
        showDeniedAlert: @escaping () async throws -> SyncUpDetails.SpeechRecognitionDeniedAlertResult = {
            .noAction
        },
        openSettings: @escaping () -> Void = {}
    ) -> SyncUpDetails.StoreEnvironment {
        .init(
            edit: edit,
            save: save,
            find: find,
            confirmDelete: confirmDelete,
            checkSpeechRecognitionAuthorization: authorizationStatus,
            showSpeechRecognitionRestrictedAlert: showRestrictedAlert,
            showSpeechRecognitionDeniedAlert: showDeniedAlert,
            openSettings: openSettings
        )
    }
    private func isStartMeeting(_ value: SyncUpDetails.ResultAction) -> Bool {
        if case .startMeeting = value {
            return true
        }
        return false
    }

    private func isDeleteSyncUp(_ value: SyncUpDetails.ResultAction) -> Bool {
        if case .deleteSyncUp = value {
            return true
        }
        return false
    }
}
