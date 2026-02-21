import Foundation
import Hammer
import Speech
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.IntegrationTests {
    // Add sync-up.
    // Flow:
    // SyncUpList - tap add button
    // SyncUpForm - type title and attendee, save
    // SyncUpList
    @Test
    func addSyncUpFlowCreatesSyncUpAndShowsItInList() async throws {
        try await withAppEnvironment(syncUps: []) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.addButton)

            // Open add form.
            try eg.fingerTap(at: SyncUpList.addButton)
            await finishAnimation(.present, "sync-up form presentation")

            // Fill required fields.
            try eg.fingerTap(at: SyncUpForm.titleField)
            try eg.keyType("Engineering")
            try eg.fingerTap(at: SyncUpForm.attendeeField)
            try eg.keyType("Blob")

            // Save sync-up.
            try eg.fingerTap(at: SyncUpForm.saveButton)
            await finishAnimation(.dismiss, "sync-up form dismissal")

            // Expect sync-up persisted and visible on list.
            #expect(storage.syncUps.count == 1)
            #expect(storage.syncUps[0].attendees.first?.name == "Blob")
            _ = try eg.viewWithIdentifier(SyncUpList.row(storage.syncUps[0].id))
        }
    }

    // Edit sync-up.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - open edit
    // SyncUpForm - update title, save
    // SyncUpDetails - go back
    // SyncUpList
    @Test
    func editSyncUpFlowUpdatesTitleAndPersistsOnList() async throws {
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(syncUps: [syncUp]) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())

            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")

            // Open edit form.
            try eg.fingerTap(at: SyncUpDetails.editButton)
            await finishAnimation(.present, "edit sync-up form presentation")

            // Update and save.
            try eg.fingerTap(at: SyncUpForm.titleField)
            try eg.keyType(" & Product")
            try eg.fingerTap(at: SyncUpForm.saveButton)
            await finishAnimation(.dismiss, "edit sync-up form dismissal")

            // Return to list.
            try tapBackButton(eg)
            await finishAnimation(.pop, "sync-up details dismissal")

            // Expect updated title persisted.
            #expect(storage.syncUps.count == 1)
            #expect(storage.syncUps[0].title == "Design & Product")
        }
    }

    // Delete sync-up.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - tap delete and confirm alert
    // SyncUpList
    @Test
    func deleteSyncUpFlowDeletesSyncUpAndReturnsToList() async throws {
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(syncUps: [syncUp]) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")

            // Delete and confirm alert.
            try eg.fingerTap(at: SyncUpDetails.deleteSyncUpButton)
            await finishAnimation(.present, "delete sync-up alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(SyncUpDetails.confirmDeleteYesTitle))
            await finishAnimation(.dismiss, "delete sync-up alert dismissal")
            await finishAnimation(.pop, "sync-up details dismissal")

            // Expect deleted from storage and list.
            #expect(storage.syncUps.isEmpty)
        }
    }

    // Save meeting.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - start meeting
    // RecordMeeting - end meeting and save
    // SyncUpDetails - open saved meeting notes, go back
    // SyncUpList
    @Test
    func recordMeetingSaveFlowSavesMeetingAndShowsMeetingNotes() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(
            syncUps: [syncUp],
            speechClient: makeAuthorizedSpeechClient(transcript: "Hello world!"),
            now: { fixedDate }
        ) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details and start meeting.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")
            try eg.fingerTap(at: SyncUpDetails.startMeetingButton)
            await finishAnimation(.push, "record meeting presentation")

            // End meeting and save.
            try eg.fingerTap(at: RecordMeeting.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(RecordMeeting.endMeetingSaveTitle))
            await finishAnimation(.dismiss, "end-meeting alert dismissal")
            await finishAnimation(.pop, "record meeting dismissal")

            // Expect meeting persisted.
            let savedMeeting = storage.syncUps.first?.meetings.first
            #expect(savedMeeting?.date == fixedDate)
            #expect(savedMeeting?.transcript == "Hello world!")

            // Open saved meeting notes.
            guard let meetingID = savedMeeting?.id else {
                #expect(Bool(false))
                return
            }
            try eg.fingerTap(at: SyncUpDetails.meetingRow(meetingID))
            await finishAnimation(.push, "meeting notes presentation")

            // Return to list.
            try tapBackButton(eg)
            await finishAnimation(.pop, "meeting notes dismissal")
            try tapBackButton(eg)
            await finishAnimation(.pop, "sync-up details dismissal")
        }
    }

    // Discard meeting.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - start meeting
    // RecordMeeting - end meeting and discard
    // SyncUpDetails
    @Test
    func recordMeetingDiscardFlowReturnsWithoutSavingMeeting() async throws {
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(
            syncUps: [syncUp],
            speechClient: makeAuthorizedSpeechClient(transcript: "Hello world!")
        ) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details and start meeting.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")
            try eg.fingerTap(at: SyncUpDetails.startMeetingButton)
            await finishAnimation(.push, "record meeting presentation")

            // End meeting and discard.
            try eg.fingerTap(at: RecordMeeting.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(RecordMeeting.endMeetingDiscardTitle))
            await finishAnimation(.dismiss, "end-meeting alert dismissal")
            await finishAnimation(.pop, "record meeting dismissal")

            // Expect no meeting persisted.
            #expect(storage.syncUps.count == 1)
            #expect(storage.syncUps[0].meetings.isEmpty)
        }
    }

    // Continue without recording from denied speech alert.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - start meeting and continue from denied alert
    // RecordMeeting - end meeting and discard
    // SyncUpDetails
    @Test
    func deniedSpeechAlertContinueFlowStartsMeetingWithoutRecording() async throws {
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(
            syncUps: [syncUp],
            speechClient: Self.makeDeniedSpeechClient()
        ) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")

            // Start meeting and continue from denied alert.
            try eg.fingerTap(at: SyncUpDetails.startMeetingButton)
            await finishAnimation(.present, "speech denied alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(SyncUpDetails.continueWithoutRecordingTitle))
            await finishAnimation(.dismiss, "speech denied alert dismissal")
            await finishAnimation(.push, "record meeting presentation")

            // Expect record meeting shown.
            _ = try eg.viewWithIdentifier(RecordMeeting.endMeetingButton)

            // End flow by discarding.
            try eg.fingerTap(at: RecordMeeting.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(RecordMeeting.endMeetingDiscardTitle))
            await finishAnimation(.dismiss, "end-meeting alert dismissal")
            await finishAnimation(.pop, "record meeting dismissal")

            // Expect no meeting persisted.
            #expect(storage.syncUps[0].meetings.isEmpty)
        }
    }

    // Discard from speech failure alert.
    // Flow:
    // SyncUpList - tap sync-up row
    // SyncUpDetails - start meeting
    // RecordMeeting - discard from speech-failure alert
    // SyncUpDetails
    @Test
    func speechFailureAlertDiscardFlowReturnsToDetailsWithoutSavingMeeting() async throws {
        let syncUp = makeSyncUp(title: "Design")
        try await withAppEnvironment(
            syncUps: [syncUp],
            speechClient: makeFailingSpeechClient()
        ) { storage in
            // Set up event generator from real app flow.
            let eg = try await EventGenerator(view: AppFlowContainer())
            // Ensure root list is ready.
            _ = try eg.viewWithIdentifier(SyncUpList.row(syncUp.id))

            // Open details and start meeting.
            try eg.fingerTap(at: SyncUpList.row(syncUp.id))
            await finishAnimation(.push, "sync-up details presentation")
            try eg.fingerTap(at: SyncUpDetails.startMeetingButton)
            await finishAnimation(.push, "record meeting presentation")

            // Handle speech failure alert.
            await finishAnimation(.present, "speech failure alert presentation")
            try eg.fingerTap(at: try viewWithAccessibilityLabel(RecordMeeting.speechFailureDiscardTitle))
            await finishAnimation(.dismiss, "speech failure alert dismissal")
            await finishAnimation(.pop, "record meeting dismissal")

            // Expect no meeting persisted.
            #expect(storage.syncUps[0].meetings.isEmpty)
        }
    }

    private func tapBackButton(_ eg: EventGenerator) throws {
        let backButton = try eg.viewWithIdentifier("BackButton")
        try eg.fingerTap(at: backButton)
    }

    private func withAppEnvironment(
        syncUps: [SyncUp],
        speechClient: SpeechClient? = nil,
        now: @escaping @Sendable () -> Date = Date.init,
        operation: @MainActor (IntegrationStorage) async throws -> Void
    ) async throws {
        let speechClient = speechClient ?? Self.makeDeniedSpeechClient()
        let storage = IntegrationStorage(syncUps: syncUps)
        prepareTaskIsolatedEnv(
            AppEnvironment.self,
            override: { env in
                env.storageClient = storage.client
                env.speechClient = speechClient
                env.soundEffectClient = .init(
                    load: { _ in },
                    play: {}
                )
                env.now = now
                env.openSettings = {}
            }
        )
        try await operation(storage)
    }

    private func makeSyncUp(title: String) -> SyncUp {
        SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            title: title
        )
    }

    private static func makeDeniedSpeechClient() -> SpeechClient {
        .init(
            authorizationStatus: { .denied },
            requestAuthorization: { .denied },
            startTask: { _ in
                AsyncThrowingStream { continuation in
                    continuation.finish()
                }
            }
        )
    }

    private func makeAuthorizedSpeechClient(transcript: String) -> SpeechClient {
        .init(
            authorizationStatus: { .authorized },
            requestAuthorization: { .authorized },
            startTask: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: transcript),
                            isFinal: true
                        )
                    )
                    continuation.finish()
                }
            }
        )
    }

    private func makeFailingSpeechClient() -> SpeechClient {
        .init(
            authorizationStatus: { .authorized },
            requestAuthorization: { .authorized },
            startTask: { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: "Hello world!"),
                            isFinal: false
                        )
                    )
                    struct SpeechFailure: Error {}
                    continuation.finish(throwing: SpeechFailure())
                }
            }
        )
    }
}

