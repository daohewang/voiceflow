/**
 * [INPUT]: 依赖 AVFoundation 的 AVAudioEngine/AVAudioConverter
 * [OUTPUT]: 对外提供 AudioEngine 类，音频采集 + 格式转换 + 回调
 * [POS]: VoiceFlow/Core 的音频层，被 ASRClient 消费
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
@preconcurrency import AVFoundation

// ========================================
// MARK: - Audio Engine
// ========================================

/// 音频采集引擎
/// 职责：麦克风输入采集 → 格式转换 → PCM 数据回调
/// 输入：44.1kHz stereo (系统默认)
/// 输出：16kHz / 16-bit / mono PCM，每 100ms 回调一次
final class AudioEngine: @unchecked Sendable {

    // ----------------------------------------
    // MARK: - Configuration
    // ----------------------------------------

    /// 目标音频格式：16kHz / 16-bit / Mono PCM
    static let targetFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    /// 回调间隔 (ms)
    static let callbackInterval: TimeInterval = 0.1  // 100ms

    // ----------------------------------------
    // MARK: - Properties
    // ----------------------------------------

    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?

    /// 音频数据回调
    var onAudioData: ((Data) -> Void)?

    /// 是否正在录音
    private(set) var isRecording = false

    // ----------------------------------------
    // MARK: - Buffer Management
    // ----------------------------------------

    /// 累积缓冲区 (用于 100ms 批量回调)
    private var accumulatedBuffer: Data = Data()
    private let bufferLock = NSLock()

    /// 每次回调的目标字节数 (16kHz * 16bit * mono * 0.1s = 3200 bytes)
    private let targetBytesPerCallback = Int(16000 * 2 * 1 * 0.1)

    // ----------------------------------------
    // MARK: - Lifecycle
    // ----------------------------------------

    init() {
        // macOS 不需要 AVAudioSession 配置
    }

    deinit {
        stopRecording()
    }

    // ----------------------------------------
    // MARK: - Recording Control
    // ----------------------------------------

    /// 开始录音
    func startRecording() throws {
        guard !isRecording else { return }

        // 创建新 engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // 创建转换器
        let targetFormat = Self.targetFormat

        guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.invalidFormat
        }
        newConverter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
        newConverter.sampleRateConverterQuality = AVAudioQuality.medium.rawValue

        // 安装 tap - 使用 nonisolated 闭包
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self = self,
                  let converter = self.converter else { return }
            self.processBuffer(buffer, converter: converter)
        }

        // 启动 engine
        try engine.start()

        // 保存引用
        self.engine = engine
        self.converter = newConverter
        self.isRecording = true

        print("[AudioEngine] Recording started - Input: \(inputFormat.sampleRate)Hz, Output: 16kHz/16bit/mono")
    }

    /// 停止录音
    func stopRecording() {
        guard isRecording, let engine = engine else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        self.engine = nil
        self.converter = nil
        self.isRecording = false

        // 刷新剩余缓冲
        flushBuffer()

        print("[AudioEngine] Recording stopped")
    }

    // ----------------------------------------
    // MARK: - Audio Processing
    // ----------------------------------------

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let targetFormat = Self.targetFormat

        // 计算目标帧数
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        // 创建输出缓冲
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: targetFrameCount
        ) else {
            return
        }

        // 执行转换
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if buffer.frameLength == 0 {
                outStatus.pointee = .endOfStream
                return nil
            }
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("[AudioEngine] Conversion error: \(error)")
            return
        }

        // 提取 PCM 数据
        guard let channelData = outputBuffer.int16ChannelData else { return }
        let byteCount = Int(outputBuffer.frameLength) * 2  // 16-bit = 2 bytes

        // 复制数据 (线程安全)
        let data = Data(bytes: channelData[0], count: byteCount)

        // 累积到缓冲区
        appendToBuffer(data)
    }

    // ----------------------------------------
    // MARK: - Buffer Accumulation
    // ----------------------------------------

    private func appendToBuffer(_ data: Data) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        accumulatedBuffer.append(data)

        // 达到目标大小时触发回调
        while accumulatedBuffer.count >= targetBytesPerCallback {
            let chunk = accumulatedBuffer.prefix(targetBytesPerCallback)
            accumulatedBuffer = accumulatedBuffer.dropFirst(targetBytesPerCallback)

            // 回调
            onAudioData?(Data(chunk))
        }
    }

    private func flushBuffer() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        if !accumulatedBuffer.isEmpty {
            onAudioData?(accumulatedBuffer)
            accumulatedBuffer.removeAll()
        }
    }
}

// ========================================
// MARK: - Error Types
// ========================================

enum AudioError: LocalizedError {
    case invalidFormat
    case engineStartFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format configuration"
        case .engineStartFailed:
            return "Failed to start audio engine"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
