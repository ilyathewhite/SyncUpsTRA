//
//  SyncUpDetails.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/7/25.
//

import ReducerArchitecture

enum SyncUpDetails: StoreNamespace {
    static let speechRecognitionRestrictedMessage =
    """
    Your device does not support speech recognition and so your meeting will not be recorded.
    """

    static let speechRecognitionDeniedMessage =
    """
    You previously denied speech recognition and so your meeting meeting will not be \
    recorded. You can enable speech recognition in settings, or you can continue without \
    recording.
    """

    enum AuthorizationStatus {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    enum SpeechRecognitionRestrictedAlertResult {
        case startMeeting
        case noAction
    }

    enum SpeechRecognitionDeniedAlertResult {
        case openSettings
        case startMeeting
        case noAction
    }

    enum ResultAction {
        case startMeeting
        case showMeetingNotes(Meeting)
        case deleteSyncUp
    }

    typealias PublishedValue = ResultAction

    struct StoreEnvironment {
        let edit: (SyncUp) async -> SyncUp?
        let save: (SyncUp) -> Void
        let find: (SyncUp.ID) -> SyncUp?
        let confirmDelete: () async throws -> Bool
        let checkSpeechRecognitionAuthorization: () -> AuthorizationStatus
        let showSpeechRecognitionRestrictedAlert: () async throws -> SpeechRecognitionRestrictedAlertResult
        let showSpeechRecognitionDeniedAlert: () async throws -> SpeechRecognitionDeniedAlertResult
        let openSettings: () -> Void
    }

    enum MutatingAction {
        case deleteMeeting(Meeting.ID)
        case update(SyncUp)
    }

    enum EffectAction {
        case editSyncUp(SyncUp)
        case confirmDeleteSyncUp
        case checkSpeechRecognitionAuthorization
        case showSpeechRecognitionRestrictedAlert
        case showSpeechRecognitionDeniedAlert
        case openSettings
        case saveSyncUp(SyncUp)
        case updateSyncUp
    }

    struct StoreState {
        var syncUp: SyncUp
    }
}

extension SyncUpDetails {
    @MainActor
    static func store(_ syncUp: SyncUp) -> Store {
        Store(.init(syncUp: syncUp), reducer: reducer(), env: nil)
    }

    @MainActor
    static func reducer() -> Reducer {
        .init(
            run: { state, action in
                switch action {
                case .deleteMeeting(let id):
                    guard let index = state.syncUp.meetings.firstIndex(where: { $0.id == id }) else {
                        assertionFailure()
                        return .none
                    }
                    state.syncUp.meetings.remove(at: index)
                    return .action(.effect(.saveSyncUp(state.syncUp)))

                case .update(let syncUp):
                    guard state.syncUp.id == syncUp.id else {
                        assertionFailure()
                        return .none
                    }
                    state.syncUp = syncUp
                    return .action(.effect(.saveSyncUp(syncUp)))
                }
            },
            effect: { env, state, action in
                switch action {
                case .editSyncUp(let syncUp):
                    return .asyncAction {
                        if let syncUp = await env.edit(syncUp) {
                            return .mutating(.update(syncUp))
                        }
                        else {
                            return .none
                        }
                    }

                case .confirmDeleteSyncUp:
                    return .asyncAction {
                        guard let shouldDelete = try? await env.confirmDelete() else { return .none }
                        if shouldDelete {
                            return .publish(.deleteSyncUp)
                        }
                        else {
                            return .none
                        }
                    }

                case .saveSyncUp(let syncUp):
                    env.save(syncUp)
                    return .none

                case .updateSyncUp:
                    if let syncUp = env.find(state.syncUp.id) {
                        return .action(.mutating(.update(syncUp), animated: true))
                    }
                    else {
                        assertionFailure()
                        return .none
                    }

                case .checkSpeechRecognitionAuthorization:
                    let result = env.checkSpeechRecognitionAuthorization()
                    switch result {
                    case .notDetermined, .authorized:
                        return .action(.publish(.startMeeting))
                    case .restricted:
                        return .action(.effect(.showSpeechRecognitionRestrictedAlert))
                    case .denied:
                        return .action(.effect(.showSpeechRecognitionDeniedAlert))
                    }

                case .showSpeechRecognitionRestrictedAlert:
                    return .asyncAction {
                        guard let result = try? await env.showSpeechRecognitionRestrictedAlert() else { return .none }
                        switch result {
                        case .startMeeting:
                            return .publish(.startMeeting)
                        case .noAction:
                            return .none
                        }
                    }

                case .showSpeechRecognitionDeniedAlert:
                    return .asyncAction {
                        guard let result = try? await env.showSpeechRecognitionDeniedAlert() else { return .none }
                        switch result {
                        case .startMeeting:
                            return .publish(.startMeeting)
                        case .openSettings:
                            return .effect(.openSettings)
                        case .noAction:
                            return .none
                        }
                    }

                case .openSettings:
                    env.openSettings()
                    return .none
                }
            }
        )
    }
}

