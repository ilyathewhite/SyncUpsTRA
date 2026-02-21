//
//  RecordMeeting.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/8/25.
//

import Foundation
import ReducerArchitecture

enum RecordMeeting: StoreNamespace {
    enum EndMeetingAlertResult {
        case saveAndEnd
        case discard
        case resume
    }

    enum SpeechRecognizerFailureAlertResult {
        case `continue`
        case discard
    }

    enum ResultAction {
        case save(Meeting)
        case discard
    }

    typealias PublishedValue = ResultAction

    struct StoreEnvironment {
        let showEndMeetingAlert: (_ discardable: Bool) async throws -> EndMeetingAlertResult
        let showSpeechRecognizerFailureAlert: () async throws -> SpeechRecognizerFailureAlertResult
        let prepareSoundPlayer: () -> Void
        let playNextSpeakerSound: () -> Void
        let startTranscriptRecording: () async -> AsyncThrowingStream<SpeechRecognitionResult, Error>
        let now: () -> Date
    }

    enum MutatingAction {
        case nextSpeaker
        case updateTranscript(String)
        case incSecondsElapsed
        case updateIgnoreTimer(Bool)
    }

    enum EffectAction {
        case showEndMeetingAlert(discardable: Bool)
        case showSpeechRecognizerFailureAlert
        case prepareSoundPlayer
        case playNextSpeakerSound
        case startOneSecondTimer
        case startTranscriptRecording
        case publishMeeting(transcript: String)
    }

    struct StoreState {
        let syncUp: SyncUp
        var secondsElapsed = 0
        var speakerIndex = 0
        var transcript = ""
        var ignoreTimeUpdates = false

        var progress: Double {
            min(1, Duration.seconds(secondsElapsed) / syncUp.duration)
        }

        var durationRemaining: Duration {
            syncUp.duration - .seconds(secondsElapsed)
        }

        var secondsPerAttendee: Int {
            Int(syncUp.durationPerAttendee.components.seconds)
        }

        var meetingFinished: Bool {
            syncUp.duration <= .seconds(secondsElapsed)
        }

        var nextSpeakerText: String {
            if speakerIndex < syncUp.attendees.count - 1 {
                return "Speaker \(speakerIndex + 1) of \(syncUp.attendees.count)"
            }
            else {
                return "No more speakers."
            }
        }

        mutating func moveToNextSpeaker() {
            speakerIndex += 1
            secondsElapsed = speakerIndex * secondsPerAttendee
        }
    }
}

extension RecordMeeting {
    @MainActor
    static func store(syncUp: SyncUp) -> Store {
        Store(.init(syncUp: syncUp), env: nil)
    }

    // This is not a chain of effects to avoid returning a task
    // that would run forever due to an endless effect.
    @MainActor
    @discardableResult
    static func start(_ store: Store) -> Task<Void, Never> {
        Task {
            await store.send(.effect(.prepareSoundPlayer))?.value
            // endless effect, don't wait for it
            store.send(.effect(.startOneSecondTimer))
            await store.send(.effect(.startTranscriptRecording))?.value
        }
    }

    @MainActor
    static func reduce(_ state: inout StoreState, _ action: MutatingAction) -> Store.SyncEffect {
        switch action {
        case .nextSpeaker:
            guard !state.meetingFinished else { return .none }
            state.moveToNextSpeaker()
            return .action(.effect(.playNextSpeakerSound))

        case .updateTranscript(let value):
            state.transcript = value
            return .none

        case .incSecondsElapsed:
            guard !state.ignoreTimeUpdates else { return .none }
            state.secondsElapsed += 1

            if state.meetingFinished {
                return .action(.effect(.publishMeeting(transcript: state.transcript)))
            }

            if !state.secondsElapsed.isMultiple(of: state.secondsPerAttendee) {
                return .none
            }
            else if state.speakerIndex + 1 < state.syncUp.attendees.count {
                return .action(.mutating(.nextSpeaker))
            }
            else {
                return .none
            }

        case .updateIgnoreTimer(let value):
            state.ignoreTimeUpdates = value
            return .none
        }
    }

    @MainActor
    static func runEffect(_ env: StoreEnvironment, _ state: StoreState, _ action: EffectAction) -> Store.Effect {
        switch action {
        case .showEndMeetingAlert(let discardable):
            return .asyncActionSequence { send in
                // ignore the timer while showing the alert
                send(.mutating(.updateIgnoreTimer(true)))
                defer { send(.mutating(.updateIgnoreTimer(false))) }

                guard let alertResult = try? await env.showEndMeetingAlert(discardable) else { return }
                switch alertResult {
                case .saveAndEnd:
                    send(.effect(.publishMeeting(transcript: state.transcript)))

                case .discard:
                    send(.publish(.discard))

                case .resume:
                    break
                }
            }

        case .showSpeechRecognizerFailureAlert:
            return .asyncActionSequence { send in
                // ignore the timer while showing the alert
                send(.mutating(.updateIgnoreTimer(true)))
                defer { send(.mutating(.updateIgnoreTimer(false))) }

                guard let result = try? await env.showSpeechRecognizerFailureAlert() else { return }
                switch result {
                case .discard:
                    send(.publish(.discard))
                case .continue:
                    break
                }
            }

        case .playNextSpeakerSound:
            env.playNextSpeakerSound()
            return .none

        case .startOneSecondTimer:
            return .asyncActionSequence { send in
                let clock = ContinuousClock()
                while !Task.isCancelled {
                    try? await clock.sleep(for: .seconds(1))
                    send(.mutating(.incSecondsElapsed))
                }
            }

        case .startTranscriptRecording:
            return .asyncActionSequence { send in
                let updates = await env.startTranscriptRecording()
                do {
                    for try await update in updates {
                        let value = update.bestTranscription.formattedString
                        send(.mutating(.updateTranscript(value)))
                    }
                }
                catch {
                    send(.effect(.showSpeechRecognizerFailureAlert))
                }
            }

        case .prepareSoundPlayer:
            env.prepareSoundPlayer()
            return .none

        case .publishMeeting(let transcript):
            let meeting = Meeting(
                id: .init(),
                date: env.now(),
                transcript: transcript
            )
            return .action(.publish(.save(meeting)))
        }
    }
}
