import Foundation
import Hammer
import SwiftUIExTesting
import Testing

@testable import SyncUps

extension EventTests.UserEventTests {
    @MainActor
    @Suite(.serialized) struct SyncUpFormUserEventTests {}
}

extension EventTests.UserEventTests.SyncUpFormUserEventTests {
    private typealias Nsp = SyncUpForm

    // MARK: - Form Fields

    // Type in title field.
    // Expect title state to update.
    @Test
    func titleFieldTypingUpdatesTitle() async throws {
        // Set up store and event generator.
        let store = makeStore(attendees: [Attendee(id: Attendee.ID(), name: "Blob")], title: "")
        let eg = try await EventGenerator(view: store.contentView)

        // Focus and type title.
        try eg.fingerTap(at: Nsp.titleField)
        try eg.keyType("Engineering")

        // Expect title updated.
        #expect(store.state.syncUp.title == "Engineering")
    }

    // Hold and move duration slider.
    // Expect duration state to change.
    @Test
    func durationSliderHoldThenMoveUpdatesDuration() async throws {
        // Set up store and event generator.
        let store = makeStore(attendees: [Attendee(id: Attendee.ID(), name: "Blob")], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)
        let initialDuration = store.state.syncUp.duration

        // Hold slider thumb, then move slightly.
        let slider = try eg.viewWithIdentifier(Nsp.durationSlider)
        let finger: FingerIndex = .rightIndex
        try eg.fingerDown(finger, at: RelativeLocation(location: slider, x: 0.1, y: 0.5))
        try eg.fingerMove([finger], translationX: 50, y: 0, duration: 0.2)
        try eg.fingerUp(finger)
        try await Task.sleep(for: .seconds(0.5))

        // Expect duration changed.
        #expect(store.state.syncUp.duration != initialDuration)
    }

    // Open theme picker and select theme option.
    // Expect theme state to update.
    @Test
    func themePickerSelectionUpdatesTheme() async throws {
        // Set up store and event generator.
        let store = makeStore(attendees: [Attendee(id: Attendee.ID(), name: "Blob")], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)

        // Expect initial theme.
        #expect(store.state.syncUp.theme == .bubblegum)

        // Open picker and choose Orange.
        try eg.fingerTap(at: Nsp.themePicker)
        await finishAnimation(.push, "theme picker presentation")
        try eg.fingerTap(at: try viewWithAccessibilityLabel("Orange"))

        // Expect theme updated.
        #expect(store.state.syncUp.theme == .appOrange)
    }

    // MARK: - Attendee Actions

    // Type in attendee field.
    // Expect attendee name state to update.
    @Test
    func attendeeFieldTypingUpdatesAttendeeName() async throws {
        // Set up store and event generator.
        let attendee = Attendee(id: Attendee.ID(), name: "")
        let store = makeStore(attendees: [attendee], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)

        // Focus and type attendee name.
        try eg.fingerTap(at: Nsp.attendeeField)
        try eg.keyType("Blob")

        // Expect attendee name updated.
        #expect(store.state.syncUp.attendees[0].name == "Blob")
    }

    // Tap New attendee button.
    // Expect attendee state to append one attendee.
    @Test
    func newAttendeeButtonTapAddsAttendee() async throws {
        // Set up store and event generator.
        let store = makeStore(attendees: [], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)

        // Tap add attendee.
        try eg.fingerTap(at: Nsp.newAttendeeButton)

        // Expect attendee appended.
        #expect(store.state.syncUp.attendees.count == 1)
    }

    // Swipe attendee row and tap Delete.
    // Expect attendee state to remove the row.
    @Test
    func attendeeSwipeDeleteRemovesAttendee() async throws {
        // Set up store and event generator.
        let attendee = Attendee(id: Attendee.ID(), name: "Blob")
        let store = makeStore(attendees: [attendee], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)

        // Reveal swipe action and delete attendee.
        let attendeeField = try eg.viewWithIdentifier(Nsp.attendeeField)
        try eg.fingerDrag(
            from: RelativeLocation(location: attendeeField, x: 0.98, y: 0.5),
            to: RelativeLocation(location: attendeeField, x: 0.02, y: 0.5),
            duration: 0.35
        )
        // Wait for swipe to delete animation.
        await finishAnimation(.swipe, "delete")

        // Expect attendee removed.
        #expect(store.state.syncUp.attendees.isEmpty)
    }

    // MARK: - Toolbar Actions

    // Tap Save while invalid, then complete required fields and tap Save.
    // Expect no publish while invalid and publish once valid.
    @Test
    func saveButtonTapPublishesOnlyWhenFormValid() async throws {
        // Set up invalid form and event generator.
        let attendee = Attendee(id: Attendee.ID(), name: "")
        let store = makeStore(attendees: [attendee], title: "")
        let eg = try await EventGenerator(view: store.contentView)

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Expect initially invalid.
        #expect(!store.state.canSave)

        // Attempt save while invalid.
        do {
            try eg.fingerTap(at: Nsp.saveButton)
        } catch {
            // Disabled toolbar item may not be tappable.
        }
        // Expect still no publish path.
        #expect(!store.state.canSave)
        #expect(!store.isCancelled)

        // Complete required fields.
        try eg.fingerTap(at: Nsp.titleField)
        try eg.keyType("Engineering")
        try eg.fingerTap(at: Nsp.attendeeField)
        try eg.keyType("Blob")

        // Expect form now valid.
        #expect(store.state.canSave)

        // Save valid form.
        try eg.fingerTap(at: Nsp.saveButton)
        let value = try await valueTask.value

        // Expect published sync-up values.
        #expect(value.title == "Engineering")
        #expect(value.attendees[0].name == "Blob")
    }

    // Tap Cancel button.
    // Expect store cancel action to complete value stream with cancellation.
    @Test
    func cancelButtonTapCancelsStore() async throws {
        // Set up store and event generator.
        let store = makeStore(attendees: [Attendee(id: Attendee.ID(), name: "Blob")], title: "Engineering")
        let eg = try await EventGenerator(view: store.contentView)

        // Capture first published value and await it later.
        let resultTask = Task { () -> Result<SyncUp, Error> in
            do {
                return .success(try await store.firstValue())
            } catch {
                return .failure(error)
            }
        }
        await store.getRequest()

        // Tap cancel.
        try eg.fingerTap(at: Nsp.cancelButton)
        let result = await resultTask.value

        // Expect store cancelled and stream ended with error.
        #expect(store.isCancelled)
        switch result {
        case .success:
            #expect(Bool(false))
        case .failure:
            #expect(Bool(true))
        }
    }

    private func makeStore(
        attendees: [Attendee],
        title: String,
        duration: Duration = .seconds(60 * 5),
        theme: Theme = .bubblegum
    ) -> SyncUpForm.Store {
        let store = SyncUpForm.store(
            syncUp: SyncUp(
                id: SyncUp.ID(),
                attendees: attendees,
                duration: duration,
                theme: theme,
                title: title
            ),
            title: "New sync-up",
            saveTitle: "Add",
            cancelTitle: "Dismiss"
        )
        store.environment = .init(editAttendee: { _ in })
        return store
    }

}
