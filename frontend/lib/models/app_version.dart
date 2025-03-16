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
    version: '0.9.0',
    buildNumber: '58',
    releaseDate: DateTime(2025, 4, 10),
    changelog: [
      '全新UI设计，更加现代和美观',
      '添加自定义字体支持，可以在设置中更改应用字体',
      '优化音乐导入功能，防止重复导入相同文件',
      '改进歌词显示，支持应用字体设置到歌词页面',
      '优化音乐文件元数据解析，提高解析准确度',
      '增强专辑和艺术家视图，改进封面图片显示',
      '修复多个已知问题，提升应用整体稳定性',
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