//
//  RecordMeetingUI.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 9/8/25.
//

import SwiftUI
import ReducerArchitecture
import SwiftUIEx

extension RecordMeeting: StoreUINamespace {
    static let nextSpeakerButton = "RecordMeeting.nextSpeakerButton"
    static let endMeetingButton = "RecordMeeting.endMeetingButton"
    static let endMeetingSaveTitle = "Save and end"
    static let endMeetingDiscardTitle = "Discard"
    static let endMeetingResumeTitle = "Resume"
    static let speechFailureContinueTitle = "Continue meeting"
    static let speechFailureDiscardTitle = "Discard meeting"

    struct MeetingHeaderView: View {
        let progress: Double
        let secondsElapsed: Int
        let durationRemaining: Duration
        let theme: Theme

        var body: some View {
            VStack {
                ProgressView(value: progress)
                    .progressViewStyle(MeetingProgressViewStyle(theme: theme))
                HStack {
                    VStack(alignment: .leading) {
                        Text("Time Elapsed")
                            .font(.caption)
                        Label(
                            Duration.seconds(secondsElapsed).formatted(.units()),
                            systemImage: "hourglass.bottomhalf.fill"
                        )
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Time Remaining")
                            .font(.caption)
                        Label(durationRemaining.formatted(.units()), systemImage: "hourglass.tophalf.fill")
                            .font(.body.monospacedDigit())
                            .labelStyle(.trailingIcon)
                    }
                }
            }
            .padding([.top, .horizontal])
        }
    }

    struct MeetingProgressViewStyle: ProgressViewStyle {
        var theme: Theme

        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10.0)
                    .fill(theme.accentColor)
                    .frame(height: 20.0)

