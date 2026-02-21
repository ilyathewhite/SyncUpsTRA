import Combine
import Foundation
import SwiftUIExTesting
import Testing

@testable import SyncUps

extension ModelTests {
    @MainActor
    @Suite struct RecordMeetingModelTests {}
}

extension ModelTests.RecordMeetingModelTests {
    // MARK: - State Updates

    // Send transcript mutation.
    // Expect transcript state to update.
    @Test
    func updateTranscriptMutationUpdatesTranscriptState() {
        // Set up record-meeting store.
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))

        // Update transcript.
        store.send(.mutating(.updateTranscript("Hello world")))
        // Expect transcript updated.
        #expect(store.state.transcript == "Hello world")
    }

    // Send next-speaker mutation.
    // Expect speaker index and elapsed time to advance, then sound effect.
    @Test
    func nextSpeakerMutationAdvancesSpeakerAndPlaysSound() {
        // Set up store and sound spy.
        var playSoundCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 120))
        store.environment = makeEnvironment(playNextSpeakerSound: {
            playSoundCallCount += 1
        })

        // Move to next speaker.
        store.send(.mutating(.nextSpeaker))

        // Expect speaker, elapsed time, and sound.
        #expect(store.state.speakerIndex == 1)
        #expect(store.state.secondsElapsed == 60)
        #expect(playSoundCallCount == 1)
    }

    // Ignore timer updates, then increment elapsed seconds.
    // Expect elapsed time to remain unchanged.
    @Test
    func incSecondsElapsedMutationDoesNothingWhenTimerIgnored() {
        // Set up store with timer ignored.
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 120))
        store.send(.mutating(.updateIgnoreTimer(true)))

        // Increment elapsed seconds.
        store.send(.mutating(.incSecondsElapsed))

        // Expect elapsed time unchanged.
        #expect(store.state.secondsElapsed == 0)
    }

    // Increment to attendee boundary.
    // Expect next speaker and sound.
    @Test
    func incSecondsElapsedMutationOnBoundaryMovesToNextSpeaker() {
        // Set up store and sound spy.
        var playSoundCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 120))
        store.environment = makeEnvironment(playNextSpeakerSound: {
            playSoundCallCount += 1
        })

        // Tick to speaker boundary.
        for _ in 0..<60 {
            store.send(.mutating(.incSecondsElapsed))
        }

        // Expect moved to next speaker and played sound.
        #expect(store.state.speakerIndex == 1)
        #expect(store.state.secondsElapsed == 60)
        #expect(playSoundCallCount == 1)
    }

    // Increment until end of meeting.
    // Expect save action to publish meeting.
    @Test
    func incSecondsElapsedMutationAtMeetingEndPublishesSave() async throws {
        // Set up short meeting and fixed date.
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 2))
        store.environment = makeEnvironment(now: { fixedDate })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Tick to meeting end.
        store.send(.mutating(.incSecondsElapsed))
        store.send(.mutating(.incSecondsElapsed))
        let value = try await valueTask.value

        // Expect save meeting published.
        guard case .save(let meeting) = value else {
            #expect(Bool(false))
            return
        }
        #expect(meeting.date == fixedDate)
        #expect(meeting.transcript == "")
    }

    // MARK: - End Meeting Effects

    // Show end-meeting alert and choose save.
    // Expect save action to publish meeting.
    @Test
    func showEndMeetingAlertEffectSavePublishesMeeting() async throws {
        // Set up end-meeting alert to save.
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        var receivedDiscardable: Bool?
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(
            showEndMeetingAlert: { discardable in
                receivedDiscardable = discardable
                return .saveAndEnd
            },
            now: { fixedDate }
        )
        store.send(.mutating(.updateTranscript("Hello world")))

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Show end-meeting alert.
        let endMeetingAlertTask = store.send(.effect(.showEndMeetingAlert(discardable: true)))
        let value = try await valueTask.value
        await endMeetingAlertTask?.value

        // Expect save meeting published.
        guard case .save(let meeting) = value else {
            #expect(Bool(false))
            return
        }
        #expect(receivedDiscardable == true)
        #expect(meeting.date == fixedDate)
        #expect(meeting.transcript == "Hello world")
    }

    // Show end-meeting alert and choose discard.
    // Expect discard action to publish.
    @Test
    func showEndMeetingAlertEffectDiscardPublishesDiscard() async throws {
        // Set up end-meeting alert to discard.
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(showEndMeetingAlert: { _ in .discard })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Show end-meeting alert.
        let endMeetingAlertTask = store.send(.effect(.showEndMeetingAlert(discardable: true)))
        let value = try await valueTask.value
        await endMeetingAlertTask?.value

        // Expect discard published.
        #expect(isDiscard(value))
    }

    // Show end-meeting alert and choose resume.
    // Expect no published value.
    @Test
    func showEndMeetingAlertEffectResumeDoesNotPublish() async throws {
        // Set up end-meeting alert to resume.
        var endMeetingAlertCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(showEndMeetingAlert: { _ in
            endMeetingAlertCallCount += 1
            return .resume
        })

        var didPublish = false
        let cancellable = store.value.sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in
                didPublish = true
            }
        )

        // Show end-meeting alert.
        await store.send(.effect(.showEndMeetingAlert(discardable: true)))?.value

        // Expect no publish and timer resumed.
        #expect(!didPublish)
        #expect(endMeetingAlertCallCount == 1)
        #expect(!store.state.ignoreTimeUpdates)
        _ = cancellable
    }

    // MARK: - Transcript Effects

    // Start transcript recording and emit transcription.
    // Expect transcript state to update.
    @Test
    func startTranscriptRecordingEffectUpdatesTranscript() async throws {
        // Set up transcript stream to emit one result.
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(
            startTranscriptRecording: {
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: "Hello world"),
                            isFinal: true
                        )
                    )
                    continuation.finish()
                }
            }
        )

        // Start transcript recording.
        await store.send(.effect(.startTranscriptRecording))?.value

        // Expect transcript updated.
        #expect(store.state.transcript == "Hello world")
    }

    // Start transcript recording, then fail and choose discard.
    // Expect discard action to publish.
    @Test
    func transcriptRecordingFailureEffectCanPublishDiscard() async throws {
        // Set up transcript stream failure and discard response.
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(
            showSpeechRecognizerFailureAlert: { .discard },
            startTranscriptRecording: {
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: "Hello world"),
                            isFinal: true
                        )
                    )
                    struct TranscriptionFailed: Error {}
                    continuation.finish(throwing: TranscriptionFailed())
                }
            }
        )

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Start transcript recording.
        let startTranscriptRecordingTask = store.send(.effect(.startTranscriptRecording))
        let value = try await valueTask.value
        await startTranscriptRecordingTask?.value

        // Expect discard published with latest transcript.
        #expect(isDiscard(value))
        #expect(store.state.transcript == "Hello world")
    }

    // Start transcript recording, then fail and choose continue.
    // Expect no published value.
    @Test
    func transcriptRecordingFailureEffectCanContinueWithoutPublish() async throws {
        // Set up transcript stream failure and continue response.
        var failureAlertCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(
            showSpeechRecognizerFailureAlert: {
                failureAlertCallCount += 1
                return .continue
            },
            startTranscriptRecording: {
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: "Hello world"),
                            isFinal: true
                        )
                    )
                    struct TranscriptionFailed: Error {}
                    continuation.finish(throwing: TranscriptionFailed())
                }
            }
        )

        var didPublish = false
        let cancellable = store.value.sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in
                didPublish = true
            }
        )

        // Start transcript recording.
        await store.send(.effect(.startTranscriptRecording))?.value

        // Expect no publish and timer resumed.
        #expect(!didPublish)
        #expect(failureAlertCallCount == 1)
        #expect(store.state.transcript == "Hello world")
        #expect(!store.state.ignoreTimeUpdates)
        _ = cancellable
    }

    // MARK: - Direct Effects

    // Start record-meeting startup effects.
    // Expect one-shot startup work finishes while timer loop keeps running.
    @Test
    func startRunsStartupEffectsWithoutWaitingForTimerLoop() async throws {
        // Set up startup environment.
        var prepareCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(
            prepareSoundPlayer: {
                prepareCallCount += 1
            },
            startTranscriptRecording: {
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SpeechRecognitionResult(
                            bestTranscription: Transcription(formattedString: "Hello world"),
                            isFinal: true
                        )
                    )
                    continuation.finish()
                }
            }
        )

        // Start startup effects.
        let startTask = RecordMeeting.start(store)
        await startTask.value

        // Expect one-shot startup work completed.
        #expect(prepareCallCount == 1)
        #expect(store.state.transcript == "Hello world")

        // Expect timer loop still running after startup task completes.
        let secondsAfterStart = store.state.secondsElapsed
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline, store.state.secondsElapsed == secondsAfterStart {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.state.secondsElapsed > secondsAfterStart)
        store.cancel()
    }

    // Trigger prepare-sound effect.
    // Expect prepare callback call.
    @Test
    func prepareSoundPlayerEffectInvokesEnvironmentCallback() async throws {
        // Set up prepare callback spy.
        var prepareCallCount = 0
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(prepareSoundPlayer: {
            prepareCallCount += 1
        })

        // Trigger prepare-sound effect.
        await store.send(.effect(.prepareSoundPlayer))?.value
        // Expect callback invoked.
        #expect(prepareCallCount == 1)
    }

    // Trigger publish-meeting effect.
    // Expect save action with fixed date and transcript.
    @Test
    func publishMeetingEffectPublishesSaveWithTranscriptAndDate() async throws {
        // Set up fixed date.
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        let store = RecordMeeting.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 60))
        store.environment = makeEnvironment(now: { fixedDate })

        // Capture first published value and await it later.
        let valueTask = Task {
            try await store.firstValue()
        }
        await store.getRequest()

        // Trigger publish-meeting effect.
        await store.send(.effect(.publishMeeting(transcript: "Hello world")))?.value
        let value = try await valueTask.value

        // Expect saved meeting payload.
        guard case .save(let meeting) = value else {
            #expect(Bool(false))
            return
        }
        #expect(meeting.date == fixedDate)
        #expect(meeting.transcript == "Hello world")
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

    private func makeEnvironment(
        showEndMeetingAlert: @escaping (Bool) async throws -> RecordMeeting.EndMeetingAlertResult = { _ in .resume },
        showSpeechRecognizerFailureAlert: @escaping () async throws -> RecordMeeting.SpeechRecognizerFailureAlertResult = { .continue },
        prepareSoundPlayer: @escaping () -> Void = {},
        playNextSpeakerSound: @escaping () -> Void = {},
        startTranscriptRecording: @escaping () async -> AsyncThrowingStream<SpeechRecognitionResult, Error> = {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        },
        now: @escaping () -> Date = Date.init
    ) -> RecordMeeting.StoreEnvironment {
        .init(
            showEndMeetingAlert: showEndMeetingAlert,
            showSpeechRecognizerFailureAlert: showSpeechRecognizerFailureAlert,
            prepareSoundPlayer: prepareSoundPlayer,
            playNextSpeakerSound: playNextSpeakerSound,
            startTranscriptRecording: startTranscriptRecording,
            now: now
        )
    }

    private func isDiscard(_ value: RecordMeeting.ResultAction) -> Bool {
        if case .discard = value {
            return true
        }
        return false
    }
}
