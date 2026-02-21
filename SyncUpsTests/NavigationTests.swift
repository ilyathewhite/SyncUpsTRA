import Foundation
import AsyncNavigation
import ReducerArchitecture
import TaskIsolatedEnv
import Testing
@testable import SyncUps

extension NavigationTests {
    // MARK: - Meeting Flows

    // Save meeting flow.
    // Flow:
    // SyncUpList - pick a sync-up
    // SyncUpDetails - start meeting
    // RecordMeeting - save meeting
    // SyncUpDetails - go back
    // SyncUpList
    @Test
    func startMeetingSaveNavigatesToRecordMeetingSavesAndReturnsToRoot() async throws {
        // Set up sync-up, storage spy, and isolated environment.
        let syncUp = makeSyncUp(title: "Design")
        let meeting = makeMeeting(transcript: "Hello world")
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up root flow and navigation proxy.
            let proxy = TestNavigationProxy()
            let (rootStore, flow) = makeRootAndFlow(syncUp: syncUp, proxy: proxy)
            let flowTask = Task {
                await flow.run()
            }
            var timeIndex = 1

            // List -> details -> record(save) -> details.
            let detailsStore = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStore.state.syncUp == syncUp)
            await detailsStore.publishOnRequest(.startMeeting)

            let recordStore = try await proxy.getStore(RecordMeeting.self, &timeIndex)
            #expect(recordStore.state.syncUp == syncUp)
            await recordStore.publishOnRequest(.save(meeting))

