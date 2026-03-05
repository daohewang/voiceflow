/**
 * [INPUT]: 依赖 AVFoundation (麦克风)、Application Services (Accessibility)
 * [OUTPUT]: 对外提供 PermissionManager 单例，检查/请求麦克风和辅助功能权限
 * [POS]: VoiceFlow 的权限中枢，被 AppState 和启动流程调用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import AVFoundation
import ApplicationServices

// ========================================
// MARK: - Permission Manager
// ========================================

@MainActor
@Observable
final class PermissionManager {

    // ----------------------------------------
    // MARK: - Singleton
    // ----------------------------------------

    static let shared = PermissionManager()

    // ----------------------------------------
    // MARK: - Permission Status
    // ----------------------------------------

    private(set) var microphoneStatus: PermissionStatus = .notDetermined
    private(set) var accessibilityStatus: PermissionStatus = .notDetermined

    enum PermissionStatus: Equatable {
        case notDetermined
        case granted
        case denied
    }

    // ----------------------------------------
    // MARK: - Computed Properties
    // ----------------------------------------

    var allGranted: Bool {
        microphoneStatus == .granted && accessibilityStatus == .granted
    }

    var needsGuidance: Bool {
        microphoneStatus == .denied || accessibilityStatus == .denied
    }

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    private init() {
        refreshStatus()
    }

    // ----------------------------------------
    // MARK: - Public API
    // ----------------------------------------

    /// 刷新所有权限状态
    func refreshStatus() {
        refreshMicrophoneStatus()
        refreshAccessibilityStatus()
    }

    /// 请求麦克风权限 (macOS 使用 AVCaptureDevice)
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphoneStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// 请求辅助功能权限 (需用户手动在系统设置中授权)
    nonisolated func requestAccessibilityPermission() -> Bool {
        // 使用字符串常量避免 concurrency-safety 警告
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.async { [weak self] in
            self?.accessibilityStatus = granted ? .granted : .denied
        }

        return granted
    }

    /// 打开系统偏好设置的辅助功能页面
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 打开系统偏好设置的麦克风隐私页面
    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    // ----------------------------------------
    // MARK: - Private Helpers
    // ----------------------------------------

    private func refreshMicrophoneStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            microphoneStatus = .granted
        case .denied:
            microphoneStatus = .denied
        case .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }

    private func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatus = trusted ? .granted : .denied
    }
}

// ========================================
// MARK: - Permission Guidance View
// ========================================

import SwiftUI

/// 权限引导视图 - 当权限未授权时显示
struct PermissionGuidanceView: View {
    @Environment(PermissionManager.self) private var permissionManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("需要授权以下权限")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "麦克风",
                    status: permissionManager.microphoneStatus,
                    action: { await requestMicrophone() }
                )

                Divider()

                permissionRow(
                    icon: "keyboard.fill",
                    title: "辅助功能",
                    status: permissionManager.accessibilityStatus,
                    action: { _ = permissionManager.requestAccessibilityPermission() }
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(width: 320)
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        status: PermissionManager.PermissionStatus,
        action: @escaping () async -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(status == .granted ? .green : .secondary)

            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            statusBadge(status, action: action)
        }
    }

    @ViewBuilder
    private func statusBadge(
        _ status: PermissionManager.PermissionStatus,
        action: @escaping () async -> Void
    ) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .denied:
            Button("打开设置") {
                if permissionManager.microphoneStatus == .denied {
                    permissionManager.openMicrophonePreferences()
                } else {
                    permissionManager.openAccessibilityPreferences()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .notDetermined:
            AsyncButton(title: "授权") {
                await action()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private func requestMicrophone() async {
        _ = await permissionManager.requestMicrophonePermission()
    }
}

// ========================================
// MARK: - Async Button Helper
// ========================================

struct AsyncButton: View {
    let title: String
    let action: () async -> Void

    @State private var isProcessing = false

    var body: some View {
        Button {
            isProcessing = true
            Task {
                await action()
                isProcessing = false
            }
        } label: {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(title)
            }
        }
        .disabled(isProcessing)
    }
}

#Preview {
    PermissionGuidanceView()
        .environment(PermissionManager.shared)
}
