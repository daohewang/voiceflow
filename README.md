<div align="center">

# VoiceFlow

**macOS 语音输入增强工具 — 让打字如说话般自然**

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://developer.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[English](#english) · [中文](#中文)

</div>

---

<a name="中文"></a>

## 概述

VoiceFlow 是一款专为 macOS 设计的语音输入增强工具。通过全局快捷键唤起录音，实时语音转文字，可选 AI 润色，最终将文字自动注入到当前光标位置——整个过程无需切换应用，无需手动粘贴。

### 核心特性

| 特性 | 说明 |
|------|------|
| 🎤 **实时语音识别** | 基于 ElevenLabs Realtime STT，低延迟流式转录 |
| ✨ **AI 文本润色** | 支持 OpenRouter 接入多种 LLM，智能优化表达 |
| ⌨️ **全局快捷键** | 自定义快捷键唤起，默认 `⌘⇧V` |
| 💉 **无缝文本注入** | 自动将文字粘贴到光标位置，恢复原剪贴板内容 |
| 🎨 **悬浮胶囊 UI** | 音频波形可视化，状态一目了然 |
| 🔒 **隐私优先** | API Key 安全存储于 Keychain，不上传云端 |

## 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│                        VoiceFlow                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   快捷键 ──► 录音 ──► ASR 转录 ──► LLM 润色 ──► 文本注入    │
│     │        │         │           │           │            │
│     │        ▼         ▼           ▼           ▼            │
│     │    ┌───────┐ ┌───────┐ ┌─────────┐ ┌─────────┐        │
│     └───►│ 波形  │ │ 实时  │ │ 智能    │ │ 光标    │        │
│          │ 动画  │ │ 字幕  │ │ 润色    │ │ 输入    │        │
│          └───────┘ └───────┘ └─────────┘ └─────────┘        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 快速开始

### 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 16.0+ (仅开发时需要)

### 安装

```bash
# 克隆仓库
git clone https://github.com/daohewang/voiceflow.git
cd voiceflow

# 构建
swift build -c release

# 运行
.build/release/VoiceFlow
```

### 配置

首次运行后，点击菜单栏图标进入设置：

1. **配置 ElevenLabs API Key** — 用于语音识别
2. **配置 OpenRouter API Key** (可选) — 用于文本润色
3. **设置快捷键** — 默认 `⌘⇧V`，可自定义
4. **授予权限** — 麦克风、辅助功能、快捷键监听

## 使用方式

1. 按下快捷键 `⌘⇧V` 开始录音
2. 说话 → 屏幕底部显示悬浮胶囊，波形随声音跳动
3. 再次按下快捷键结束录音
4. 等待处理 → 文字自动注入到光标位置

### 录音状态

| 状态 | 说明 |
|------|------|
| 🔴 录音中 | 波形随音量实时跳动，左侧显示时长 |
| 🟣 处理中 | 显示 "Thinking..." + 旋转加载动画 |
| ⚪ 已取消 | 点击取消按钮后显示，1.5s 后自动消失 |

## 项目结构

```
VoiceFlow/
├── App/
│   ├── VoiceFlowApp.swift      # 应用入口，菜单栏生命周期
│   └── AppState.swift          # 全局状态管理
├── Core/
│   ├── AudioEngine.swift       # 音频采集，RMS 音量计算
│   ├── ASRClient.swift         # ElevenLabs Realtime STT 客户端
│   ├── LLMClient.swift         # OpenRouter LLM 客户端
│   ├── TextInjector.swift      # 文本注入，剪贴板恢复
│   ├── HotkeyMonitor.swift     # 全局快捷键监听
│   └── RecordingCoordinator.swift  # 录音流程协调器
├── UI/
│   ├── RecordingIndicator.swift    # 悬浮胶囊 UI
│   ├── SettingsView.swift          # 设置界面
│   └── MenuBarView.swift           # 菜单栏下拉视图
└── Models/
    ├── HotkeyConfig.swift      # 快捷键配置模型
    └── StyleTemplate.swift     # 润色风格模板
```

## 技术实现

### 音频处理链

```
麦克风 (44.1kHz Stereo) → AVAudioEngine → 重采样 (16kHz Mono)
                                              ↓
                                    RMS 音量计算 → 波形动画
                                              ↓
                                    PCM 数据 → ASR WebSocket
```

### 文本注入机制

1. 保存当前剪贴板内容
2. 将目标文本写入剪贴板
3. 模拟 `⌘V` 按键事件
4. 检测剪贴板变化，智能恢复原内容

### 并发模型

- `@MainActor` + `@Observable` 管理主线程状态
- `AsyncStream` 处理 WebSocket 消息流
- `NSLock` 保护音频缓冲区线程安全

## 配置项

| 配置 | 说明 | 默认值 |
|------|------|--------|
| 快捷键 | 唤起/结束录音 | `⌘⇧V` |
| 润色风格 | AI 润色风格模板 | `default` |
| API Keys | ElevenLabs / OpenRouter | - |

## 常见问题

<details>
<summary><b>为什么需要辅助功能权限？</b></summary>

辅助功能权限用于模拟 `⌘V` 按键事件，将文本注入到目标应用。VoiceFlow 不会监控或记录您的任何操作。
</details>

<details>
<summary><b>支持哪些语言？</b></summary>

ASR 支持ElevenLabs Realtime STT 支持的所有语言，包括中文、英语、日语等。LLM 润色会保持原始语言。
</details>

<details>
<summary><b>剪贴板内容会丢失吗？</b></summary>

不会。VoiceFlow 会在注入后智能检测剪贴板状态，如果目标应用没有修改剪贴板，会自动恢复原始内容。
</details>

## 贡献

欢迎提交 Issue 和 Pull Request。

## 许可证

[MIT License](LICENSE)

---

<a name="english"></a>

## Overview

VoiceFlow is a macOS voice input enhancement tool. Trigger recording via global hotkey, real-time speech-to-text, optional AI polish, and automatic text injection at cursor position—all without switching apps or manual pasting.

### Key Features

| Feature | Description |
|---------|-------------|
| 🎤 **Real-time ASR** | Powered by ElevenLabs Realtime STT, low-latency streaming transcription |
| ✨ **AI Polish** | OpenRouter integration for various LLMs, intelligent text optimization |
| ⌨️ **Global Hotkey** | Customizable hotkey, default `⌘⇧V` |
| 💉 **Seamless Injection** | Auto-paste text at cursor, restore original clipboard |
| 🎨 **Floating Capsule UI** | Audio waveform visualization, status at a glance |
| 🔒 **Privacy First** | API Keys stored securely in Keychain |

## Quick Start

```bash
git clone https://github.com/daohewang/voiceflow.git
cd voiceflow
swift build -c release
.build/release/VoiceFlow
```

## License

[MIT License](LICENSE)

---

<div align="center">

Made with ❤️ by [daohewang](https://github.com/daohewang)

</div>
