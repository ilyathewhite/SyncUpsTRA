import Foundation
import Testing

@testable import SyncUps

extension ModelTests {
    @MainActor
    @Suite struct StorageClientTests {}
}

extension ModelTests.StorageClientTests {
    // MARK: - Save and Find

    // Save sync-up.
    // Expect find to return saved value.
    @Test
    func saveSyncUpThenFindReturnsSavedValue() {
        // Set up client and sync-up.
        let client = StorageClient.liveValue
        let storage = Storage.shared
        let syncUp = makeSyncUp(title: "Storage Save")

        // Remove test value after completion.
        defer {
            if storage.findSyncUp(syncUp.id) != nil {
                storage.deleteSyncUp(syncUp)
            }
        }

        // Save sync-up through client.
        client.saveSyncUp(syncUp)

        // Expect storage to contain saved sync-up.
        #expect(storage.findSyncUp(syncUp.id) == syncUp)
    }

    // Save sync-up, then save same id with updates.
    // Expect one stored value with latest fields.
    @Test
    func saveSyncUpWithSameIDUpdatesExistingValue() {
        // Set up client and original sync-up.
        let client = StorageClient.liveValue
        let storage = Storage.shared
        let original = makeSyncUp(title: "Storage Original")

        // Remove test value after completion.
        defer {
            if storage.findSyncUp(original.id) != nil {
                storage.deleteSyncUp(original)
            }
        }

        // Save original value.
        client.saveSyncUp(original)

        // Prepare updated value with same id.
        var updated = original
        updated.title = "Storage Updated"
        updated.duration = .seconds(60 * 15)

        // Save updated value.
        client.saveSyncUp(updated)

        // Expect one value with updated data.
        let matches = storage.allSyncUps().filter { $0.id == original.id }
        #expect(matches.count == 1)
        #expect(matches.first == updated)
    }

    // MARK: - Delete

    // Save sync-up, then delete it.
    // Expect find to return nil.
    @Test
    func deleteSyncUpRemovesStoredValue() {
        // Set up client and sync-up.
        let client = StorageClient.liveValue
        let storage = Storage.shared
        let syncUp = makeSyncUp(title: "Storage Delete")

        // Save and delete sync-up.
        client.saveSyncUp(syncUp)
        client.deleteSyncUp(syncUp)

        // Expect sync-up removed from storage.
        #expect(storage.findSyncUp(syncUp.id) == nil)
    }

    // MARK: - Meeting Notes

    // Save sync-up with one meeting, then save meeting notes.
    // Expect new meeting inserted first.
    @Test
    func saveMeetingNotesInsertsMeetingAtBeginning() {
        // Set up client and meeting values.
        let client = StorageClient.liveValue
        let storage = Storage.shared
        let oldMeeting = Meeting(
            id: Meeting.ID(),
            date: Date(timeIntervalSince1970: 1_000),
            transcript: "Old"
        )
        let newMeeting = Meeting(
            id: Meeting.ID(),
            date: Date(timeIntervalSince1970: 2_000),
            transcript: "New"
        )
        var syncUp = makeSyncUp(title: "Storage Meeting Notes")
        syncUp.meetings = [oldMeeting]

        // Remove test value after completion.
        defer {
            if storage.findSyncUp(syncUp.id) != nil {
                storage.deleteSyncUp(syncUp)
            }
        }

        // Save sync-up and add meeting notes.
        client.saveSyncUp(syncUp)
        client.saveMeetingNotes(syncUp, newMeeting)

        // Expect latest meeting inserted first.
        let found = storage.findSyncUp(syncUp.id)
        #expect(found?.meetings.first == newMeeting)
        #expect(found?.meetings.count == 2)
    }
}

private extension ModelTests.StorageClientTests {
    func makeSyncUp(title: String) -> SyncUp {
        SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: title
        )
    }
}
