//
//  MeetingNotesUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/8/25.
//

import SwiftUI
import ReducerArchitecture

extension MeetingNotes: StoreUINamespace {
    struct ContentView: StoreContentView {
        typealias Nsp = MeetingNotes
        @ObservedObject var store: Store

        var body: some View {
            ScrollView {
                VStack(alignment: .leading) {
                    Divider()
                        .padding(.bottom)
                    Text("Attendees")
                        .font(.headline)
                    ForEach(store.state.syncUp.attendees) { attendee in
                        Text(attendee.name)
                    }
                    Text("Transcript")
                        .font(.headline)
                        .padding(.top)
                    Text(store.state.meeting.transcript)
                }
            }
            .navigationTitle(Text(store.state.meeting.date, style: .date))
            .padding()
        }
    }
}

#Preview {
    let store = MeetingNotes.store(
        syncUp: .designMock,
        meeting: .init(id: .init(), date: .now, transcript: "Hello, World!")
    )
    return NavigationStack {
        store.contentView
    }
}
