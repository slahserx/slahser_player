import 'dart:convert';

/// 应用版本信息模型
class AppVersion {
  /// 当前版本号
  final String version;
  /// 构建编号
  final String buildNumber;
  /// 版本发布日期
  final DateTime releaseDate;
  /// 版本更新日志
  final List<String> changelog;

  const AppVersion({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.changelog,
  });

  /// 当前应用版本
  static final AppVersion current = AppVersion(
    version: '0.8.0',
    buildNumber: '47',
    releaseDate: DateTime(2025, 3, 16),
    changelog: [
      '新增播放列表功能，支持创建、删除和编辑播放列表',
      '优化音量控制，修复切换歌曲时音量滑块动画问题',
      '改进用户界面，优化布局和响应式设计',
      '新增迷你播放器模式，可在任务栏显示播放控制',
      '添加更多音频格式支持，包括FLAC和OGG',
      '修复多个已知BUG和稳定性问题',
    ],
  );

  /// 从JSON创建版本信息
  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['version'] as String,
      buildNumber: json['buildNumber'].toString(),
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      changelog: List<String>.from(json['changelog'] as List),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'releaseDate': releaseDate.toIso8601String(),
      'changelog': changelog,
    };
  }

  /// 判断是否有新版本
  bool hasNewerVersion(AppVersion other) {
    final List<String> currentParts = version.split('.');
    final List<String> otherParts = other.version.split('.');

    for (int i = 0; i < currentParts.length && i < otherParts.length; i++) {
      final currentValue = int.parse(currentParts[i]);
      final otherValue = int.parse(otherParts[i]);

      if (otherValue > currentValue) {
        return true;
      } else if (otherValue < currentValue) {
        return false;
      }
    }

    return otherParts.length > currentParts.length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          version == other.version;

  @override
  int get hashCode => version.hashCode;
} 