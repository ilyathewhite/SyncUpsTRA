//
//  AppFlow.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/9/25.
//

import SwiftUI
import ReducerArchitecture

@MainActor
struct AppFlow {
    let rootIndex: Int
    let syncUp: SyncUp
    let env: NavigationEnv

    func endFlow() {
        env.popTo(rootIndex)
    }

    func syncDetails(_ syncUp: SyncUp) -> NavigationNode<SyncUpDetails> {
        .init(SyncUpDetails.store(syncUp), env)
    }

    func recordMeeting(_ syncUp: SyncUp) -> NavigationNode<RecordMeeting> {
        .init(RecordMeeting.store(syncUp: syncUp), env)
    }

    func showMeetingNotes(syncUp: SyncUp, meeting: Meeting) -> NavigationNode<MeetingNotes> {
        .init(MeetingNotes.store(syncUp: syncUp, meeting: meeting), env)
    }

    public func run() async {
        await syncDetails(syncUp).then { detailsAction, detailsIndex in
            switch detailsAction {
            case .startMeeting:
                await recordMeeting(syncUp).then { meetingAction, _ in
                    switch meetingAction {
                    case .discard:
                        break
                    case .save(let meeting):
                        appEnv.storageClient.saveMeetingNotes(syncUp, meeting)
                    }
                    env.popTo(detailsIndex)
                }

            case .showMeetingNotes(let meeting):
                await showMeetingNotes(syncUp: syncUp, meeting: meeting).then { _ , _ in
                    endFlow()
                }

            case .deleteSyncUp:
                appEnv.storageClient.deleteSyncUp(syncUp)
                endFlow()
            }
        }
    }
}
