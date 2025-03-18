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
    version: '0.9.2',
    buildNumber: '60',
    releaseDate: DateTime(2025, 3, 19),
    changelog: [
      '修复播放器控制栏封面图片闪烁问题',
      '优化歌曲列表中封面图片的加载和缓存机制',
      '改进图片过渡动画，使切换更加流畅',
      '添加图片预加载功能，提前加载当前播放歌曲的前后封面',
      '优化内存使用，减少频繁重绘导致的性能问题',
      '修复了嵌入式封面图片在不同设备上的显示问题',
      '提升整体用户界面响应速度和稳定性',
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