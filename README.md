# SyncUpsTRA

This is an example of TRA in action. Point-Free took Apple's Scrumdinger application and implemented a similar app, called SyncUps, using their tools. This is another implementation of SyncUps using [TRA](https://github.com/ilyathewhite/ReducerArchitecture).

## Some Higlights

- The app implements each screen using a store/reducer/view triplet, ogranized into groups.
- Most of the logic of each screen is captured in the reducer.
- The environment for the reducer is setup in the UI that has the most context for the implementation.
- The app uses mutating actions only when actually changing state. In the example below, the reducer implementation for `.editSyncUp` effect action is to run the effect (using the environment) to get the edits from the user and then to send the edits to the store as a mutating action.
```Swift
    effect: { env, state, action in
        switch action {
        case .editSyncUp(let syncUp):
            return .asyncAction {
                if let syncUp = await env.edit(syncUp) {
                    return .mutating(.update(syncUp))
                }
                else {
                    return .none
                }
            }
        ...
```
- The app encodes navigation using Swift concurrency:
```Swift
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
```
- Sheets and alerts are effects that are implemented using Swift concurrency as well.
