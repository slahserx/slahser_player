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
    version: '0.9.1',
    buildNumber: '59',
    releaseDate: DateTime(2025, 3, 18),
    changelog: [
      '优化播放队列显示，从右侧滑出更加美观',
      '改进歌词页面自适应布局，解决窗口缩小时溢出问题',
      '优化歌曲切换性能，添加颜色缓存和预加载机制',
      '增强色彩提取算法，使界面颜色更加协调',
      '修复了多个UI布局问题',
      '提升整体界面响应速度和流畅度',
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