import AVFoundation

final class VoiceGuide {
    static let shared = VoiceGuide()

    private let synth = AVSpeechSynthesizer()
    private var didPrepare = false

    private init() {}

    /// ✅ 先に一度だけ呼ぶ（音が出ない/遅延する対策）
    /// - 例: カメラ画面の onAppear / シーケンス開始直前
    func prepareIfNeeded() {
        guard !didPrepare else { return }
        didPrepare = true

        // 音声ガイドは「マナーモードでも鳴ってほしい」前提なら .playback が安定
        // 他アプリ音声と共存したければ mixWithOthers を付ける
        let session = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 10.0, *) {
                // spokenAudio は読み上げに向く
                try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            } else {
                try session.setCategory(.playback)
            }
            try session.setActive(true)
        } catch {
            print("DEBUG: ❌ VoiceGuide prepare audio session failed: \(error)")
        }

        // “初回だけ無音/遅延” を減らすためのウォームアップ（無音で一瞬だけ）
        // ※ stopSpeaking されないよう interrupt=false
        speak(" ", interrupt: false, volume: 0.0)
    }

    func speak(_ text: String, interrupt: Bool = true) {
        speak(text, interrupt: interrupt, volume: 1.0)
    }

    // 内部：音量指定できるようにしてウォームアップに使う
    private func speak(_ text: String, interrupt: Bool, volume: Float) {
        // まだ prepare していなければ自動で呼ぶ（呼び忘れ防止）
        prepareIfNeeded()

        if interrupt, synth.isSpeaking {
            synth.stopSpeaking(at: .word)
        }

        let utt = AVSpeechUtterance(string: text)

        // 言語（“人間っぽさ”は端末依存。Siriっぽいのがあれば優先）
        utt.voice = bestJapaneseVoice()

        // 人間っぽさ調整（必要なら微調整）
        utt.rate = 0.48
        utt.pitchMultiplier = 1.0
        utt.preUtteranceDelay = 0.08
        utt.postUtteranceDelay = 0.05

        utt.volume = volume

        synth.speak(utt)
    }

    private func bestJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }

        // “Siri系” があれば優先（端末/OSで無いこともあります）
        if let siriLike = voices.first(where: { $0.identifier.lowercased().contains("siri") }) {
            return siriLike
        }

        // それ以外は標準 ja-JP
        return AVSpeechSynthesisVoice(language: "ja-JP")
    }
}
