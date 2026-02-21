//
//  RecordMeetingEnv.swift
//  SyncUps
//
//  Created by Codex on 2/13/26.
//

import Speech

extension RecordMeeting {
    @MainActor
    static func prepareSoundPlayer() {
        appEnv.soundEffectClient.load("ding.wav")
    }

    @MainActor
    static func playNextSpeakerSound() {
        appEnv.soundEffectClient.play()
    }

    static func startTranscriptRecording() async -> AsyncThrowingStream<SpeechRecognitionResult, Error> {
        let authorizationStatus = appEnv.speechClient.authorizationStatus()
        let authorization =
            authorizationStatus == .notDetermined
            ? await appEnv.speechClient.requestAuthorization()
            : authorizationStatus

        guard authorization == .authorized else {
            return .init(unfolding: { nil })
        }

        return await appEnv.speechClient.startTask(SFSpeechAudioBufferRecognitionRequest())
    }

    static func now() -> Date {
        appEnv.now()
    }
}
