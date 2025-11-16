//
//  SyncUpDetailsUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/7/25.
//

import SwiftUI
import ReducerArchitecture
import SwiftUIEx

extension SyncUpDetails: StoreUINamespace {
    struct ContentView: StoreContentView {
        typealias Nsp = SyncUpDetails
        @ObservedObject var store: Store

        init(_ store: Store) {
            self.store = store
        }

        @State private var confirmDelete: CheckedContinuation<Bool, Never>? = nil
        @State private var speechRecognitionRestrictedAlertResult:
            CheckedContinuation<SpeechRecognitionRestrictedAlertResult, Never>? = nil
        @State private var speechRecognitionDeniedAlertResult:
            CheckedContinuation<SpeechRecognitionDeniedAlertResult, Never>? = nil

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
                        Button(action: { store.send(.effect(.checkSpeechRecognitionAuthorization)) }) {
                            Label("Start Meeting", systemImage: "timer")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }

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
                                .swipeActions(edge: .trailing) {
                                    Button(
                                        role: .destructive,
                                        action: { store.send(.mutating(.deleteMeeting(meeting.id), animated: true)) },
                                        label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    )
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
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            // Sheet for editing the syncUp
            .sheet(self, \.editSyncUpUI) { ui in ui.makeView() }
            // Confirmation alert for deleting the syncUp
            .taskAlert(
                "Delete",
                $confirmDelete,
                actions: { complete in
                    Button("Nevermind", role: .cancel) {
                        complete(false)
                    }
                    Button("Yes", role: .destructive) {
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
                    Button("Continue without recording") {
                        complete(.startMeeting)
                    }
                    Button("Cancel") {
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
                    Button("Continue without recording") {
                        complete(.startMeeting)
                    }
                    Button("Open Settings") {
                        complete(.openSettings)
                    }
                    Button("Cancel") {
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
            }
            .onAppear {
                guard store.environment != nil else { return }
                store.send(.effect(.updateSyncUp))
            }
            .connectOnAppear {
                store.environment = .init(
                    edit: { syncUp in
                        let editStore = SyncUpForm.store(
                            syncUp: syncUp,
                            title: syncUp.title,
                            saveTitle: "Done",
                            cancelTitle: "Cancel"
                        )
                        return try? await store.run(editStore)
                    },
                    save: { syncUp in
                        appEnv.storageClient.saveSyncUp(syncUp)
                    },
                    find: { id in
                        appEnv.storageClient.findSyncUp(id)
                    },
                    confirmDelete: {
                        return await withCheckedContinuation { continuation in
                            confirmDelete = continuation
                        }
                    },
                    checkSpeechRecognitionAuthorization: {
                        switch appEnv.speechClient.authorizationStatus() {
                        case .authorized:
                            return .authorized
                        case .notDetermined:
                            return .notDetermined
                        case .restricted:
                            return .restricted
                        case .denied:
                            return .denied
                        default:
                            return .notDetermined
                        }
                    },
                    showSpeechRecognitionRestrictedAlert: {
                        return await withCheckedContinuation { continuation in
                            speechRecognitionRestrictedAlertResult = continuation
                        }
                    },
                    showSpeechRecognitionDeniedAlert: {
                        return await withCheckedContinuation { continuation in
                            speechRecognitionDeniedAlertResult = continuation
                        }
                    },
                    openSettings: {
                        appEnv.openSettings()
                    }
                )
            }
        }
    }
}

#Preview {
    appEnv = .init()
    let store = SyncUpDetails.store(.designMock)
    return NavigationStack {
        store.contentView
    }
}

#Preview("restricted") {
    appEnv = .init()
    appEnv.speechClient.authorizationStatus =  { .restricted }

    let store = SyncUpDetails.store(.designMock)
    return NavigationStack {
        store.contentView
    }
}

#Preview("denied") {
    appEnv = .init()
    appEnv.speechClient.authorizationStatus =  { .denied }

    let store = SyncUpDetails.store(.designMock)
    return NavigationStack {
        store.contentView
    }
}
