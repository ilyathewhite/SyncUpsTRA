import AVFoundation

struct SoundEffectClient {
    var load: @MainActor (_ fileName: String) -> Void
    var play: @MainActor () -> Void
}

extension SoundEffectClient {
    @MainActor
    static func load(_ fileName: String) {
        Player.shared.load(fileName: fileName)
    }

    @MainActor
    static func play() {
        Player.shared.play()
    }

    static let liveValue = Self(
        load: Self.load,
        play: Self.play
    )
}

@MainActor
private final class Player {
    static let shared = Player()
    private let player = AVPlayer()

    func load(fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "")
        else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func play() {
        player.seek(to: .zero)
        player.play()
    }

    required init() {}
}
