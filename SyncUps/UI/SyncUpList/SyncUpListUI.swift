//
//  SyncUpListUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/6/25.
//

import SwiftUI
import ReducerArchitecture

extension SyncUpList: StoreUINamespace {
    struct ContentView: StoreContentView {
        typealias Nsp = SyncUpList
        @ObservedObject var store: Store

        init(_ store: Store) {
            self.store = store
        }

        var createSyncUpUI: StoreUI<SyncUpForm>? { .init(store.child()) }

        var body: some View {
            List {
                ForEach(Array(store.state.syncUps)) { syncUp in
                    CardView(syncUp: syncUp)
                        .listRowBackground(syncUp.theme.mainColor)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.publish(syncUp)
                        }
                }
            }
            .sheet(self, \.createSyncUpUI) { ui in ui.makeView() }
            .toolbar {
                Button(action: { store.send(.effect(.addSyncUp)) }) {
                    Image(systemName: "plus")
                }
            }
            .navigationTitle("Daily Sync-ups")
            .onAppear {
                guard store.environment != nil else { return }
                store.send(.effect(.reload))
            }
            .connectOnAppear {
                store.environment = .init(
                    createSyncUp: { [weak store] in
                        guard let store else { return nil }
                        return await Nsp.createSyncUp(store: store)
                    },
                    allSyncUps: Nsp.allSyncUps
                )
            }
        }
    }
}

struct CardView: View {
    let syncUp: SyncUp

    var body: some View {
        VStack(alignment: .leading) {
            Text(syncUp.title)
                .font(.headline)
            Spacer()
            HStack {
                Label("\(syncUp.attendees.count)", systemImage: "person.3")
                Spacer()
                Label(syncUp.duration.formatted(.units()), systemImage: "clock")
                    .labelStyle(.trailingIcon)
            }
            .font(.caption)
        }
        .padding()
        .foregroundColor(syncUp.theme.accentColor)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: Self { Self() }
}

#Preview {
    let store = SyncUpList.store(syncUps: appEnv.storageClient.allSyncUps())
    return NavigationStack {
        store.contentView
    }
}
