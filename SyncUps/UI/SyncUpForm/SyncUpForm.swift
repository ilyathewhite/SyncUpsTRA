//
//  SyncUpForm.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/7/25.
//

import ReducerArchitecture

enum SyncUpForm: StoreNamespace {
    typealias PublishedValue = SyncUp

    struct StoreEnvironment {
        let editAttendee: (Attendee.ID) -> Void
    }

    enum MutatingAction {
        case updateTitle(String)
        case updateDuration(minutes: Double)
        case updateTheme(Theme)
        case updateAttendeeName(id: Attendee.ID, name: String)
        case addAttendee
        case removeAttendee(id: Attendee.ID)
    }

    enum EffectAction {
        case editAttendee(Attendee.ID)
    }

    struct StoreState {
        var syncUp: SyncUp
        let title: String
        let saveTitle: String
        let cancelTitle: String

        var duration: Double {
            Double(syncUp.duration.components.seconds / 60)
        }

        var canSave: Bool {
            guard !syncUp.title.isEmpty else { return false }
            guard !syncUp.attendees.isEmpty else { return false }
            for attendee in syncUp.attendees {
                guard !attendee.name.isEmpty else { return false }
            }
            return true
        }
    }
}

extension SyncUpForm {
    @MainActor
    static func store(syncUp: SyncUp, title: String, saveTitle: String, cancelTitle: String) -> Store {
        let state: StoreState = .init(syncUp: syncUp, title: title, saveTitle: saveTitle, cancelTitle: cancelTitle)
        return Store(state, reducer: reducer(), env: nil)
    }

    @MainActor
    static func reducer() -> Reducer {
        .init(
            run: { state, action in
                switch action {
                case .updateTitle(let value):
                    state.syncUp.title = value

                case .updateDuration(minutes: let value):
                    state.syncUp.duration = .seconds(60 * value)

                case .updateTheme(let value):
                    state.syncUp.theme = value

                case let .updateAttendeeName(id, name):
                    guard let index = state.syncUp.attendees.firstIndex(where: { $0.id == id }) else {
                        assertionFailure()
                        return .none
                    }
                    state.syncUp.attendees[index].name = name

                case .addAttendee:
                    let attendee: Attendee = .init(id: .init())
                    state.syncUp.attendees.append(attendee)
                    return .action(.effect(.editAttendee(attendee.id)))

                case .removeAttendee(let id):
                    guard let index = state.syncUp.attendees.firstIndex(where: { $0.id == id }) else {
                        assertionFailure()
                        return .none
                    }
                    state.syncUp.attendees.remove(at: index)
                }
                return .none
            },
            effect: { env, _, action in
                switch action {
                case .editAttendee(let id):
                    env.editAttendee(id)
                }
                return .none
            }
        )
    }
}
