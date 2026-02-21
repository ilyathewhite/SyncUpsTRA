import Combine
import Foundation
import Hammer
import Speech
import SwiftUI
import SwiftUIExTesting
import TaskIsolatedEnv
import Testing

@testable import SyncUps

extension EventTests.OverlayTests {
    @MainActor
    @Suite(.serialized) struct RecordMeetingOverlayTests {}
}

extension EventTests.OverlayTests.RecordMeetingOverlayTests {
    private typealias Nsp = RecordMeeting

    // Trigger end-meeting alert and choose save.
    // Expect timer pause while shown, then save publish.
    @Test
    func showEndMeetingAlertEffectPausesTimerThenPublishesSave() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_234_567_890)
        try await withAppEnvironment(now: { fixedDate }) {
            // Set up store and install real UI wiring.
            let store = Nsp.store(syncUp: makeSyncUp(attendeeCount: 2, durationSeconds: 600))
            let eg = try await EventGenerator(
                view: NavigationStack {
                    store.contentView
                }
            )
            await Task.yield()
            #expect(store.environment != nil)
            store.send(.mutating(.updateTranscript("Hello world")))

            // Capture first published value and await it later.
            let valueTask = Task {
                try await store.firstValue()
            }
            await store.getRequest()

            // Show alert and wait for pause.
            let endMeetingAlertTask = store.send(.effect(.showEndMeetingAlert(discardable: true)))
            await finishAnimation(.present, "end-meeting alert")
            #expect(store.state.ignoreTimeUpdates)

            // Tap save from alert.
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.endMeetingSaveTitle))
            let value = try await valueTask.value
            await endMeetingAlertTask?.value

            // Expect save published.
            guard case .save(let meeting) = value else {
                #expect(Bool(false))
                return
            }
            #expect(meeting.date == fixedDate)
            #expect(meeting.transcript == "Hello world")
        }
    }

    // Trigger end-meeting alert and choose resume.
    // Expect timer pause while shown, then timer resume and no publish.
    @Test
    func showEndMeetingAlertEffectPausesTimerThenResumesWithoutPublish() async throws {
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

            // Observe publishes to assert no value is emitted.
            var didPublish = false
            let cancellable = store.value.sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    didPublish = true
                }
            )

            // Show alert and wait for pause.
            let endMeetingAlertTask = store.send(.effect(.showEndMeetingAlert(discardable: true)))
            await finishAnimation(.present, "end-meeting alert")
            #expect(store.state.ignoreTimeUpdates)

            // Tap resume from alert.
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.endMeetingResumeTitle))
            await endMeetingAlertTask?.value

            // Expect no publish and timer resumed.
            await finishAnimation(.dismiss, "end-meeting alert")
            #expect(!store.state.ignoreTimeUpdates)
            #expect(!didPublish)
            _ = cancellable
        }
    }

    // Trigger speech-failure alert and choose discard.
    // Expect timer pause while shown, then discard publish.
    @Test
    func showSpeechFailureAlertEffectPausesTimerThenPublishesDiscard() async throws {
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

            // Show alert and wait for pause.
            let speechFailureAlertTask = store.send(.effect(.showSpeechRecognizerFailureAlert))
            await finishAnimation(.present, "speech-failure alert")
            #expect(store.state.ignoreTimeUpdates)

            // Tap discard from alert.
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.speechFailureDiscardTitle))
            let value = try await valueTask.value
            await speechFailureAlertTask?.value

            // Expect discard published.
            #expect(isDiscard(value))
        }
    }

    // Trigger speech-failure alert and choose continue.
    // Expect timer pause while shown, then timer resume and no publish.
    @Test
    func showSpeechFailureAlertEffectPausesTimerThenContinuesWithoutPublish() async throws {
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

            // Observe publishes to assert no value is emitted.
            var didPublish = false
            let cancellable = store.value.sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    didPublish = true
                }
            )

            // Show alert and wait for pause.
            let speechFailureAlertTask = store.send(.effect(.showSpeechRecognizerFailureAlert))
            await finishAnimation(.present, "speech-failure alert")
            #expect(store.state.ignoreTimeUpdates)

            // Tap continue from alert.
            try eg.fingerTap(at: try viewWithAccessibilityLabel(Nsp.speechFailureContinueTitle))
            await speechFailureAlertTask?.value

            // Expect no publish and timer resumed.
            await finishAnimation(.dismiss, "speech-failure alert")
            #expect(!store.state.ignoreTimeUpdates)
            #expect(!didPublish)
            _ = cancellable
        }
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

    private func isDiscard(_ value: Nsp.ResultAction) -> Bool {
        if case .discard = value {
            return true
        }
        return false
    }
}
