import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/file_service.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class MusicLibraryService extends ChangeNotifier {
  static const String _musicLibraryFileName = 'music_library.json';
  static const String _appFolderName = 'SlahserPlayer';

  List<MusicFile> _musicFiles = [];
  List<MusicFile> get musicFiles => _musicFiles;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  bool _isScanning = false;
  bool _completeScan = false;
  bool get isLibraryFullyLoaded => _completeScan && !_isScanning;
  
  /// 获取应用专用文件夹路径
  Future<String> _getAppDirectoryPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(path.join(appDocDir.path, _appFolderName));
    
    // 确保目录存在
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
      debugPrint('**** 创建应用专用文件夹: ${appDir.path} ****');
    }
    
    return appDir.path;
  }
  
  /// 获取音乐库文件路径
  Future<String> _getMusicLibraryFilePath() async {
    final appDirPath = await _getAppDirectoryPath();
    return path.join(appDirPath, _musicLibraryFileName).replaceAll('\\', '/');
  }
  
  // 导入音乐文件
  Future<void> importMusicFiles() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      List<String> filePaths = await FileService.importMusicFiles();
      await _processMusicFiles(filePaths);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 导入音乐文件夹
  Future<void> importMusicFolder() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      List<String> filePaths = await FileService.importMusicFolder();
      await _processMusicFiles(filePaths);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 处理音乐文件
  Future<void> _processMusicFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    // 创建现有音乐文件路径的映射，用于快速查找
    final Map<String, bool> existingPaths = {};
    for (var music in _musicFiles) {
      // 规范化路径并存储到映射中
      existingPaths[_normalizePath(music.filePath)] = true;
    }
    
    List<MusicFile> newFiles = [];
    int processedCount = 0;
    int totalFiles = filePaths.length;
    int skippedCount = 0;
    
    for (String filePath in filePaths) {
      // 规范化文件路径
      String normalizedPath = _normalizePath(filePath);
      
      processedCount++;
      if (processedCount % 5 == 0 || processedCount == totalFiles) {
        debugPrint('正在处理文件: $processedCount / $totalFiles (已跳过: $skippedCount)');
        // 更新UI但保持loading状态
        notifyListeners();
      }
      
      // 检查文件是否已存在（使用规范化路径比较）
      if (existingPaths.containsKey(normalizedPath)) {
        debugPrint('文件已存在，跳过: $normalizedPath');
        skippedCount++;
        continue;
      }
      
      try {
        // 验证文件是否存在且可读
        final file = File(normalizedPath);
        if (await file.exists()) {
          debugPrint('开始解析文件: $normalizedPath');
          MusicFile musicFile = await MusicFile.fromPath(normalizedPath);
          newFiles.add(musicFile);
          // 将新文件添加到映射中，防止同一批导入中的重复文件
          existingPaths[normalizedPath] = true;
          debugPrint('文件解析完成: ${musicFile.title} - ${musicFile.artist}');
        } else {
          debugPrint('文件不存在: $normalizedPath');
        }
      } catch (e) {
        debugPrint('处理音乐文件失败: $normalizedPath, 错误: $e');
      }
    }
    
    debugPrint('处理完成，总计: ${filePaths.length} 个文件，新增: ${newFiles.length} 个，跳过: $skippedCount 个');
    
    if (newFiles.isNotEmpty) {
      _musicFiles.addAll(newFiles);
      await _saveLibrary();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // 规范化路径
  String _normalizePath(String filePath) {
    // 转换路径分隔符为统一格式，并转为小写便于比较
    return filePath.replaceAll('\\', '/').toLowerCase();
  }
  
  // 保存音乐库
  Future<void> _saveLibrary() async {
    try {
      final filePath = await _getMusicLibraryFilePath();
      debugPrint('准备保存音乐库到: $filePath');
      
      // 检查是否有重复路径，并去重
      final Set<String> uniquePaths = Set<String>();
      final List<MusicFile> uniqueFiles = [];
      
      for (var file in _musicFiles) {
        String normalizedPath = _normalizePath(file.filePath);
        if (!uniquePaths.contains(normalizedPath)) {
          uniquePaths.add(normalizedPath);
          uniqueFiles.add(file);
        }
      }
      
      // 如果检测到重复，更新音乐文件列表
      if (uniqueFiles.length < _musicFiles.length) {
        debugPrint('检测到${_musicFiles.length - uniqueFiles.length}个重复音乐文件，已自动清理');
        _musicFiles = uniqueFiles;
      }
      
      // 将音乐文件列表转换为简单的路径列表
      List<String> paths = _musicFiles.map((file) => file.filePath).toList();
      
      final file = File(filePath);
      await file.writeAsString(jsonEncode(paths));
      debugPrint('音乐库保存成功，共${paths.length}首歌曲');
    } catch (e) {
      debugPrint('保存音乐库失败: $e');
    }
  }
  
  // 加载音乐库
  Future<void> loadLibrary() async {
    _isLoading = true;
    _isScanning = true;
    notifyListeners();
    
    try {
      final filePath = await _getMusicLibraryFilePath();
      debugPrint('尝试从以下路径加载音乐库: $filePath');
      
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        
        if (jsonString.isNotEmpty) {
          List<dynamic> paths = jsonDecode(jsonString);
          debugPrint('成功解析音乐库JSON，找到${paths.length}个音乐文件路径');
          
          // 使用Set保存规范化路径，防止重复
          final Set<String> normalizedPaths = {};
          final List<MusicFile> loadedFiles = [];
          int duplicateCount = 0;
          
          for (String filePath in paths.cast<String>()) {
            // 规范化路径
            String normalizedPath = _normalizePath(filePath);
            
            // 如果路径已存在，跳过
            if (normalizedPaths.contains(normalizedPath)) {
              duplicateCount++;
              continue;
            }
            
            normalizedPaths.add(normalizedPath);
            
            // 检查文件是否仍然存在
            if (File(normalizedPath).existsSync()) {
              try {
                MusicFile musicFile = await MusicFile.fromPath(normalizedPath);
                loadedFiles.add(musicFile);
              } catch (e) {
                debugPrint('加载音乐文件失败: $normalizedPath, 错误: $e');
              }
            }
          }
          
          _musicFiles = loadedFiles;
          
          if (duplicateCount > 0) {
            debugPrint('检测到$duplicateCount个重复文件路径，已自动跳过');
            // 检测到重复，保存一次清理后的库
            await _saveLibrary();
          }
          
          debugPrint('所有音乐文件加载完成，共${_musicFiles.length}首歌曲');
        } else {
          debugPrint('音乐库文件内容为空');
        }
      } else {
        debugPrint('音乐库文件不存在');
        
        // 尝试从SharedPreferences加载（兼容旧版本）
        final prefs = await SharedPreferences.getInstance();
        List<String>? oldPaths = prefs.getStringList('music_library');
        
        if (oldPaths != null && oldPaths.isNotEmpty) {
          debugPrint('从SharedPreferences找到${oldPaths.length}个音乐文件路径，即将迁移');
          
          // 使用Set保存规范化路径，防止重复
          final Set<String> normalizedPaths = {};
          final List<MusicFile> loadedFiles = [];
          
          for (String filePath in oldPaths) {
            // 规范化路径
            String normalizedPath = _normalizePath(filePath);
            
            // 如果路径已存在，跳过
            if (normalizedPaths.contains(normalizedPath)) {
              continue;
            }
            
            normalizedPaths.add(normalizedPath);
            
            // 检查文件是否仍然存在
            if (File(normalizedPath).existsSync()) {
              try {
                MusicFile musicFile = await MusicFile.fromPath(normalizedPath);
                loadedFiles.add(musicFile);
              } catch (e) {
                debugPrint('加载音乐文件失败: $normalizedPath, 错误: $e');
              }
            }
          }
          
          _musicFiles = loadedFiles;
          
          // 迁移后保存到新格式
          await _saveLibrary();
          
          // 清理旧数据
          await prefs.remove('music_library');
          debugPrint('迁移完成，从SharedPreferences迁移了${_musicFiles.length}首歌曲');
        }
      }
    } catch (e) {
      debugPrint('加载音乐库失败: $e');
    } finally {
      _isLoading = false;
      _isScanning = false;
      _completeScan = true;
      notifyListeners();
    }
  }
  
  // 删除音乐文件
  Future<void> removeMusicFile(String id) async {
    _musicFiles.removeWhere((file) => file.id == id);
    await _saveLibrary();
    notifyListeners();
  }
  
  // 清空音乐库
  Future<void> clearLibrary() async {
    _musicFiles = [];
    await _saveLibrary();
    notifyListeners();
  }

  /// 扫描音乐文件
  Future<void> scanMusicFiles() async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      notifyListeners();
      
      debugPrint('开始扫描音乐文件...');
      
      // 清空当前音乐文件列表
      _musicFiles.clear();
      
      // 获取指定的音乐文件夹
      final paths = await _getSettingsMusicPaths();
      if (paths.isEmpty) {
        debugPrint('未设置音乐文件夹路径');
        _isScanning = false;
        notifyListeners();
        return;
      }
      
      debugPrint('从以下路径扫描音乐: $paths');
      
      // 扫描所有音乐文件夹
      for (final dirPath in paths) {
        try {
          final dir = Directory(dirPath);
          if (!await dir.exists()) {
            debugPrint('目录不存在: $dirPath');
            continue;
          }
          
          await _scanMusicFilesInDirectory(dir);
        } catch (e) {
          debugPrint('扫描目录出错: $e');
        }
      }
      
      // 按照自定义规则进行排序（主要按艺术家、专辑、标题）
      _sortMusicFiles();
      
      debugPrint('音乐扫描完成，共找到 ${_musicFiles.length} 首歌曲');
      
      // 保存音乐库
      await _saveMusicLibrary();
      
      _isScanning = false;
      
      // 发送特殊通知，表明音乐库已完全加载
      _completeScan = true;
      notifyListeners();
      
      // 额外发送一次通知，确保同步代码知道扫描已完成
      Future.delayed(const Duration(milliseconds: 100), () {
        debugPrint('******* 音乐库扫描完全完成，通知所有监听器 *******');
        notifyListeners();
      });
      
    } catch (e) {
      debugPrint('扫描音乐文件发生错误: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 获取设置中的音乐路径
  Future<List<String>> _getSettingsMusicPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? paths = prefs.getStringList('music_paths');
      return paths ?? [];
    } catch (e) {
      debugPrint('获取音乐路径失败: $e');
      return [];
    }
  }

  /// 扫描目录中的音乐文件
  Future<void> _scanMusicFilesInDirectory(Directory dir) async {
    try {
      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          String extension = path.extension(entity.path).toLowerCase();
          if (['.mp3', '.flac', '.wav', '.ogg', '.m4a', '.aac'].contains(extension)) {
            try {
              MusicFile musicFile = await MusicFile.fromPath(entity.path);
              _musicFiles.add(musicFile);
            } catch (e) {
              debugPrint('解析音乐文件失败: ${entity.path}, 错误: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('扫描目录失败: ${dir.path}, 错误: $e');
    }
  }

  /// 对音乐文件进行排序
  void _sortMusicFiles() {
    _musicFiles.sort((a, b) {
      // 首先按艺术家排序
      int artistComp = a.artist.compareTo(b.artist);
      if (artistComp != 0) return artistComp;
      
      // 然后按专辑排序
      int albumComp = a.album.compareTo(b.album);
      if (albumComp != 0) return albumComp;
      
      // 最后按标题排序
      return a.title.compareTo(b.title);
    });
    
    debugPrint('音乐文件已排序');
  }

  /// 保存音乐库
  Future<void> _saveMusicLibrary() async {
    await _saveLibrary();
  }
} 