private final class IntegrationStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var storedSyncUps: [SyncUp]

    init(syncUps: [SyncUp]) {
        self.storedSyncUps = syncUps
    }

    var syncUps: [SyncUp] {
        lock.lock()
        defer { lock.unlock() }
        return storedSyncUps
    }

    var client: StorageClient {
        .init(
            allSyncUps: {
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.storedSyncUps
            },
            saveSyncUp: { syncUp in
                self.lock.lock()
                defer { self.lock.unlock() }
                if let index = self.storedSyncUps.firstIndex(where: { $0.id == syncUp.id }) {
                    self.storedSyncUps[index] = syncUp
                }
                else {
                    self.storedSyncUps.append(syncUp)
                }
            },
            deleteSyncUp: { syncUp in
                self.lock.lock()
                defer { self.lock.unlock() }
                guard let index = self.storedSyncUps.firstIndex(where: { $0.id == syncUp.id }) else {
                    assertionFailure()
                    return
                }
                self.storedSyncUps.remove(at: index)
            },
            saveMeetingNotes: { syncUp, meeting in
                self.lock.lock()
                defer { self.lock.unlock() }
                guard let index = self.storedSyncUps.firstIndex(where: { $0.id == syncUp.id }) else {
                    assertionFailure()
                    return
                }
                self.storedSyncUps[index].meetings.insert(meeting, at: 0)
            },
            findSyncUp: { id in
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.storedSyncUps.first(where: { $0.id == id })
            }
        )
    }
}
