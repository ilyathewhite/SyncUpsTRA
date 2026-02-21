//
//  SyncUpDetailsUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/7/25.
//

import SwiftUI
import ReducerArchitecture
import SwiftUIEx
import TaskIsolatedEnv

extension SyncUpDetails: StoreUINamespace {
    static let startMeetingButton = "SyncUpDetails.startMeetingButton"
    static let editButton = "SyncUpDetails.editButton"
    static let deleteMeetingButton = "SyncUpDetails.deleteMeetingButton"
    static let deleteSyncUpButton = "SyncUpDetails.deleteSyncUpButton"
    static let confirmDeleteNevermindTitle = "Nevermind"
    static let confirmDeleteYesTitle = "Yes"
    static let continueWithoutRecordingTitle = "Continue without recording"
    static let openSettingsTitle = "Open Settings"
    static let cancelTitle = "Cancel"

    static func meetingRow(_ id: Meeting.ID) -> String {
        "SyncUpDetails.meetingRow.\(id.rawValue.uuidString)"
    }

    struct ContentView: StoreContentView {
        typealias Nsp = SyncUpDetails
        @ObservedObject var store: Store

        init(_ store: Store) {
            self.store = store
        }

        @State private var confirmDelete: CheckedContinuation<Bool, Error>? = nil
        @State private var speechRecognitionRestrictedAlertResult:
            CheckedContinuation<SpeechRecognitionRestrictedAlertResult, Error>? = nil
        @State private var speechRecognitionDeniedAlertResult:
            CheckedContinuation<SpeechRecognitionDeniedAlertResult, Error>? = nil

        var editSyncUpUI: StoreUI<SyncUpForm>? { .init(store.child()) }

        var syncUp: SyncUp {
            store.state.syncUp
        }

        var body: some View {
            List {
                // Info
                Section(
                    content: {
                        // Start
                        Button(action: { store.send(.effect(.startMeeting)) }) {
                            Label("Start Meeting", systemImage: "timer")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        .testIdentifier(Nsp.startMeetingButton)

                        // Length
                        HStack {
                            Label("Length", systemImage: "clock")
                            Spacer()
                            Text(syncUp.duration.formatted(.units()))
                        }

                        // Theme
                        HStack {
                            Label("Theme", systemImage: "paintpalette")
                            Spacer()
                            Text(syncUp.theme.name)
                                .padding(4)
                                .foregroundColor(syncUp.theme.accentColor)
                                .background(syncUp.theme.mainColor)
                                .cornerRadius(4)
                        }
                    },
                    header: {
                        Text("Sync-up Info")
                    }
                )

                // Meetings
                if !syncUp.meetings.isEmpty {
                    Section(
                        content: {
                            ForEach(syncUp.meetings) { meeting in
                                NavigationRow(action: { store.publish(.showMeetingNotes(meeting)) }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                        Text(meeting.date, style: .date)
                                        Text(meeting.date, style: .time)
                                    }
                                }
                                .testIdentifier(Nsp.meetingRow(meeting.id))
                                .swipeActions(edge: .trailing) {
                                    Button(
                                        role: .destructive,
                                        action: { store.send(.mutating(.deleteMeeting(meeting.id), animated: true)) },
                                        label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    )
                                    .testIdentifier(Nsp.deleteMeetingButton)
                                }
                            }
                        },
                        header: {
                            Text("Past meetings")
                        }
                    )
                }

                // Attendees
                Section(
                    content: {
                        ForEach(syncUp.attendees) { attendee in
                            Label(attendee.name, systemImage: "person")
                        }
                    },
                    header: {
                        Text("Attendees")
                    }
                )

                // Delete
                Section {
                    Button("Delete") {
                        store.send(.effect(.confirmDeleteSyncUp))
                    }
                    .testIdentifier(Nsp.deleteSyncUpButton)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            // Sheet for editing the syncUp
            .sheet(self, \.editSyncUpUI) { ui in ui.makeView() }
            // Confirmation alert for deleting the syncUp
            .taskAlert(
                "Delete?",
                $confirmDelete,
                actions: { complete in
                    Button(Nsp.confirmDeleteNevermindTitle, role: .cancel) {
                        complete(false)
                    }
                    Button(Nsp.confirmDeleteYesTitle, role: .destructive) {
                        complete(true)
                    }
                },
                message: {
                    Text("Are you sure you want to delete this sync-up?")
                }
            )
            // Speech recognition authorization restricted alert
            .taskAlert(
                "Speech recognition restricted",
                $speechRecognitionRestrictedAlertResult,
                actions: { complete in
                    Button(Nsp.continueWithoutRecordingTitle) {
                        complete(.startMeeting)
                    }
                    Button(Nsp.cancelTitle) {
                        complete(.noAction)
                    }
                },
                message: {
                    Text(speechRecognitionRestrictedMessage)
                }
            )
            // Speech recognition authorization denied alert
            .taskAlert(
                "Speech recognition denied",
                $speechRecognitionDeniedAlertResult,
                actions: { complete in
                    Button(Nsp.continueWithoutRecordingTitle) {
                        complete(.startMeeting)
                    }
                    Button(Nsp.openSettingsTitle) {
                        complete(.openSettings)
                    }
                    Button(Nsp.cancelTitle) {
                        complete(.noAction)
                    }
                },
                message: {
                    Text(speechRecognitionDeniedMessage)
                }
            )
            .navigationTitle(syncUp.title)
            .toolbar {
                Button("Edit") {
                    store.send(.effect(.editSyncUp(syncUp)))
                }
                .testIdentifier(Nsp.editButton)
            }
            .onAppear {
                guard store.environment != nil else { return }
                store.send(.effect(.updateSyncUp))
            }
            .connectOnAppear {
                guard store.environment == nil else { return }
                store.environment = .init(
                    edit: { [weak store] syncUp in
                        guard let store else { return nil }
                        return await Nsp.edit(syncUp: syncUp, store: store)
                    },
                    save: Nsp.save(syncUp:),
                    find: Nsp.find(id:),
                    confirmDelete: {
                        try await withCheckedThrowingContinuation { continuation in
                            confirmDelete = continuation
                        }
                    },
                    checkSpeechRecognitionAuthorization: Nsp.checkSpeechRecognitionAuthorization,
                    showSpeechRecognitionRestrictedAlert: {
                        try await withCheckedThrowingContinuation { continuation in
                            speechRecognitionRestrictedAlertResult = continuation
                        }
                    },
                    showSpeechRecognitionDeniedAlert: {
                        try await withCheckedThrowingContinuation { continuation in
                            speechRecognitionDeniedAlertResult = continuation
                        }
                    },
                    openSettings: Nsp.openSettings
                )
            }
        }
    }
}

#Preview {
    prepareTaskIsolatedEnv(AppEnvironment.self, override: { env in
        env = .liveValue
    })
    let store = SyncUpDetails.store(SyncUp.designMock)
    return NavigationStack {
        store.contentView
    }
}

#Preview("restricted") {
    prepareTaskIsolatedEnv(AppEnvironment.self, override: { env in
        env = .liveValue
        env.speechClient.authorizationStatus = { .restricted }
    })
    let store = SyncUpDetails.store(SyncUp.designMock)
    return NavigationStack {
        store.contentView
    }
}

#Preview("denied") {
    prepareTaskIsolatedEnv(AppEnvironment.self, override: { env in
        env = .liveValue
        env.speechClient.authorizationStatus = { .denied }
    })
    let store = SyncUpDetails.store(SyncUp.designMock)
    return NavigationStack {
        store.contentView
    }
}
