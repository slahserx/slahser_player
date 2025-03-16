import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:slahser_player/services/audio_player_service.dart';

class SettingsService extends ChangeNotifier {
  static const String _settingsFileName = 'settings.json';
  
  // 当前设置
  AppSettings _settings = AppSettings(
    fontFamily: '微软雅黑',
  );
  AppSettings get settings => _settings;
  
  // 可用字体列表
  List<String> _availableFonts = ['.SF Pro Display', 'Arial', 'Roboto', 'Times New Roman'];
  List<String> get availableFonts => _availableFonts;
  
  // 主题颜色映射
  static final Map<ThemeColor, Color> themeColorMap = {
    ThemeColor.green: const Color(0xFF1DB954), // Spotify 绿色
    ThemeColor.blue: const Color(0xFF2196F3),
    ThemeColor.purple: const Color(0xFF9C27B0),
    ThemeColor.orange: const Color(0xFFFF9800),
    ThemeColor.red: const Color(0xFFF44336),
  };
  
  // 获取当前主题颜色
  Color get currentThemeColor => themeColorMap[_settings.themeColor]!;
  
  // 获取当前主题模式
  ThemeMode get currentThemeMode {
    switch (_settings.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }
  
  // 是否为深色模式
  bool get isDarkMode => _settings.themeMode == AppThemeMode.dark;
  
  // 音频播放服务
  AudioPlayerService? _audioPlayerService;
  
  // 设置音频播放服务
  void setAudioPlayerService(AudioPlayerService service) {
    _audioPlayerService = service;
    // 初始化时更新音频播放服务的设置
    _updateAudioPlayerFadeSettings();
    _updateAudioPlayerVolumeSettings();
  }
  
  // 初始化
  Future<void> init() async {
    await _loadSettings();
    await _loadSystemFonts();
  }
  
  // 加载系统字体
  Future<void> _loadSystemFonts() async {
    try {
      // 这里只是一个示例，实际上Flutter无法直接获取系统字体
      // 在实际应用中，可能需要使用平台特定的代码或插件来获取系统字体
      // 这里我们使用一个预定义的字体列表
      _availableFonts = [
        '.SF Pro Display',
        'Arial',
        'Roboto',
        'Times New Roman',
        'Courier New',
        'Georgia',
        'Verdana',
        'Tahoma',
        '微软雅黑',
        '宋体',
        '黑体',
        '楷体',
        '仿宋',
        '华文细黑',
        '华文楷体',
        '华文宋体',
        '方正姚体',
        '方正舒体',
        '方正黑体',
        'Noto Sans SC',
        'Noto Serif SC',
      ];
    } catch (e) {
      debugPrint('加载系统字体失败: $e');
    }
  }
  
  // 加载设置
  Future<void> _loadSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_settingsFileName');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
      } else {
        // 使用默认设置
        _settings = AppSettings();
        await _saveSettings();
      }
    } catch (e) {
      debugPrint('加载设置失败: $e');
      // 使用默认设置
      _settings = AppSettings();
    }
    
    notifyListeners();
  }
  
  // 保存设置
  Future<void> _saveSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_settingsFileName');
      
      final jsonString = jsonEncode(_settings.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('保存设置失败: $e');
    }
  }
  
  // 更新音频播放服务的淡入淡出设置
  void _updateAudioPlayerFadeSettings() {
    if (_audioPlayerService != null) {
      debugPrint('更新音频播放服务的淡入淡出设置: 启用=${_settings.enableFadeEffect}, 淡入=${_settings.fadeInDuration}ms, 淡出=${_settings.fadeOutDuration}ms');
      _audioPlayerService!.updateFadeSettings(
        _settings.enableFadeEffect,
        _settings.fadeInDuration,
        _settings.fadeOutDuration,
      );
    }
  }
  
  // 更新音频播放服务的音量设置
  void _updateAudioPlayerVolumeSettings() {
    if (_audioPlayerService != null) {
      debugPrint('更新音频播放服务的音量设置: 音量=${_settings.volume}, 静音=${_settings.isMuted}');
      
      // 使用特殊方法设置音量，避免保存设置
      if (_settings.isMuted) {
        _audioPlayerService!.setMuteFromSettings(true);
      } else {
        // 设置音量值
        _audioPlayerService!.setVolumeFromSettings(_settings.volume);
      }
    }
  }
  
  // 更新主题模式
  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    _settings = _settings.copyWith(themeMode: themeMode);
    await _saveSettings();
    notifyListeners();
  }
  
  // 更新主题颜色
  Future<void> updateThemeColor(ThemeColor themeColor) async {
    if (_settings.themeColor == themeColor) return; // 如果没有变化，直接返回
    
    _settings = _settings.copyWith(themeColor: themeColor);
    await _saveSettings();
    debugPrint('主题颜色已更新为: $themeColor, 颜色值: ${themeColorMap[themeColor]}');
    notifyListeners();
  }
  
  // 更新字体
  Future<void> updateFontFamily(String fontFamily) async {
    _settings = _settings.copyWith(fontFamily: fontFamily);
    await _saveSettings();
    notifyListeners();
  }
  
  // 更新淡入淡出效果启用状态
  Future<void> updateFadeEffect(bool enable) async {
    _settings = _settings.copyWith(enableFadeEffect: enable);
    await _saveSettings();
    _updateAudioPlayerFadeSettings();
    notifyListeners();
  }
  
  // 更新淡入持续时间
  Future<void> updateFadeInDuration(int durationMs) async {
    _settings = _settings.copyWith(fadeInDuration: durationMs);
    await _saveSettings();
    _updateAudioPlayerFadeSettings();
    notifyListeners();
  }
  
  // 更新淡出持续时间
  Future<void> updateFadeOutDuration(int durationMs) async {
    _settings = _settings.copyWith(fadeOutDuration: durationMs);
    await _saveSettings();
    _updateAudioPlayerFadeSettings();
    notifyListeners();
  }
  
  // 更新快捷键
  Future<void> updateShortcut(ShortcutAction action, HotKey hotKey) async {
    final newShortcuts = Map<ShortcutAction, HotKey>.from(_settings.shortcuts);
    newShortcuts[action] = hotKey;
    
    _settings = _settings.copyWith(shortcuts: newShortcuts);
    await _saveSettings();
    notifyListeners();
  }
  
  // 重置所有设置
  Future<void> resetSettings() async {
    _settings = AppSettings();
    await _saveSettings();
    _updateAudioPlayerFadeSettings();
    notifyListeners();
  }
  
  // 更新音量设置
  Future<void> updateVolume(double volume) async {
    _settings = _settings.copyWith(volume: volume);
    await _saveSettings();
    notifyListeners();
  }
  
  // 更新静音设置
  Future<void> updateMuted(bool isMuted) async {
    _settings = _settings.copyWith(isMuted: isMuted);
    await _saveSettings();
    notifyListeners();
  }
  
  // 获取当前设置
  Future<AppSettings> loadSettings() async {
    // 如果设置已经加载，直接返回
    if (_settings.volume > 0 || _settings.isMuted) {
      return _settings;
    }
    
    // 否则尝试重新加载
    await _loadSettings();
    return _settings;
  }
} 