            let detailsStoreAfterMeeting = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStoreAfterMeeting == detailsStore)
            let savedMeetingNotes = spy.allSavedMeetingNotes()
            #expect(savedMeetingNotes.count == 1)
            if let savedMeetingNotes = savedMeetingNotes.first {
                #expect(savedMeetingNotes.0 == syncUp)
                #expect(savedMeetingNotes.1 == meeting)
            }

            // Details -> list via back.
            proxy.backAction()

            let rootStoreAfterBack = try await proxy.getStore(SyncUpList.self, &timeIndex)
            // Expect returned to root list.
            #expect(rootStoreAfterBack == rootStore)

            await flowTask.value
        }
    }

    // Discard meeting flow.
    // Flow:
    // SyncUpList - pick a sync-up
    // SyncUpDetails - start meeting
    // RecordMeeting - discard meeting
    // SyncUpDetails - go back
    // SyncUpList
    @Test
    func startMeetingDiscardNavigatesToRecordMeetingAndReturnsToRootWithoutSave() async throws {
        // Set up sync-up, storage spy, and isolated environment.
        let syncUp = makeSyncUp(title: "Design")
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up root flow and navigation proxy.
            let proxy = TestNavigationProxy()
            let (rootStore, flow) = makeRootAndFlow(syncUp: syncUp, proxy: proxy)
            let flowTask = Task {
                await flow.run()
            }
            var timeIndex = 1

            // List -> details -> record(discard) -> details.
            let detailsStore = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStore.state.syncUp == syncUp)
            await detailsStore.publishOnRequest(.startMeeting)

            let recordStore = try await proxy.getStore(RecordMeeting.self, &timeIndex)
            #expect(recordStore.state.syncUp == syncUp)
            await recordStore.publishOnRequest(.discard)

            let detailsStoreAfterMeeting = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStoreAfterMeeting == detailsStore)
            #expect(spy.allSavedMeetingNotes().isEmpty)

            // Details -> list via back.
            proxy.backAction()

            let rootStoreAfterBack = try await proxy.getStore(SyncUpList.self, &timeIndex)
            // Expect returned to root list with no saved notes.
            #expect(rootStoreAfterBack == rootStore)

            await flowTask.value
        }
    }

    // Meeting notes flow.
    // Flow:
    // SyncUpList - pick a sync-up
    // SyncUpDetails - open meeting notes
    // MeetingNotes - close notes
    // SyncUpList
    @Test
    func showMeetingNotesNavigatesToNotesAndReturnsToRoot() async throws {
        // Set up sync-up with meeting, storage spy, and isolated environment.
        let meeting = makeMeeting(transcript: "Decisions")
        let syncUp = makeSyncUp(title: "Design", meetings: [meeting])
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up root flow and navigation proxy.
            let proxy = TestNavigationProxy()
            let (rootStore, flow) = makeRootAndFlow(syncUp: syncUp, proxy: proxy)
            let flowTask = Task {
                await flow.run()
            }
            var timeIndex = 1

            // List -> details -> notes -> list.
            let detailsStore = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStore.state.syncUp == syncUp)
            await detailsStore.publishOnRequest(.showMeetingNotes(meeting))

            let meetingNotesStore = try await proxy.getStore(MeetingNotes.self, &timeIndex)
            #expect(meetingNotesStore.state.syncUp == syncUp)
            #expect(meetingNotesStore.state.meeting == meeting)
            await meetingNotesStore.publishOnRequest(())

            let rootStoreAfterNotes = try await proxy.getStore(SyncUpList.self, &timeIndex)
            // Expect returned to root with no storage side effects.
            #expect(rootStoreAfterNotes == rootStore)
            #expect(spy.allSavedMeetingNotes().isEmpty)
            #expect(spy.allDeletedSyncUps().isEmpty)

            await flowTask.value
        }
    }

    // Delete sync-up flow.
    // Flow:
    // SyncUpList - pick a sync-up
    // SyncUpDetails - delete sync-up
    // SyncUpList
    @Test
    func deleteSyncUpFromDetailsDeletesAndReturnsToRoot() async throws {
        // Set up sync-up, storage spy, and isolated environment.
        let syncUp = makeSyncUp(title: "Design")
        let spy = StorageSpy()
        try await withStorageSpyEnvironment(spy) {
            // Set up root flow and navigation proxy.
            let proxy = TestNavigationProxy()
            let (rootStore, flow) = makeRootAndFlow(syncUp: syncUp, proxy: proxy)
            let flowTask = Task {
                await flow.run()
            }
            var timeIndex = 1

            // List -> details(delete) -> list.
            let detailsStore = try await proxy.getStore(SyncUpDetails.self, &timeIndex)
            #expect(detailsStore.state.syncUp == syncUp)
            await detailsStore.publishOnRequest(.deleteSyncUp)

            let rootStoreAfterDelete = try await proxy.getStore(SyncUpList.self, &timeIndex)
            // Expect returned to root and sync-up deleted.
            #expect(rootStoreAfterDelete == rootStore)
            #expect(spy.allDeletedSyncUps() == [syncUp])

            await flowTask.value
        }
    }

    private func withStorageSpyEnvironment(
        _ spy: StorageSpy,
        operation: @MainActor () async throws -> Void
    ) async throws {
        try await withTaskIsolatedEnv(
            AppEnvironment.self,
            override: { @Sendable env in
                env.storageClient = makeNavigationStorageClient(spy: spy)
            },
            operation: operation
        )
    }

    private func makeRootAndFlow(
        syncUp: SyncUp,
        proxy: TestNavigationProxy
    ) -> (SyncUpList.Store, AppFlow) {
        let rootStore = SyncUpList.store(syncUps: [syncUp])
        _ = proxy.push(StoreUI<SyncUpList>(rootStore))
        let flow = AppFlow(syncUp: syncUp, proxy: proxy)
        return (rootStore, flow)
    }

    private func makeSyncUp(title: String, meetings: [Meeting] = []) -> SyncUp {
        SyncUp(
            id: SyncUp.ID(),
            attendees: [Attendee(id: Attendee.ID(), name: "Blob")],
            meetings: meetings,
            title: title
        )
    }

    private func makeMeeting(transcript: String) -> Meeting {
        Meeting(
            id: Meeting.ID(),
            date: Date(timeIntervalSince1970: 1_234_567_890),
            transcript: transcript
        )
    }
}

private final class StorageSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var deletedSyncUps: [SyncUp] = []
    private var savedMeetingNotes: [(SyncUp, Meeting)] = []

    func allDeletedSyncUps() -> [SyncUp] {
        lock.lock()
        defer { lock.unlock() }
        return deletedSyncUps
    }

    func allSavedMeetingNotes() -> [(SyncUp, Meeting)] {
        lock.lock()
        defer { lock.unlock() }
        return savedMeetingNotes
    }

    func appendDeletedSyncUp(_ syncUp: SyncUp) {
        lock.lock()
        defer { lock.unlock() }
        deletedSyncUps.append(syncUp)
    }

    func appendSavedMeetingNotes(syncUp: SyncUp, meeting: Meeting) {
        lock.lock()
        defer { lock.unlock() }
        savedMeetingNotes.append((syncUp, meeting))
    }
}

private func makeNavigationStorageClient(spy: StorageSpy) -> StorageClient {
    .init(
        allSyncUps: { [] },
        saveSyncUp: { _ in },
        deleteSyncUp: { syncUp in
            spy.appendDeletedSyncUp(syncUp)
        },
        saveMeetingNotes: { syncUp, meeting in
            spy.appendSavedMeetingNotes(syncUp: syncUp, meeting: meeting)
        },
        findSyncUp: { _ in nil }
    )
}
