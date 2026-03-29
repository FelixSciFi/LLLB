import AVFoundation
import Foundation
import Speech

struct RecognitionCandidate: Identifiable, Equatable {
    let id = UUID()
    let text: String
    /// 0...1 relative confidence when available.
    let confidence: Float
}

final class VoiceInputController: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var authorizationMessage: String?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var latestResult: SFSpeechRecognitionResult?
    private let resultLock = NSLock()

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.authorizationMessage = nil
                case .denied, .restricted:
                    self?.authorizationMessage = "请在设置中允许语音识别。"
                case .notDetermined:
                    self?.authorizationMessage = nil
                @unknown default:
                    self?.authorizationMessage = nil
                }
            }
        }
    }

    func beginListening() {
        guard let recognizer, recognizer.isAvailable else {
            authorizationMessage = "当前设备法语识别不可用。"
            return
        }

        cancelSession()
        latestResult = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            authorizationMessage = "无法启动麦克风。"
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            authorizationMessage = "音频引擎启动失败。"
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            self?.resultLock.lock()
            self?.latestResult = result
            self?.resultLock.unlock()
        }

        isListening = true
        authorizationMessage = nil
    }

    /// Stops capture; after a short delay (so the final hypothesis can arrive), invokes `completion` on the main queue.
    func endListeningTopCandidates(maxCount: Int, completion: @escaping ([RecognitionCandidate]) -> Void) {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        request?.endAudio()
        request = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self else {
                completion([])
                return
            }

            self.resultLock.lock()
            let result = self.latestResult
            self.latestResult = nil
            self.resultLock.unlock()

            self.task?.cancel()
            self.task = nil
            self.isListening = false

            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

            completion(Self.buildCandidates(from: result, maxCount: maxCount))
        }
    }

    private static func buildCandidates(from result: SFSpeechRecognitionResult?, maxCount: Int) -> [RecognitionCandidate] {
        guard let result else { return [] }
        let transcriptions = Array(result.transcriptions.prefix(maxCount))
        guard !transcriptions.isEmpty else { return [] }

        return transcriptions.enumerated().map { index, tr in
            let avg: Float
            if tr.segments.isEmpty {
                avg = 1.0 - Float(index) * 0.12
            } else {
                let sum = tr.segments.reduce(0.0) { $0 + $1.confidence }
                avg = Float(sum) / Float(tr.segments.count)
            }
            let confidence = max(0.2, min(1.0, avg)) * (1.0 - Float(index) * 0.08)
            return RecognitionCandidate(text: tr.formattedString, confidence: confidence)
        }
    }

    private func cancelSession() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isListening = false
    }
}
