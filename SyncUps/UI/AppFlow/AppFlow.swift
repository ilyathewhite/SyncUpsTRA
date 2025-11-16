//
//  AppFlow.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/9/25.
//

import SwiftUI
import ReducerArchitecture
import AsyncNavigation

@MainActor
struct AppFlow {
    let rootIndex: Int
    let syncUp: SyncUp
    let proxy: NavigationProxy

    func endFlow() {
        proxy.popTo(rootIndex)
    }

    func syncDetails(_ syncUp: SyncUp) -> NavigationNode<SyncUpDetails> {
        .init(SyncUpDetails.store(syncUp), proxy)
    }

    func recordMeeting(_ syncUp: SyncUp) -> NavigationNode<RecordMeeting> {
        .init(RecordMeeting.store(syncUp: syncUp), proxy)
    }

    func showMeetingNotes(syncUp: SyncUp, meeting: Meeting) -> NavigationNode<MeetingNotes> {
        .init(MeetingNotes.store(syncUp: syncUp, meeting: meeting), proxy)
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
                    proxy.popTo(detailsIndex)
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
