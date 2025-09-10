//
//  SyncUpList.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/6/25.
//

import ReducerArchitecture

enum SyncUpList: StoreNamespace {
    typealias PublishedValue = SyncUp

    struct StoreEnvironment {
        var createSyncUp: () async -> SyncUp?
        var allSyncUps: () -> [SyncUp]
    }

    enum MutatingAction {
        case reload([SyncUp])
    }

    enum EffectAction {
        case addSyncUp
        case reload
    }

    struct StoreState {
        var syncUps: [SyncUp] = []
    }
}

extension SyncUpList {
    @MainActor
    static func store(syncUps: [SyncUp]) -> Store {
        Store(.init(syncUps: syncUps), reducer: reducer(), env: nil)
    }

    @MainActor
    static func reducer() -> Reducer {
        .init(
            run: { state, action in
                switch action {
                case .reload(let syncUps):
                    state.syncUps = syncUps
                }
                return .none
            },
            effect: { env, state, action in
                switch action {
                case .addSyncUp:
                    return .asyncAction {
                        if await env.createSyncUp() != nil {
                            return .effect(.reload)
                        }
                        else {
                            return .none
                        }
                    }

                case .reload:
                    let allSyncUps = env.allSyncUps()
                    return .action(.mutating(.reload(allSyncUps), animated: true))
                }
            }
        )
    }
}
