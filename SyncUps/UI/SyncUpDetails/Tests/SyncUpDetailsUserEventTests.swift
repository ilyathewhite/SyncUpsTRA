import Foundation
import Hammer
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.UserEventTests {
    @MainActor
    @Suite(.serialized) struct SyncUpDetailsUserEventTests {}
}

extension EventTests.UserEventTests.SyncUpDetailsUserEventTests {
    private typealias Nsp = SyncUpDetails

    // MARK: - Info Actions

    // Tap Start Meeting button.
    // Expect start meeting action to publish.
    @Test
    func startMeetingButtonTapPublishesStartMeeting() async throws {
        // Set up details store and event generator.
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        let store = makeStore(syncUp: syncUp, authorizationStatus: { .authorized })
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

        // Tap start meeting.
        try eg.fingerTap(at: Nsp.startMeetingButton)
        let value = try await valueTask.value

        // Expect start-meeting published.
        #expect(isStartMeeting(value))
    }

    // MARK: - Meeting Actions

    // Tap past meeting row.
    // Expect show-meeting-notes action to publish selected meeting.
    @Test
    func meetingRowTapPublishesMeetingNotes() async throws {
        // Set up details store with one meeting.
        let meeting = Meeting(
            id: Meeting.ID(),
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: "Hello"
        )
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            meetings: [meeting],
            title: "Design"
        )
        let store = makeStore(syncUp: syncUp)
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

        // Tap meeting row.
        try eg.fingerTap(at: Nsp.meetingRow(meeting.id))
        let value = try await valueTask.value

