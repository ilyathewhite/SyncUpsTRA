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
        case discrard
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
        let showEndMeetingAlert: (_ discardable: Bool) async -> EndMeetingAlertResult
        let showSpeechRecognizerFailureAlert: () async -> SpeechRecognizerFailureAlertResult
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

        var durationRemaining: Duration {
            syncUp.duration - .seconds(secondsElapsed)
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
            secondsElapsed = speakerIndex * Int(syncUp.durationPerAttendee.components.seconds)
        }
    }
}

extension RecordMeeting {
    @MainActor
    static func store(syncUp: SyncUp) -> Store {
        Store(.init(syncUp: syncUp), reducer: reducer(), env: nil)
    }

    @MainActor
    static func reducer() -> Reducer {
        .init(
            run: { state, action in
                switch action {
                case .nextSpeaker:
                    guard state.speakerIndex + 1 < state.syncUp.attendees.count else {
                        return .action(.effect(.showEndMeetingAlert(discardable: false)))
                    }

                    state.moveToNextSpeaker()
                    return .action(.effect(.playNextSpeakerSound))

                case .updateTranscript(let value):
                    state.transcript = value
                    return .none

                case .incSecondsElapsed:
                    guard !state.ignoreTimeUpdates else { return .none }
                    state.secondsElapsed += 1
                    let secondsPerAttendee = Int(state.syncUp.durationPerAttendee.components.seconds)
                    if !state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
                        return .none
                    }
                    else if state.speakerIndex + 1 < state.syncUp.attendees.count {
                        return .action(.mutating(.nextSpeaker))
                    }
                    else if state.meetingFinished {
                        return .action(.effect(.publishMeeting(transcript: state.transcript)))
                    }
                    else {
                        return .none
                    }

                case .updateIgnoreTimer(let value):
                    state.ignoreTimeUpdates = value
                    return .none
                }
            },
            effect: { env, state, action in
                switch action {
                case .showEndMeetingAlert(let discardable):
                    return .asyncActionSequence {
                        .init { continuation in
                            Task {
                                // ignore the timer while showing the alert
                                continuation.yield(.mutating(.updateIgnoreTimer(true)))
                                defer { continuation.yield(.mutating(.updateIgnoreTimer(false))) }

                                let alertResult = await env.showEndMeetingAlert(discardable)
                                switch alertResult {
                                case .saveAndEnd:
                                    continuation.yield(.effect(.publishMeeting(transcript: state.transcript)))

                                case .discrard:
                                    continuation.yield(.publish(.discard))

                                case .resume:
                                    break
                                }
                            }
                        }
                    }

                case .showSpeechRecognizerFailureAlert:
                    return .asyncActionSequence {
                        .init { continuation in
                            Task {
                                // ignore the timer while showing the alert
                                continuation.yield(.mutating(.updateIgnoreTimer(true)))
                                defer { continuation.yield(.mutating(.updateIgnoreTimer(false))) }

                                let result = await env.showSpeechRecognizerFailureAlert()
                                switch result {
                                case .discard:
                                    continuation.yield(.publish(.discard))
                                case .continue:
                                    break
                                }
                            }
                        }
                    }

                case .playNextSpeakerSound:
                    env.playNextSpeakerSound()
                    return .none

                case .startOneSecondTimer:
                    return .asyncActionSequence {
                        return .init { continuation in
                            Task {
                                let clock = ContinuousClock()
                                while !Task.isCancelled {
                                    try? await clock.sleep(for: .seconds(1))
                                    continuation.yield(.mutating(.incSecondsElapsed))
                                }
                            }
                        }
                    }

                case .startTranscriptRecording:
                    return .asyncActionSequence {
                        .init { continuation in

                            Task {
                                let updates = await env.startTranscriptRecording()
                                do {
                                    for try await update in updates {
                                        let value = update.bestTranscription.formattedString
                                        continuation.yield(.mutating(.updateTranscript(value)))
                                    }
                                }
                                catch {
                                    continuation.yield(.effect(.showSpeechRecognizerFailureAlert))
                                }
                            }
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
        )
    }
}

