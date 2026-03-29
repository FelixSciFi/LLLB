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
    @Published private(set) var speechAuthorized = false
    @Published private(set) var micAuthorized = false
    @Published private(set) var debugState: String = ""

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var latestResult: SFSpeechRecognitionResult?
    private let resultLock = NSLock()

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func requestAuthorization() {
        setDebugState("请求语音识别权限…")
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.speechAuthorized = (status == .authorized)
                switch status {
                case .authorized:
                    self.setDebugState("语音识别权限：已授权")
                    if self.authorizationMessage == "请在设置中允许语音识别。" {
                        self.authorizationMessage = nil
                    }
                case .denied, .restricted:
                    self.authorizationMessage = "请在设置中允许语音识别。"
                    self.setDebugState("语音识别权限：被拒绝或受限")
                case .notDetermined:
                    self.setDebugState("语音识别权限：未决定")
                @unknown default:
                    self.setDebugState("语音识别权限：未知状态")
                }
            }
        }

        requestMicrophoneAuthorization()
    }

    private func requestMicrophoneAuthorization() {
        setDebugState("请求麦克风权限…")
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.refreshRecordPermissionFlag()
                    if granted {
                        self.setDebugState("麦克风权限：已授权")
                    } else if AVAudioSession.sharedInstance().recordPermission == .denied {
                        self.authorizationMessage = "请在设置中允许麦克风，才能录音识别。"
                        self.setDebugState("麦克风权限：已拒绝")
                    } else {
                        self.setDebugState("麦克风权限：未授权")
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.refreshRecordPermissionFlag()
                    if granted {
                        self.setDebugState("麦克风权限：已授权")
                    } else if AVAudioSession.sharedInstance().recordPermission == .denied {
                        self.authorizationMessage = "请在设置中允许麦克风，才能录音识别。"
                        self.setDebugState("麦克风权限：已拒绝")
                    } else {
                        self.setDebugState("麦克风权限：未授权")
                    }
                }
            }
        }
    }

    private func refreshRecordPermissionFlag() {
        micAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func beginListening() {
        DispatchQueue.main.async {
            self.debugState = "按下：准备聆听…"
            self.beginListeningOnMain()
        }
    }

    private func beginListeningOnMain() {
        guard let recognizer, recognizer.isAvailable else {
            authorizationMessage = "当前设备法语识别不可用。"
            debugState = "recognizer 不可用"
            return
        }

        speechAuthorized = (SFSpeechRecognizer.authorizationStatus() == .authorized)
        refreshRecordPermissionFlag()

        guard speechAuthorized, micAuthorized else {
            if !speechAuthorized {
                authorizationMessage = "语音识别未授权：请在设置中允许语音识别。"
                debugState = "speech 未授权"
            } else {
                let recordPermission = AVAudioSession.sharedInstance().recordPermission
                if recordPermission == .denied {
                    authorizationMessage = "麦克风未授权：请到「设置」中开启麦克风，才能按住说话。"
                } else {
                    authorizationMessage = "麦克风权限未确定：请先响应系统弹窗允许麦克风，或到设置中开启。"
                }
                debugState = "麦克风未授权"
            }
            return
        }

        cancelSession()
        latestResult = nil
        debugState = "开始聆听…"

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            performSessionCleanup()
            authorizationMessage = "无法启动音频会话：\(error.localizedDescription)"
            debugState = "setCategory/setActive 失败"
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else {
            performSessionCleanup()
            authorizationMessage = "无法创建语音识别请求。"
            debugState = "request nil"
            return
        }
        request.shouldReportPartialResults = true
        if Self.isRunningOnSimulator {
            request.requiresOnDeviceRecognition = false
        } else {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

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
            performSessionCleanup()
            authorizationMessage = "音频引擎启动失败：\(error.localizedDescription)"
            debugState = "audioEngine.start 失败"
            return
        }

        debugState = "音频引擎已启动"

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.performSessionCleanup()
                    self.authorizationMessage = "语音识别出错：\(error.localizedDescription)"
                    self.debugState = "recognition error"
                }
                return
            }
            guard let result else { return }
            DispatchQueue.main.async {
                self.resultLock.lock()
                self.latestResult = result
                self.resultLock.unlock()
                self.debugState = result.isFinal ? "收到识别最终结果" : "收到识别中间结果"
            }
        }

        isListening = true
        authorizationMessage = nil
        debugState = "识别任务已开始"
    }

    /// Stops capture; after a short delay (so the final hypothesis can arrive), invokes `completion` on the main queue.
    func endListeningTopCandidates(maxCount: Int, completion: @escaping ([RecognitionCandidate]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            self.debugState = "结束录音，等待识别收尾…"

            self.audioEngine.inputNode.removeTap(onBus: 0)
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }

            self.request?.endAudio()
            self.request = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                self.resultLock.lock()
                let result = self.latestResult
                self.latestResult = nil
                self.resultLock.unlock()

                self.performSessionCleanup()

                self.debugState = result == nil ? "已停止（无识别结果）" : "已停止，准备返回候选"

                let cands = Self.buildCandidates(from: result, maxCount: maxCount)
                DispatchQueue.main.async {
                    completion(cands)
                }
            }
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
        performSessionCleanup()
    }

    /// 统一收尾：停止采集、结束请求、取消任务、停用会话、复位聆听状态。
    private func performSessionCleanup() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListening = false
    }

    private func setDebugState(_ text: String) {
        DispatchQueue.main.async {
            self.debugState = text
        }
    }
}