        // Expect selected meeting published.
        #expect(meetingNotes(from: value) == meeting)
    }

    // Swipe meeting row and tap Delete.
    // Expect meeting removed and sync-up saved.
    @Test
    func meetingSwipeDeleteRemovesMeetingAndSavesSyncUp() async throws {
        // Set up details store with meeting and save spy.
        let meeting = Meeting(
            id: Meeting.ID(),
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: "Hello"
        )
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            meetings: [meeting],
            title: "Design"
        )
        var savedSyncUp: SyncUp?
        let store = makeStore(
            syncUp: syncUp,
            save: { syncUp in
                savedSyncUp = syncUp
            })
        let eg = try await EventGenerator(
            view: NavigationStack {
                store.contentView
            }
        )

        // Reveal swipe action and delete meeting.
        let meetingRow = try eg.viewWithIdentifier(Nsp.meetingRow(meeting.id))
        try eg.fingerDrag(
            from: RelativeLocation(location: meetingRow, x: 0.98, y: 0.5),
            to: RelativeLocation(location: meetingRow, x: 0.02, y: 0.5),
            duration: 0.35
        )
        // Wait for swipe delete animation.
        await finishAnimation(.swipe, "delete")

        // Expect meeting removed and save triggered.
        #expect(store.state.syncUp.meetings.isEmpty)
        #expect(savedSyncUp?.meetings.isEmpty == true)
    }

    // MARK: - Sync-up Actions

    // Tap Edit button.
    // Expect edit effect to update and save sync-up.
    @Test
    func editButtonTapUpdatesSyncUpAndSaves() async throws {
        // Set up details store, edit output, and save spy.
        let (saveCalls, saveContinuation) = AsyncStream<Void>.makeStream()
        var saveIterator = saveCalls.makeAsyncIterator()
        let id = SyncUp.ID()
        let syncUp = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        let updated = SyncUp(
            id: id,
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            theme: .appOrange,
            title: "Design & Product"
        )
        var editedInput: SyncUp?
        var savedSyncUp: SyncUp?
        let store = makeStore(
            syncUp: syncUp,
            edit: { value in
                editedInput = value
                return updated
            },
            save: { value in
                savedSyncUp = value
                saveContinuation.yield()
                saveContinuation.finish()
            }
        )
        let eg = try await EventGenerator(
            view: NavigationStack {
                store.contentView
            }
        )

        // Tap edit button.
        try eg.fingerTap(at: Nsp.editButton)
        _ = await saveIterator.next()

        // Expect edit input, state update, and save.
        #expect(editedInput == syncUp)
        #expect(store.state.syncUp == updated)
        #expect(savedSyncUp == updated)
    }

    // Tap Delete button and confirm deletion.
    // Expect delete-sync-up action to publish.
    @Test
    func deleteSyncUpButtonTapPublishesDeleteWhenConfirmed() async throws {
        // Set up isolated app environment.
        let syncUp = SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: "Design"
        )
        try await withStorageEnvironment(syncUp: syncUp) {
            // Set up details store and install real UI wiring.
            let store = Nsp.store(syncUp)
            let eg = try await EventGenerator(
                view: NavigationStack {
                    store.contentView
                }
            )
            await Task.yield()
            #expect(store.environment != nil)
            _ = try eg.viewWithIdentifier(Nsp.deleteSyncUpButton)

            // Capture first published value and await it later.
            let valueTask = Task {
                try await store.firstValue()
            }
            await store.getRequest()

            // Tap delete sync-up.
            try eg.fingerTap(at: Nsp.deleteSyncUpButton)
            await finishAnimation(.present, "delete-confirmation alert")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.confirmDeleteYesTitle))
            let value = try await valueTask.value

            // Expect delete action published.
            #expect(isDeleteSyncUp(value))
        }
    }

    private func makeStore(
        syncUp: SyncUp,
        edit: @escaping (SyncUp) async -> SyncUp? = { _ in nil },
        save: @escaping (SyncUp) -> Void = { _ in },
        find: @escaping (SyncUp.ID) -> SyncUp? = { _ in nil },
        confirmDelete: @escaping () async throws -> Bool = { false },
        authorizationStatus: @escaping () -> Nsp.AuthorizationStatus = { .authorized },
        showRestrictedAlert: @escaping () async throws -> Nsp.SpeechRecognitionRestrictedAlertResult = {
            .noAction
        },
        showDeniedAlert: @escaping () async throws -> Nsp.SpeechRecognitionDeniedAlertResult = { .noAction },
        openSettings: @escaping () -> Void = {}
    ) -> Nsp.Store {
        let store = Nsp.store(syncUp)
        store.environment = .init(
            edit: edit,
            save: save,
            find: { id in
                if let found = find(id) {
                    return found
                }
                return id == syncUp.id ? syncUp : nil
            },
            confirmDelete: confirmDelete,
            checkSpeechRecognitionAuthorization: authorizationStatus,
            showSpeechRecognitionRestrictedAlert: showRestrictedAlert,
            showSpeechRecognitionDeniedAlert: showDeniedAlert,
            openSettings: openSettings
        )
        return store
    }

    private func isStartMeeting(_ value: Nsp.ResultAction) -> Bool {
        if case .startMeeting = value {
            return true
        }
        return false
    }

    private func isDeleteSyncUp(_ value: Nsp.ResultAction) -> Bool {
        if case .deleteSyncUp = value {
            return true
        }
        return false
    }

    private func meetingNotes(from value: Nsp.ResultAction) -> Meeting? {
        if case .showMeetingNotes(let meeting) = value {
            return meeting
        }
        return nil
    }

    private func withStorageEnvironment(
        syncUp: SyncUp,
        operation: @MainActor () async throws -> Void
    ) async throws {
        try await withTaskIsolatedEnv(
            AppEnvironment.self,
            override: { @Sendable env in
                env.storageClient = makeSyncUpDetailsUserEventStorageClient(syncUp: syncUp)
            },
            operation: operation
        )
    }
}

private func makeSyncUpDetailsUserEventStorageClient(syncUp: SyncUp) -> StorageClient {
    .init(
        allSyncUps: { [syncUp] },
        saveSyncUp: { _ in },
        deleteSyncUp: { _ in },
        saveMeetingNotes: { _, _ in },
        findSyncUp: { id in
            id == syncUp.id ? syncUp : nil
        }
    )
}
