//
//  MeetingNotes.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/8/25.
//

import ReducerArchitecture

enum MeetingNotes: StoreNamespace {
    typealias PublishedValue = Void

    typealias StoreEnvironment = Never
    typealias MutatingAction = Void
    typealias EffectAction = Never

    struct StoreState {
        let syncUp: SyncUp
        let meeting: Meeting
    }
}

extension MeetingNotes {
    @MainActor
    static func store(syncUp: SyncUp, meeting: Meeting) -> Store {
        Store(.init(syncUp: syncUp, meeting: meeting), reducer: reducer())
    }
}
