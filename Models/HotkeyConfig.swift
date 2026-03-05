/**
 * [INPUT]: 依赖 Foundation 框架
 * [OUTPUT]: 对外提供 HotkeyConfig 数据结构
 * [POS]: VoiceFlow 的快捷键配置模型，被 AppState 和 HotkeyMonitor 使用
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */

import Foundation
import ApplicationServices
import Carbon

// ========================================
// MARK: - Hotkey Config
// ========================================

struct HotkeyConfig: Codable, Equatable {

    // ----------------------------------------
    // MARK: - Properties
    // ----------------------------------------

    /// 按键码 (CGKeyCode)
    let keyCode: Int

    /// 修饰键 (CGEventFlags 的原始值)
    let modifiers: UInt64

    // ----------------------------------------
    // MARK: - Computed Properties
    // ----------------------------------------

    /// 获取 CGKeyCode
    var cgKeyCode: CGKeyCode {
        return CGKeyCode(keyCode)
    }

    /// 获取 CGEventFlags
    var cgEventFlags: CGEventFlags {
        return CGEventFlags(rawValue: modifiers)
    }

    /// 显示文本 (如 "⌘⇧V")
    var displayString: String {
        var parts: [String] = []

        let flags = cgEventFlags
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }

        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    // ----------------------------------------
    // MARK: - Initialization
    // ----------------------------------------

    init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.keyCode = Int(keyCode)
        self.modifiers = modifiers.rawValue
    }

    // ----------------------------------------
    // MARK: - Defaults
    // ----------------------------------------

    /// 默认快捷键: Cmd + Shift + V
    static let `default` = HotkeyConfig(
        keyCode: 9,  // V
        modifiers: [.maskCommand, .maskShift]
    )

    // ----------------------------------------
    // MARK: - Helpers
    // ----------------------------------------

    /// 按键码转字符串
    private func keyCodeToString(_ code: Int) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "PgDn"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "?"
        }
    }
}
