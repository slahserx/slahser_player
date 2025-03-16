import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 主题模式枚举
enum AppThemeMode {
  light,
  dark,
  system,
}

// 主题颜色枚举
enum ThemeColor {
  green,
  blue,
  purple,
  orange,
  red,
}

// 快捷键操作枚举
enum ShortcutAction {
  playPause,
  next,
  previous,
  volumeUp,
  volumeDown,
  mute,
  toggleRepeat,
  toggleShuffle,
  showLyrics,
}

// 应用设置模型
class AppSettings {
  // 外观设置
  AppThemeMode themeMode;
  ThemeColor themeColor;
  String fontFamily;
  
  // 播放设置
  bool enableFadeEffect;
  int fadeInDuration; // 毫秒
  int fadeOutDuration; // 毫秒
  double volume; // 音量 0.0-1.0
  bool isMuted; // 是否静音
  
  // 快捷键设置
  Map<ShortcutAction, HotKey> shortcuts;
  
  AppSettings({
    this.themeMode = AppThemeMode.system,
    this.themeColor = ThemeColor.green,
    this.fontFamily = '微软雅黑',
    this.enableFadeEffect = true,
    this.fadeInDuration = 500,
    this.fadeOutDuration = 500,
    this.volume = 1.0,
    this.isMuted = false,
    Map<ShortcutAction, HotKey>? shortcuts,
  }) : shortcuts = shortcuts ?? _defaultShortcuts();
  
  // 默认快捷键设置
  static Map<ShortcutAction, HotKey> _defaultShortcuts() {
    return {
      ShortcutAction.playPause: HotKey(LogicalKeyboardKey.space),
      ShortcutAction.next: HotKey(LogicalKeyboardKey.arrowRight, ctrl: true),
      ShortcutAction.previous: HotKey(LogicalKeyboardKey.arrowLeft, ctrl: true),
      ShortcutAction.volumeUp: HotKey(LogicalKeyboardKey.arrowUp, ctrl: true),
      ShortcutAction.volumeDown: HotKey(LogicalKeyboardKey.arrowDown, ctrl: true),
      ShortcutAction.mute: HotKey(LogicalKeyboardKey.keyM, ctrl: true),
      ShortcutAction.toggleRepeat: HotKey(LogicalKeyboardKey.keyR, ctrl: true),
      ShortcutAction.toggleShuffle: HotKey(LogicalKeyboardKey.keyS, ctrl: true),
      ShortcutAction.showLyrics: HotKey(LogicalKeyboardKey.keyL, ctrl: true),
    };
  }
  
  // 从JSON创建设置
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.values[json['themeMode'] ?? 2],
      themeColor: ThemeColor.values[json['themeColor'] ?? 0],
      fontFamily: json['fontFamily'] ?? '微软雅黑',
      enableFadeEffect: json['enableFadeEffect'] ?? true,
      fadeInDuration: json['fadeInDuration'] ?? 500,
      fadeOutDuration: json['fadeOutDuration'] ?? 500,
      volume: json['volume'] ?? 1.0,
      isMuted: json['isMuted'] ?? false,
      shortcuts: (json['shortcuts'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(
          ShortcutAction.values.firstWhere(
            (e) => e.toString() == key,
            orElse: () => ShortcutAction.playPause,
          ),
          HotKey.fromJson(value),
        ),
      ) ?? _defaultShortcuts(),
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'themeColor': themeColor.index,
      'fontFamily': fontFamily,
      'enableFadeEffect': enableFadeEffect,
      'fadeInDuration': fadeInDuration,
      'fadeOutDuration': fadeOutDuration,
      'volume': volume,
      'isMuted': isMuted,
      'shortcuts': shortcuts.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      ),
    };
  }
  
  // 复制并修改设置
  AppSettings copyWith({
    AppThemeMode? themeMode,
    ThemeColor? themeColor,
    String? fontFamily,
    bool? enableFadeEffect,
    int? fadeInDuration,
    int? fadeOutDuration,
    double? volume,
    bool? isMuted,
    Map<ShortcutAction, HotKey>? shortcuts,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      fontFamily: fontFamily ?? this.fontFamily,
      enableFadeEffect: enableFadeEffect ?? this.enableFadeEffect,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      shortcuts: shortcuts ?? Map.from(this.shortcuts),
    );
  }
}

// 热键模型
class HotKey {
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool alt;
  final bool shift;
  
  HotKey(
    this.key, {
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });
  
  // 从JSON创建热键
  factory HotKey.fromJson(Map<String, dynamic> json) {
    return HotKey(
      LogicalKeyboardKey(json['key']),
      ctrl: json['ctrl'] ?? false,
      alt: json['alt'] ?? false,
      shift: json['shift'] ?? false,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key.keyId,
      'ctrl': ctrl,
      'alt': alt,
      'shift': shift,
    };
  }
  
  // 获取热键的显示文本
  String get displayText {
    final List<String> parts = [];
    if (ctrl) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    
    String keyName = key.keyLabel;
    if (keyName.isEmpty) {
      // 处理特殊按键
      if (key == LogicalKeyboardKey.space) {
        keyName = 'Space';
      } else if (key == LogicalKeyboardKey.arrowUp) {
        keyName = '↑';
      } else if (key == LogicalKeyboardKey.arrowDown) {
        keyName = '↓';
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        keyName = '←';
      } else if (key == LogicalKeyboardKey.arrowRight) {
        keyName = '→';
      } else {
        // 尝试从keyId获取名称
        keyName = key.debugName?.split('.').last ?? 'Unknown';
      }
    }
    
    parts.add(keyName);
    return parts.join(' + ');
  }
  
  @override
  String toString() => displayText;
} 