import 'package:flutter/material.dart';

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
  custom, // 添加自定义颜色选项
}

// 应用设置模型
class AppSettings {
  // 外观设置
  AppThemeMode themeMode;
  ThemeColor themeColor;
  String fontFamily;
  int customColor; // 自定义颜色的ARGB值
  
  // 播放设置
  bool enableFadeEffect;
  int fadeInDuration; // 毫秒
  int fadeOutDuration; // 毫秒
  double volume; // 音量 0.0-1.0
  bool isMuted; // 是否静音
  
  // 云音乐设置
  bool enableCloudMusicPreBuffer; // 是否启用云音乐预缓冲
  int preBufferCloudCount; // 预缓冲数量
  String cloudMusicDownloadPath; // 云音乐下载路径
  
  AppSettings({
    this.themeMode = AppThemeMode.system,
    this.themeColor = ThemeColor.green,
    this.fontFamily = '微软雅黑',
    this.customColor = 0xFF1DB954, // 默认使用绿色作为自定义颜色的初始值
    this.enableFadeEffect = true,
    this.fadeInDuration = 500,
    this.fadeOutDuration = 500,
    this.volume = 1.0,
    this.isMuted = false,
    this.enableCloudMusicPreBuffer = true,
    this.preBufferCloudCount = 2,
    this.cloudMusicDownloadPath = '', // 默认为空，表示使用默认临时目录
  });
  
  // 从JSON创建设置
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.values[json['themeMode'] ?? 2],
      themeColor: ThemeColor.values[json['themeColor'] ?? 0],
      fontFamily: json['fontFamily'] ?? '微软雅黑',
      customColor: json['customColor'] ?? 0xFF1DB954,
      enableFadeEffect: json['enableFadeEffect'] ?? true,
      fadeInDuration: json['fadeInDuration'] ?? 500,
      fadeOutDuration: json['fadeOutDuration'] ?? 500,
      volume: json['volume'] ?? 1.0,
      isMuted: json['isMuted'] ?? false,
      enableCloudMusicPreBuffer: json['enableCloudMusicPreBuffer'] ?? true,
      preBufferCloudCount: json['preBufferCloudCount'] ?? 2,
      cloudMusicDownloadPath: json['cloudMusicDownloadPath'] ?? '',
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'themeColor': themeColor.index,
      'fontFamily': fontFamily,
      'customColor': customColor,
      'enableFadeEffect': enableFadeEffect,
      'fadeInDuration': fadeInDuration,
      'fadeOutDuration': fadeOutDuration,
      'volume': volume,
      'isMuted': isMuted,
      'enableCloudMusicPreBuffer': enableCloudMusicPreBuffer,
      'preBufferCloudCount': preBufferCloudCount,
      'cloudMusicDownloadPath': cloudMusicDownloadPath,
    };
  }
  
  // 复制并修改设置
  AppSettings copyWith({
    AppThemeMode? themeMode,
    ThemeColor? themeColor,
    String? fontFamily,
    int? customColor,
    bool? enableFadeEffect,
    int? fadeInDuration,
    int? fadeOutDuration,
    double? volume,
    bool? isMuted,
    bool? enableCloudMusicPreBuffer,
    int? preBufferCloudCount,
    String? cloudMusicDownloadPath,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      fontFamily: fontFamily ?? this.fontFamily,
      customColor: customColor ?? this.customColor,
      enableFadeEffect: enableFadeEffect ?? this.enableFadeEffect,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      enableCloudMusicPreBuffer: enableCloudMusicPreBuffer ?? this.enableCloudMusicPreBuffer,
      preBufferCloudCount: preBufferCloudCount ?? this.preBufferCloudCount,
      cloudMusicDownloadPath: cloudMusicDownloadPath ?? this.cloudMusicDownloadPath,
    );
  }
} 