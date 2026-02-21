//
//  SyncUpFormUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/7/25.
//

import SwiftUI
import ReducerArchitecture
import SwiftUIEx

extension SyncUpForm: StoreUINamespace {
    static let titleField = "SyncUpForm.titleField"
    static let durationSlider = "SyncUpForm.durationSlider"
    static let themePicker = "SyncUpForm.themePicker"
    static let attendeeField = "SyncUpForm.attendeeField"
    static let deleteAttendeeButton = "SyncUpForm.deleteAttendeeButton"
    static let newAttendeeButton = "SyncUpForm.newAttendeeButton"
    static let cancelButton = "SyncUpForm.cancelButton"
    static let saveButton = "SyncUpForm.saveButton"

    static func themeOption(_ theme: Theme) -> String {
        "SyncUpForm.themeOption.\(theme.rawValue)"
    }

    struct ThemePicker: View {
        @Binding var selection: Theme

        var body: some View {
            Picker("Theme", selection: $selection) {
                ForEach(Theme.allCases) { theme in
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.mainColor)
                        Label(theme.name, systemImage: "paintpalette")
                            .padding(4)
                    }
                    .foregroundColor(theme.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .testIdentifier(SyncUpForm.themeOption(theme))
                    .tag(theme)
                }
            }
            .testIdentifier(SyncUpForm.themePicker)
        }
    }

    enum Field: Hashable {
      case attendee(Attendee.ID)
      case title
    }

    struct ContentView: StoreContentView {
        typealias Nsp = SyncUpForm
        @ObservedObject var store: Store

        init(_ store: Store) {
            self.store = store
        }

        @FocusState var focus: Field?

        var body: some View {
            NavigationStack {
                Form {
                    Section ("Requirements") {
                        Text("A sync-up requires a title and at least one attendee.\nEvery attendee must have a non-empty name.")
                            .font(.footnote)
                    }                
                    Section(
                        content: {
                            // Title
                            TextField(
                                "Title",
                                text: store.binding(\.syncUp.title, { .updateTitle($0) })
                            )
                            .testIdentifier(Nsp.titleField)
                            .focused($focus, equals: .title)

                            // Duration
                            HStack {
                                Slider(
                                    value: store.binding(\.duration, { .updateDuration(minutes: $0) }),
                                    in: 5...30,
                                    step: 1
                                ) {
                                    Text("Length")
                                }
                                .testIdentifier(Nsp.durationSlider)
                                Spacer()
                                Text(store.state.syncUp.duration.formatted(.units()))
                            }

                            // Theme
                            ThemePicker(selection: store.binding(\.syncUp.theme, { .updateTheme($0) }))
                        },
                        header: {
                            Text("Sync-up Info")
                        }
                    )
                    Section(
                        content: {
                            // Attendees
                            ForEach(store.state.syncUp.attendees) { attendee in
                                TextField(
                                    "Name",
                                    text: .init(
                                        get: { attendee.name },
                                        set: { store.send(.mutating(.updateAttendeeName(id: attendee.id, name: $0)))}
                                    )
                                )
                                .testIdentifier(Nsp.attendeeField)
                                .focused($focus, equals: .attendee(attendee.id))
                                .swipeActions(edge: .trailing) {
                                    Button(
                                        role: .destructive,
                                        action: { store.send(.mutating(.removeAttendee(id: attendee.id))) },
                                        label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    )
                                    .testIdentifier(Nsp.deleteAttendeeButton)
                                }
                            }

                            // Add attendee
                            Button("New attendee") {
                                store.send(.mutating(.addAttendee))
                            }
                            .testIdentifier(Nsp.newAttendeeButton)
                        },
                        header: {
                            Text("Attendees")
                        }
                    )
                }
                .navigationTitle(store.state.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(store.state.cancelTitle) {
                            store.cancel()
                        }
                        .testIdentifier(Nsp.cancelButton)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(store.state.saveTitle) {
                            store.publish(store.state.syncUp)
                        }
                        .testIdentifier(Nsp.saveButton)
                        .disabled(!store.state.canSave)
                    }
                }
            }
            .task {
                if focus == nil {
                    await Task.yield()
                    focus = .title
                }
            }
            .connectOnAppear {
                store.environment = .init(
                    editAttendee: { id in
                        focus = .attendee(id)
                    }
                )
            }
        }
    }
}

#Preview {
    let syncUp = SyncUp(id: .init())
    let store = SyncUpForm.store(syncUp: syncUp, title: "Sync-up form", saveTitle: "Save", cancelTitle: "Cancel")
    return NavigationStack {
        store.contentView
    }
}