                ProgressView(configuration)
                    .tint(theme.mainColor)
                    .frame(height: 12.0)
                    .padding(.horizontal)
            }
        }
    }

    struct MeetingTimerView: View {
        let syncUp: SyncUp
        let speakerIndex: Int

        var body: some View {
            Circle()
                .strokeBorder(lineWidth: 24)
                .overlay {
                    VStack {
                        Group {
                            if speakerIndex < syncUp.attendees.count {
                                Text(syncUp.attendees[speakerIndex].name)
                            } else {
                                Text("Someone")
                            }
                        }
                        .font(.title)
                        Text("is speaking")
                        Image(systemName: "mic.fill")
                            .font(.largeTitle)
                            .padding(.top)
                    }
                    .foregroundStyle(syncUp.theme.accentColor)
                }
                .overlay {
                    ForEach(Array(syncUp.attendees.enumerated()), id: \.element.id) { index, attendee in
                        if index < speakerIndex + 1 {
                            SpeakerArc(totalSpeakers: syncUp.attendees.count, speakerIndex: index)
                                .rotation(Angle(degrees: -90))
                                .stroke(syncUp.theme.mainColor, lineWidth: 12)
                        }
                    }
                }
                .padding(.horizontal)
        }
    }

    struct SpeakerArc: Shape {
        let totalSpeakers: Int
        let speakerIndex: Int

        func path(in rect: CGRect) -> Path {
            let diameter = min(rect.size.width, rect.size.height) - 24.0
            let radius = diameter / 2.0
            let center = CGPoint(x: rect.midX, y: rect.midY)
            return Path { path in
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
            }
        }

        private var degreesPerSpeaker: Double {
            360.0 / Double(totalSpeakers)
        }
        private var startAngle: Angle {
            Angle(degrees: degreesPerSpeaker * Double(speakerIndex) + 1.0)
        }
        private var endAngle: Angle {
            Angle(degrees: startAngle.degrees + degreesPerSpeaker - 1.0)
        }
    }

    struct MeetingFooterView: View {
        let nextSpeakerText: String
        let nextButtonTapped: () -> Void

        var body: some View {
            VStack {
                HStack {
                    Text(nextSpeakerText)
                    Spacer()
                    Button(action: nextButtonTapped) {
                        Image(systemName: "forward.fill")
                    }
                    .testIdentifier(RecordMeeting.nextSpeakerButton)
                }
            }
            .padding([.bottom, .horizontal])
        }
    }

    struct ContentView: StoreContentView {
        typealias Nsp = RecordMeeting
        @ObservedObject var store: Store

        init(_ store: Store) {
            self.store = store
        }

        @State private var endMeetingAlertResult:
            CheckedContinuation<EndMeetingAlertResult, Error>? = nil
        @State private var speechRecognizerFailureAlertResult:
            CheckedContinuation<SpeechRecognizerFailureAlertResult, Error>? = nil

        @State private var showDiscardButton = false

        var syncUp: SyncUp {
            store.state.syncUp
        }

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(syncUp.theme.mainColor)

                VStack {
                    MeetingHeaderView(
                        progress: store.state.progress,
                        secondsElapsed: store.state.secondsElapsed,
                        durationRemaining: store.state.durationRemaining,
                        theme: syncUp.theme
                    )
                    MeetingTimerView(
                        syncUp: syncUp,
                        speakerIndex: store.state.speakerIndex
                    )
                    MeetingFooterView(
                        nextSpeakerText: store.state.nextSpeakerText,
                        nextButtonTapped: { store.send(.mutating(.nextSpeaker)) }
                    )
                }
            }
            .padding()
            .foregroundColor(syncUp.theme.accentColor)
            .navigationBarTitleDisplayMode(.inline)
            .taskAlert(
                "End meeting?",
                $endMeetingAlertResult,
                actions: { complete in
                    Button(Nsp.endMeetingSaveTitle) {
                        complete(.saveAndEnd)
                    }
                    if showDiscardButton {
                        Button(Nsp.endMeetingDiscardTitle, role: .destructive) {
                            complete(.discard)
                        }
                    }
                    Button(Nsp.endMeetingResumeTitle, role: .cancel) {
                        complete(.resume)
                    }
                },
                message: {
                    Text("What would you like to do?")
                }
            )
            .taskAlert(
                "Speech recognition failure",
                $speechRecognizerFailureAlertResult,
                actions: { complete in
                    Button(Nsp.speechFailureContinueTitle, role: .cancel) {
                        complete(.continue)
                    }
                    Button(Nsp.speechFailureDiscardTitle, role: .destructive) {
                        complete(.discard)
                    }
                },
                message: {
                    Text("What would you like to do?")
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End meeting") {
                        store.send(.effect(.showEndMeetingAlert(discardable: true)))
                    }
                    .testIdentifier(Nsp.endMeetingButton)
                }
            }
            .navigationBarBackButtonHidden(true)
            .connectOnAppear {
                guard store.environment == nil else { return }
                store.environment = .init(
                    showEndMeetingAlert: { discardable in
                        showDiscardButton = discardable
                        return try await withCheckedThrowingContinuation { continuation in
                            endMeetingAlertResult = continuation
                        }
                    },
                    showSpeechRecognizerFailureAlert: {
                        return try await withCheckedThrowingContinuation { continuation in
                            speechRecognizerFailureAlertResult = continuation
                        }
                    },
                    prepareSoundPlayer: Nsp.prepareSoundPlayer,
                    playNextSpeakerSound: Nsp.playNextSpeakerSound,
                    startTranscriptRecording: Nsp.startTranscriptRecording,
                    now: Nsp.now
                )

                Nsp.start(store)
            }
        }
    }
}

// Xcode creates more than one copy of recorMeeting store, which results
// in addiitonal sounds for the next speaker. The workaround is to wrap
// it in a flow so that as soon as the flow is finished, the store is cancelled.

#Preview {
    enum PreviewStartScreen: ViewModelUINamespace {
        class ViewModel: BaseViewModel<Void> {}
        struct ContentView: ViewModelContentView {
            typealias Nsp = PreviewStartScreen
            @ObservedObject var viewModel: ViewModel

            init(_ viewModel: ViewModel) {
                self.viewModel = viewModel
            }

            var body: some View {
                Button("Start") {
                    viewModel.publish(())
                }
            }
        }
    }

    @MainActor
    func start() -> RootNavigationNode<PreviewStartScreen> {
        .init(PreviewStartScreen.ViewModel())
    }

    @MainActor
    func recordMeeting(_ syncUp: SyncUp, _ proxy: NavigationProxy) -> NavigationNode<RecordMeeting> {
        .init(RecordMeeting.store(syncUp: syncUp), proxy)
    }

    return NavigationFlow(start()) { _, proxy in
        await recordMeeting(.mock, proxy).then { _, _ in
            proxy.popToRoot()
        }
    }
}
