import Combine
import Foundation
import Hammer
import Speech
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.UserEventTests {
    @MainActor
    @Suite(.serialized) struct RecordMeetingUserEventTests {}
}

extension EventTests.UserEventTests.RecordMeetingUserEventTests {
    private typealias Nsp = RecordMeeting

    // MARK: - Meeting Actions

    // Tap next speaker button.
    // Expect speaker progression and sound effect.
    @Test
    func nextSpeakerButtonTapAdvancesSpeakerAndPlaysSound() async throws {
        // Set up store, sound spy, and event generator.
        var playSoundCallCount = 0
        let store = makeStore(
            syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 120),
            playNextSpeakerSound: {
                playSoundCallCount += 1
            }
        )
        let eg = try await EventGenerator(
            view: NavigationStack {
                store.contentView
            }
        )

        // Tap next speaker.
        try eg.fingerTap(at: Nsp.nextSpeakerButton)

        // Expect speaker progressed and sound played.
        #expect(store.state.speakerIndex == 1)
        #expect(store.state.secondsElapsed == 60)
        #expect(playSoundCallCount == 1)
    }

    // MARK: - Toolbar Actions

    // Tap end meeting button and choose save.
    // Expect save action to publish meeting.
    @Test
    func endMeetingButtonTapPublishesSaveWhenAlertReturnsSave() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        try await withAppEnvironment(now: { fixedDate }) {
            // Set up store and install real UI wiring.
            let store = Nsp.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 600))
            store.send(.mutating(.updateTranscript("Hello world")))
            let eg = try await EventGenerator(
                view: NavigationStack {
                    store.contentView
                }
            )
            await Task.yield()
            #expect(store.environment != nil)

            // Capture first published value and await it later.
            let valueTask = Task {
                try await store.firstValue()
            }
            await store.getRequest()

            // Tap end meeting.
            try eg.fingerTap(at: Nsp.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert")
            #expect(store.state.ignoreTimeUpdates)
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.endMeetingSaveTitle))
            let value = try await valueTask.value

            // Expect save meeting published.
            guard case .save(let meeting) = value else {
                #expect(Bool(false))
                return
            }
            #expect(meeting.date == fixedDate)
            #expect(meeting.transcript == "Hello world")
        }
    }

    // Tap end meeting button and choose discard.
    // Expect discard action to publish.
    @Test
    func endMeetingButtonTapPublishesDiscardWhenAlertReturnsDiscard() async throws {
        try await withAppEnvironment {
            // Set up store and install real UI wiring.
            let store = Nsp.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 600))
            let eg = try await EventGenerator(
                view: NavigationStack {
                    store.contentView
                }
            )
            await Task.yield()
            #expect(store.environment != nil)

            // Capture first published value and await it later.
            let valueTask = Task {
                try await store.firstValue()
            }
            await store.getRequest()

            // Tap end meeting.
            try eg.fingerTap(at: Nsp.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert")
            #expect(store.state.ignoreTimeUpdates)
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.endMeetingDiscardTitle))
            let value = try await valueTask.value

            // Expect discard published.
            #expect(isDiscard(value))
        }
    }

    // Tap end meeting button and choose resume.
    // Expect no published value.
    @Test
    func endMeetingButtonTapDoesNotPublishWhenAlertReturnsResume() async throws {
        try await withAppEnvironment {
            // Set up store and install real UI wiring.
            let store = Nsp.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 600))
            let eg = try await EventGenerator(
                view: NavigationStack {
                    store.contentView
                }
            )
            await Task.yield()
            #expect(store.environment != nil)

            var didPublish = false
            let cancellable = store.value.sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    didPublish = true
                }
            )

            // Tap end meeting.
            try eg.fingerTap(at: Nsp.endMeetingButton)
            await finishAnimation(.present, "end-meeting alert")
            #expect(store.state.ignoreTimeUpdates)
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.endMeetingResumeTitle))

            // Expect no publish and timer resumed.
            await finishAnimation(.dismiss, "end-meeting alert")
            #expect(!store.state.ignoreTimeUpdates)
            #expect(!didPublish)
            _ = cancellable
        }
    }

    private func makeStore(
        syncUp: SyncUp,
        showEndMeetingAlert: @escaping (Bool) async throws -> Nsp.EndMeetingAlertResult = { _ in .resume },
        showSpeechRecognizerFailureAlert: @escaping () async throws -> Nsp.SpeechRecognizerFailureAlertResult = {
            .continue
        },
        prepareSoundPlayer: @escaping () -> Void = {},
        playNextSpeakerSound: @escaping () -> Void = {},
        startTranscriptRecording: @escaping () async -> AsyncThrowingStream<SpeechRecognitionResult, Error> = {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        },
        now: @escaping () -> Date = Date.init
    ) -> Nsp.Store {
        let store = Nsp.store(syncUp: syncUp)
        store.environment = .init(
            showEndMeetingAlert: showEndMeetingAlert,
            showSpeechRecognizerFailureAlert: showSpeechRecognizerFailureAlert,
            prepareSoundPlayer: prepareSoundPlayer,
            playNextSpeakerSound: playNextSpeakerSound,
            startTranscriptRecording: startTranscriptRecording,
            now: now
        )
        return store
    }

    private func withAppEnvironment(
        now: @escaping @Sendable () -> Date = Date.init,
        operation: @MainActor () async throws -> Void
    ) async throws {
        try await withTaskIsolatedEnv(
            AppEnvironment.self,
            override: { @Sendable env in
                env.speechClient = .init(
                    authorizationStatus: { .denied },
                    requestAuthorization: { .denied },
                    startTask: { _ in
                        AsyncThrowingStream { continuation in
                            continuation.finish()
                        }
                    }
                )
                env.soundEffectClient = .init(
                    load: { _ in },
                    play: {}
                )
                env.now = now
            },
            operation: operation
        )
    }

    private func makeSyncUp(attendeeCount: Int, durationSeconds: Int) -> SyncUp {
        SyncUp(
            id: SyncUp.ID(),
            attendees: (0..<attendeeCount).map { index in
                Attendee(id: Attendee.ID(), name: "Blob \(index)")
            },
            duration: .seconds(durationSeconds),
            title: "Design"
        )
    }

    private func isDiscard(_ value: Nsp.ResultAction) -> Bool {
        if case .discard = value {
            return true
        }
        return false
    }
}
