/**
 * [INPUT]: 依赖 SwiftUI 框架, AppState, AudioEngine
 * [OUTPUT]: 对外提供 RecordingIndicatorManager 单例，管理录音指示器窗口
 * [POS]: VoiceFlow 的录音状态指示器，被 HotkeyMonitor 触发
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import SwiftUI
import AppKit

// ========================================
// MARK: - Recording Indicator Manager
// ========================================

@MainActor
final class RecordingIndicatorManager: ObservableObject {

    static let shared = RecordingIndicatorManager()

    @Published var audioLevel: Float = 0.0
    @Published var status: IndicatorStatus = .hidden
    @Published var recordingTime: Int = 0

    enum IndicatorStatus {
        case hidden
        case recording
        case processing
        case cancelled
    }

    private var panel: NSPanel?
    private var hostingView: NSHostingView<RootIndicatorView>?

    private init() {}

    func updateAudioLevel(_ level: Float) {
        audioLevel = level
    }

    func showRecording() {
        status = .recording
        show()
    }

    func showProcessing() {
        status = .processing
        if panel == nil { show() }
    }

    func showCancelled() {
        status = .cancelled
        if panel == nil { show() }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if self.status == .cancelled {
                self.hide()
            }
        }
    }

    func hide() {
        status = .hidden
        audioLevel = 0.0

        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    func performCancel() {
        RecordingCoordinator.shared.cancelRecording()
        showCancelled()
    }

    private func show() {
        if panel != nil { return }

        let panelWidth: CGFloat = 140
        let panelHeight: CGFloat = 48

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = false
        panel.ignoresMouseEvents = false

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = (screenFrame.width - panelWidth) / 2 + screenFrame.origin.x
            let y = screenFrame.origin.y + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let rootView = RootIndicatorView()
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        panel.orderFrontRegardless()
    }
}

// ========================================
// MARK: - Root Indicator View
// ========================================

struct RootIndicatorView: View {
    @ObservedObject var manager = RecordingIndicatorManager.shared

    var body: some View {
        ZStack {
            switch manager.status {
            case .recording:
                RecordingCapsule()
            case .processing:
                ProcessingCapsule()
            case .cancelled:
                CancelledCapsule()
            case .hidden:
                EmptyView()
            }
        }
        .frame(width: 140, height: 48)
        .background(Color.clear)
    }
}

// ========================================
// MARK: - Recording Capsule
// ========================================

struct RecordingCapsule: View {
    @ObservedObject var manager = RecordingIndicatorManager.shared
    @State private var barHeights: [CGFloat] = Array(repeating: 3, count: 8)
    @State private var timer: Timer?
    @State private var animationTimer: Timer?

    private let colors: [Color] = [
        Color(hex: "ec4899"), Color(hex: "f472b6"), Color(hex: "d946ef"), Color(hex: "a855f7"),
        Color(hex: "8b5cf6"), Color(hex: "3b82f6"), Color(hex: "38bdf8"), Color(hex: "22d3ee")
    ]

    var body: some View {
        Capsule()
            .fill(Color.black.opacity(0.92))
            .overlay(
                HStack(spacing: 0) {
                    // 时间 - 使用 manager 的时间
                    Text(String(format: "%02d:%02d", manager.recordingTime / 60, manager.recordingTime % 60))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, alignment: .leading)

                    // 波形
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { i in
                            Group {
                                if barHeights[i] <= 4 {
                                    Circle()
                                        .fill(colors[i])
                                        .frame(width: 3, height: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(colors[i])
                                        .frame(width: 3, height: barHeights[i])
                                        .shadow(color: colors[i].opacity(0.6), radius: 2)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // 取消按钮
                    Button {
                        manager.performCancel()
                    } label: {
                        ZStack {
                            Circle().fill(.white.opacity(0.1))
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36)
                }
                .padding(.horizontal, 10)
            )
            .onAppear {
                barHeights = Array(repeating: 3, count: 8)
                startTimers()
            }
            .onDisappear {
                stopTimers()
            }
    }

    private func startTimers() {
        manager.recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in manager.recordingTime += 1 }
        }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            Task { @MainActor in updateBars() }
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        animationTimer?.invalidate()
        timer = nil
        animationTimer = nil
    }

    private func updateBars() {
        let level = CGFloat(manager.audioLevel)

        // 没声音 = 小圆点
        guard level > 0.001 else {
            barHeights = Array(repeating: 3, count: 8)
            return
        }

        // 有声音 = 柱状，大幅放大让波动更剧烈
        let t = CACurrentMediaTime()
        for i in 0..<8 {
            let wave = sin(t * 10 + Double(i) * 0.9)
            let rand = CGFloat.random(in: 0.6...1.0)
            // 放大系数提升到 800，让波动更大
            let boost = level * 800 * rand * CGFloat(wave * 0.5 + 0.5)
            barHeights[i] = max(3, min(40, 3 + boost))
        }
    }
}

// ========================================
// MARK: - Processing Capsule
// ========================================

struct ProcessingCapsule: View {
    @State private var isAnimating = false
    @State private var processingTime: Int = 0
    @State private var timer: Timer?

    var body: some View {
        Capsule()
            .fill(Color.black.opacity(0.92))
            .overlay(
                HStack(spacing: 0) {
                    // 独立计时
                    Text(String(format: "%02d:%02d", processingTime / 60, processingTime % 60))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, alignment: .leading)

                    Text("Thinking...")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)

                    ZStack {
                        Circle()
                            .stroke(Color(hex: "c084fc").opacity(0.3), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color(hex: "c084fc"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(isAnimating ? 360 : 0))
                            .shadow(color: Color(hex: "c084fc").opacity(0.8), radius: 3)
                    }
                    .frame(width: 14, height: 14)
                    .frame(width: 36)
                }
                .padding(.horizontal, 10)
            )
            .onAppear {
                processingTime = 0
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    Task { @MainActor in processingTime += 1 }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

// ========================================
// MARK: - Cancelled Capsule
// ========================================

struct CancelledCapsule: View {
    var body: some View {
        Capsule()
            .fill(Color.black.opacity(0.92))
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Text("已取消")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            )
    }
}

// ========================================
// MARK: - Color Extension
// ========================================

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// ========================================
// MARK: - Preview
// ========================================

#Preview("Recording") {
    RecordingCapsule()
        .frame(width: 140, height: 48)
        .padding()
        .background(Color.gray)
}

#Preview("Processing") {
    ProcessingCapsule()
        .frame(width: 140, height: 48)
        .padding()
        .background(Color.gray)
}

#Preview("Cancelled") {
    CancelledCapsule()
        .frame(width: 140, height: 48)
        .padding()
        .background(Color.gray)
}
