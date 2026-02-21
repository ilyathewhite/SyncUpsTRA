import Foundation
import Testing

@testable import SyncUps

extension ModelTests {
    @MainActor
    @Suite struct SyncUpFormModelTests {}
}

extension ModelTests.SyncUpFormModelTests {
    // MARK: - State Updates

    // Update title.
    // Expect sync-up title state to update.
    @Test
    func updateTitleUpdatesTitleState() {
        // Set up form store.
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(), attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
                title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Update title.
        store.send(.mutating(.updateTitle("Product")))
        // Expect updated title.
        #expect(store.state.syncUp.title == "Product")
    }

    // Update duration minutes.
    // Expect sync-up duration state to update.
    @Test
    func updateDurationUpdatesDurationState() {
        // Set up form store.
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(), attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
                title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Update duration.
        store.send(.mutating(.updateDuration(minutes: 12)))
        // Expect updated duration.
        #expect(store.state.duration == 12)
    }

    // Update theme.
    // Expect sync-up theme state to update.
    @Test
    func updateThemeUpdatesThemeState() {
        // Set up form store.
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(), attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
                title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Update theme.
        store.send(.mutating(.updateTheme(.appOrange)))
        // Expect updated theme.
        #expect(store.state.syncUp.theme == .appOrange)
    }

    // Update one attendee name by id.
    // Expect only the matching attendee to update.
    @Test
    func updateAttendeeNameUpdatesMatchingAttendee() {
        // Set up two attendees.
        let attendee1 = Attendee(id: Attendee.ID(), name: "Blob")
        let attendee2 = Attendee(id: Attendee.ID(), name: "Blob Jr.")
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(),
                attendees: [attendee1, attendee2],
                title: "Engineering"
            ),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Edit second attendee.
        store.send(.mutating(.updateAttendeeName(id: attendee2.id, name: "Blob Sr.")))

        // Expect only matching attendee changed.
        #expect(store.state.syncUp.attendees[0].name == "Blob")
        #expect(store.state.syncUp.attendees[1].name == "Blob Sr.")
    }

    // MARK: - Save Validation

    // Start with no attendees.
    // Expect save to require at least one attendee.
    @Test
    func canSaveRequiresAtLeastOneAttendee() {
        // Set up empty attendee list.
        var state = SyncUpForm.StoreState(
            syncUp: SyncUp(id: SyncUp.ID(), attendees: [], title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Expect initially invalid.
        #expect(!state.canSave)

        // Add attendee.
        state.syncUp.attendees.append(Attendee(id: Attendee.ID(), name: "Blob"))

        // Expect now valid.
        #expect(state.canSave)
    }

    // Save requires non-empty title and non-empty attendee names.
    @Test
    func canSaveRequiresTitleAndNamedAttendees() {
        // Set up empty title and attendee name.
        let attendee = Attendee(id: Attendee.ID(), name: "")
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(),
                attendees: [attendee],
                title: ""
            ),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Expect initially invalid.
        #expect(!store.state.canSave)

        // Set title only.
        store.send(.mutating(.updateTitle("Engineering")))
        // Expect still invalid.
        #expect(!store.state.canSave)

        // Set attendee name.
        store.send(.mutating(.updateAttendeeName(id: attendee.id, name: "Blob")))
        // Expect now valid.
        #expect(store.state.canSave)
    }

    // MARK: - Attendee Mutations

    // Add attendee and expect edit callback for the new id.
    @Test
    func addAttendeeRequestsEditingNewAttendee() {
        // Set up store and edit callback spy.
        var editedAttendeeID: Attendee.ID?

        let store = SyncUpForm.store(
            syncUp: SyncUp(id: SyncUp.ID(), attendees: [], title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )
        store.environment = .init(editAttendee: { id in
            editedAttendeeID = id
        })

        // Add attendee.
        store.send(.mutating(.addAttendee))

        // Expect attendee appended and edit requested for new id.
        #expect(store.state.syncUp.attendees.count == 1)
        #expect(editedAttendeeID == store.state.syncUp.attendees[0].id)
    }

    // Remove by id and expect only that attendee to be removed.
    @Test
    func removeAttendeeRemovesMatchingID() {
        // Set up two attendees.
        let attendee1 = Attendee(id: Attendee.ID(), name: "Blob")
        let attendee2 = Attendee(id: Attendee.ID(), name: "Blob Jr.")
        var state = SyncUpForm.StoreState(
            syncUp: SyncUp(
                id: SyncUp.ID(),
                attendees: [attendee1, attendee2],
                title: "Engineering"
            ),
            title: "Edit sync-up",
            saveTitle: "Done",
            cancelTitle: "Cancel"
        )

        // Remove first attendee.
        _ = SyncUpForm.reduce(&state, .removeAttendee(id: attendee1.id))

        // Expect only second attendee remains.
        #expect(state.syncUp.attendees == [attendee2])
    }

    // MARK: - Effects

    // Run edit-attendee effect.
    // Expect callback to receive matching attendee id.
    @Test
    func editAttendeeEffectInvokesEnvironmentCallback() {
        // Set up effect inputs.
        let attendeeID = Attendee.ID()
        var receivedID: Attendee.ID?
        let env = SyncUpForm.StoreEnvironment(editAttendee: { id in
            receivedID = id
        })
        let state = SyncUpForm.StoreState(
            syncUp: SyncUp(id: SyncUp.ID(), attendees: [], title: "Engineering"),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )

        // Run effect.
        _ = SyncUpForm.runEffect(env, state, .editAttendee(attendeeID))

        // Expect callback received matching id.
        #expect(receivedID == attendeeID)
    }
}
