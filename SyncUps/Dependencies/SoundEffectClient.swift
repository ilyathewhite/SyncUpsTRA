import AVFoundation

struct SoundEffectClient {
    var load: (_ fileName: String) -> Void
    var play: () -> Void

    init() {
        let player = Player()
        self.load = player.load
        self.play = player.play
    }
}

private final class Player {
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
