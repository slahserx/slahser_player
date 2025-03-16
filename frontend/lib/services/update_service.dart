import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:slahser_player/models/app_version.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 更新状态枚举
enum UpdateStatus {
  idle, // 空闲状态
  checking, // 检查更新中
  available, // 有更新可用
  upToDate, // 已是最新版本
  downloading, // 下载更新中
  downloaded, // 更新已下载
  installing, // 安装更新中
  failed, // 更新失败
  error, // 更新出错
}

/// 更新服务，处理应用的版本检查和更新
class UpdateService extends ChangeNotifier {
  // GitHub相关设置
  static const String _owner = 'slahserx';  // GitHub用户名
  static const String _repo = 'slahser_player';  // GitHub仓库名
  static const String _githubApiReleaseUrl = 'https://api.github.com/repos/$_owner/$_repo/releases';
  static const String _githubReleasePageUrl = 'https://github.com/$_owner/$_repo/releases';
  
  // 当前更新状态
  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;
  
  // 最新版本信息
  AppVersion? _latestVersion;
  AppVersion? get latestVersion => _latestVersion;
  
  // 下载进度（0-100）
  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;
  
  // 下载的更新文件路径
  String? _downloadedFilePath;
  String? get downloadedFilePath => _downloadedFilePath;
  
  // 错误信息
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // 历史版本列表，包含当前版本
  final List<AppVersion> _versionHistory = [
    AppVersion(
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
    ),
    AppVersion(
      version: '0.7.5',
      buildNumber: '42',
      releaseDate: DateTime(2025, 2, 10),
      changelog: [
        '新增歌词显示功能，支持LRC格式',
        '添加均衡器功能，支持自定义音频效果',
        '优化元数据解析，支持显示封面图片',
        '修复部分安卓设备上的兼容性问题',
        '提升应用启动速度和整体性能',
      ],
    ),
    AppVersion(
      version: '0.7.0',
      buildNumber: '38',
      releaseDate: DateTime(2025, 1, 5),
      changelog: [
        '重新设计用户界面，提供深色和浅色主题',
        '新增文件夹视图，方便按文件夹浏览音乐',
        '增加拖放功能，支持直接拖放文件到播放器',
        '添加全局快捷键支持',
        '提高音频播放稳定性',
        '修复内存泄漏问题',
      ],
    ),
    AppVersion(
      version: '0.6.5',
      buildNumber: '32',
      releaseDate: DateTime(2024, 12, 1),
      changelog: [
        '添加音乐库管理功能',
        '新增专辑和艺术家视图',
        '支持导入/导出M3U播放列表',
        '改进音频流处理机制',
        '修复Windows上的高DPI显示问题',
      ],
    ),
  ];
  
  // 获取版本历史
  List<AppVersion> get versionHistory => _versionHistory;
  
  // 选中的历史版本（默认为当前版本）
  AppVersion _selectedVersion;
  AppVersion get selectedVersion => _selectedVersion;
  
  // 构造函数
  UpdateService() : _selectedVersion = AppVersion.current {
    // 更新当前版本（与AppVersion.current保持一致）
    _versionHistory[0] = AppVersion.current;
  }
  
  // 设置选中的版本
  void selectVersion(AppVersion version) {
    _selectedVersion = version;
    notifyListeners();
  }
  
  /// 检查更新
  Future<void> checkForUpdates() async {
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      // 发起网络请求获取GitHub最新发布版本
      final response = await http.get(Uri.parse('$_githubApiReleaseUrl/latest'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 解析版本信息
        final tagName = data['tag_name'] as String;
        final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        final publishedAt = DateTime.parse(data['published_at'] as String);
        final body = data['body'] as String;
        
        // 从release说明中提取更新日志（按行分割，去除空行）
        final changelog = body
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        
        // 创建新版本对象
        _latestVersion = AppVersion(
          version: version,
          buildNumber: data['id'].toString(),
          releaseDate: publishedAt,
          changelog: changelog,
        );
        
        debugPrint('GitHub最新版本: ${_latestVersion!.version}');
        debugPrint('当前版本: ${AppVersion.current.version}');
        
        // 检查是否有新版本
        final List<int> githubParts = _latestVersion!.version.split('.').map((part) => int.parse(part)).toList();
        final List<int> currentParts = AppVersion.current.version.split('.').map((part) => int.parse(part)).toList();
        
        // 比较版本号
        bool hasNewVersion = false;
        for (int i = 0; i < githubParts.length && i < currentParts.length; i++) {
          if (githubParts[i] > currentParts[i]) {
            hasNewVersion = true;
            break;
          } else if (githubParts[i] < currentParts[i]) {
            hasNewVersion = false;
            break;
          }
        }
        
        // 如果主要版本号相同，但GitHub版本有更多的子版本号
        if (!hasNewVersion && githubParts.length > currentParts.length) {
          hasNewVersion = true;
        }
        
        _status = hasNewVersion ? UpdateStatus.available : UpdateStatus.upToDate;
        debugPrint('版本比较结果: ${hasNewVersion ? "有新版本可用" : "已是最新版本"}');
      } else if (response.statusCode == 404) {
        // 没有发布版本
        _status = UpdateStatus.upToDate;
        debugPrint('GitHub API 404: 未找到发布版本');
      } else {
        throw Exception('GitHub API返回错误: ${response.statusCode}');
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      debugPrint('检查更新出错: $_errorMessage');
    }

    notifyListeners();
  }
  
  /// 下载更新（在浏览器中打开GitHub发布页面）
  Future<void> downloadUpdate() async {
    if (_latestVersion == null) return;

    try {
      final url = Uri.parse(_githubReleasePageUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw '无法打开URL: $_githubReleasePageUrl';
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  
  /// 安装更新
  Future<void> installUpdate() async {
    // 实际应用中，这里应该调用本地更新安装逻辑
    // 对于桌面应用，通常会下载安装包并调用系统API执行安装
    
    // 模拟安装
    await Future.delayed(const Duration(seconds: 1));
    
    // 重置状态
    _status = UpdateStatus.idle;
    _latestVersion = null;
    _downloadProgress = 0;
    notifyListeners();
  }
  
  /// 重置状态
  void resetStatus() {
    _status = UpdateStatus.idle;
    _downloadProgress = 0;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// 设置状态并通知监听器
  void _setStatus(UpdateStatus status) {
    _status = status;
    notifyListeners();
  }
} 