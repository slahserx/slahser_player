import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/file_service.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../utils/cache_manager.dart';
import 'dart:math';

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
  Future<String> _getMusicLibraryPath() async {
    final appDirPath = await _getAppDirectoryPath();
    return path.join(appDirPath, _musicLibraryFileName).replaceAll('\\', '/');
  }
  
  // 初始化
  Future<void> initialize() async {
    // 初始化缓存管理器
    await MusicCacheManager().initialize();
    
    // ... 原有的初始化代码 ...
  }
  
  // 修改导入音乐文件的方法
  Future<MusicFile?> importMusicFile(String filePath) async {
    // 规范化路径
    final normalizedPath = _normalizePath(filePath);
    
    // 检查文件是否存在
    if (!File(normalizedPath).existsSync()) {
      debugPrint('文件不存在: $normalizedPath');
      return null;
    }
    
    // 检查是否已经导入
    final existingFile = _musicFiles.firstWhere(
      (file) => _normalizePath(file.filePath) == normalizedPath,
      orElse: () => MusicFile(
        id: '',
        filePath: '',
        fileName: '',
        fileExtension: '',
        title: '',
        artist: '',
        album: '',
        duration: const Duration(),
      ),
    );
    
    if (existingFile.id.isNotEmpty) {
      debugPrint('文件已存在: $normalizedPath');
      return existingFile;
    }
    
    try {
      // 直接使用MusicFile.fromPath静态方法创建音乐文件
      final musicFile = await MusicFile.fromPath(normalizedPath);
      
      // 成功解析后添加到库中
      _musicFiles.add(musicFile);
      
      debugPrint('导入成功: ${musicFile.title} - ${musicFile.artist}');
      return musicFile;
    } catch (e) {
      debugPrint('导入音乐文件时发生错误: $e');
      return null;
    }
  }
  
  // 修改重新扫描所有文件的方法
  Future<int> rescanAllFiles() async {
    int updatedCount = 0;
    
    for (int i = 0; i < _musicFiles.length; i++) {
      final file = _musicFiles[i];
      if (File(file.filePath).existsSync()) {
        // 清除缓存，强制重新解析
        await MusicCacheManager().clearCache(CacheType.metadata);
        
        // 重新解析文件
        try {
          final newFile = await MusicFile.fromPath(file.filePath);
          // 替换列表中的文件
          _musicFiles[i] = newFile;
          updatedCount++;
        } catch (e) {
          debugPrint('重新解析文件失败: ${file.filePath}, 错误: $e');
        }
      }
    }
    
    // 重新保存库
    await saveLibrary();
    
    return updatedCount;
  }
  
  // 修改保存库的方法
  Future<void> saveLibrary() async {
    try {
      final libraryPath = await _getMusicLibraryPath();
      final libraryFile = File(libraryPath);
      
      // 创建目录（如果不存在）
      if (!await libraryFile.parent.exists()) {
        await libraryFile.parent.create(recursive: true);
      }
      
      // 将库转换为JSON
      final jsonList = _musicFiles.map((file) => file.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // 写入文件
      await libraryFile.writeAsString(jsonString, flush: true);
      
      debugPrint('音乐库已保存，共${_musicFiles.length}首歌曲');
    } catch (e) {
      debugPrint('保存音乐库失败: $e');
    }
  }
  
  // 清理缓存方法
  Future<void> clearCache(CacheType type) async {
    await MusicCacheManager().clearCache(type);
  }
  
  // 获取缓存大小
  Future<String> getCacheSize() async {
    final size = await MusicCacheManager().getCacheSize(CacheType.all);
    
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
  
  // 导入音乐文件
  Future<Map<String, dynamic>> importMusicFiles() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      List<String> filePaths = await FileService.importMusicFiles();
      if (filePaths.isEmpty) {
        return {'success': false, 'message': '未选择任何文件'};
      }
      
      Map<String, dynamic> result = await _processMusicFiles(filePaths);
      int addedCount = result['added'];
      int skippedCount = result['skipped'];
      
      String message = '成功导入$addedCount首音乐';
      if (skippedCount > 0) {
        message += '，跳过$skippedCount首（已存在或无效）';
      }
      
      return {
        'success': true, 
        'message': message, 
        'added': addedCount,
        'skipped': skippedCount,
        'total': result['total']
      };
    } catch (e) {
      return {'success': false, 'message': '导入文件失败: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 导入音乐文件夹
  Future<Map<String, dynamic>> importMusicFolder() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      List<String> filePaths = await FileService.importMusicFolder();
      if (filePaths.isEmpty) {
        return {'success': false, 'message': '未选择任何文件夹或文件夹中没有音乐文件'};
      }
      
      Map<String, dynamic> result = await _processMusicFiles(filePaths);
      int addedCount = result['added'];
      int skippedCount = result['skipped'];
      
      String message = '成功导入$addedCount首音乐';
      if (skippedCount > 0) {
        message += '，跳过$skippedCount首（已存在或无效）';
      }
      
      return {
        'success': true, 
        'message': message, 
        'added': addedCount,
        'skipped': skippedCount,
        'total': result['total']
      };
    } catch (e) {
      return {'success': false, 'message': '导入文件夹失败: ${e.toString()}'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 处理音乐文件
  Future<Map<String, dynamic>> _processMusicFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return {'added': 0, 'skipped': 0, 'total': 0};
    
    _isLoading = true;
    notifyListeners();
    
    int addedCount = 0;
    int skippedCount = 0;
    List<MusicFile> newFiles = [];
    
    // 创建现有文件路径和ID的Map
    final Map<String, bool> existingPaths = {};
    final Map<String, bool> existingIds = {};
    for (var music in _musicFiles) {
      existingPaths[_normalizePath(music.filePath)] = true;
      existingIds[music.id] = true;
    }
    
    for (String filePath in filePaths) {
      try {
        // 规范化路径进行比较
        String normalizedPath = _normalizePath(filePath);
        
        // 检查文件是否已存在
        if (existingPaths.containsKey(normalizedPath)) {
          debugPrint('文件已存在，跳过: $filePath');
          skippedCount++;
          continue;
        }
        
        // 检查文件是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('文件不存在，跳过: $filePath');
          skippedCount++;
          continue;
        }
        
        // 创建音乐文件对象
        final musicFile = await MusicFile.fromPath(filePath);
        
        // 检查ID是否已存在
        if (existingIds.containsKey(musicFile.id)) {
          debugPrint('音乐ID已存在，跳过: ${musicFile.id} (${musicFile.filePath})');
          skippedCount++;
          continue;
        }
        
        newFiles.add(musicFile);
        
        // 添加到现有路径和ID的Map，防止同一批导入中的重复
        existingPaths[normalizedPath] = true;
        existingIds[musicFile.id] = true;
        
        // 输出调试信息
        debugPrint('成功导入: ${musicFile.title} - ${musicFile.artist}, ID: ${musicFile.id}');
        addedCount++;
      } catch (e) {
        debugPrint('处理音乐文件失败: $filePath - ${e.toString()}');
        skippedCount++;
      }
    }
    
    if (newFiles.isNotEmpty) {
      _musicFiles.addAll(newFiles);
      await _saveMusicLibrary();
    }
    
    debugPrint('导入处理完成: 共${filePaths.length}个文件，成功导入$addedCount首，跳过$skippedCount首');
    _isLoading = false;
    notifyListeners();
    
    return {
      'added': addedCount,
      'skipped': skippedCount,
      'total': filePaths.length
    };
  }
  
  // 规范化路径
  String _normalizePath(String filePath) {
    // 转换路径分隔符为统一格式，并转为小写便于比较
    return filePath.replaceAll('\\', '/').toLowerCase();
  }
  
  // 保存音乐库到文件
  Future<void> _saveMusicLibrary() async {
    try {
      final libraryPath = await _getMusicLibraryPath();
      final file = File(libraryPath);
      
      // 确保目录存在
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      
      // 将音乐库转换为JSON
      final libraryData = {
        'songs': _musicFiles.map((music) => music.toJson()).toList(),
      };
      
      // 保存到文件
      await file.writeAsString(jsonEncode(libraryData));
      debugPrint('音乐库保存成功: $libraryPath');
      
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
      final filePath = await _getMusicLibraryPath();
      debugPrint('尝试从以下路径加载音乐库: $filePath');
      
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        
        if (jsonString.isNotEmpty) {
          try {
            // 解析JSON
            final dynamic jsonData = jsonDecode(jsonString);
            List<dynamic> songsList = [];
            
            // 处理不同格式的JSON数据
            if (jsonData is Map<String, dynamic> && jsonData.containsKey('songs')) {
              // 新格式：包含songs字段的对象
              songsList = jsonData['songs'] as List<dynamic>;
              debugPrint('成功解析音乐库JSON（新格式），找到${songsList.length}个音乐文件');
            } else if (jsonData is List) {
              // 旧格式：直接的路径列表
              songsList = jsonData;
              debugPrint('成功解析音乐库JSON（旧格式），找到${songsList.length}个音乐文件路径');
            } else {
              throw FormatException('未知的音乐库JSON格式');
            }
            
            // 使用Set保存规范化路径，防止重复
            final Set<String> normalizedPaths = {};
            final List<MusicFile> loadedFiles = [];
            int duplicateCount = 0;
            
            // 处理歌曲列表
            for (var songItem in songsList) {
              try {
                MusicFile? musicFile;
                
                if (songItem is String) {
                  // 旧格式：字符串路径
                  String filePath = songItem;
                  String normalizedPath = _normalizePath(filePath);
                  
                  // 如果路径已存在，跳过
                  if (normalizedPaths.contains(normalizedPath)) {
                    duplicateCount++;
                    continue;
                  }
                  
                  normalizedPaths.add(normalizedPath);
                  
                  // 检查文件是否仍然存在
                  if (File(normalizedPath).existsSync()) {
                    musicFile = await MusicFile.fromPath(normalizedPath);
                  }
                } else if (songItem is Map<String, dynamic>) {
                  // 新格式：JSON对象
                  musicFile = MusicFile.fromJson(songItem);
                  
                  // 检查文件是否存在且路径是否重复
                  String normalizedPath = _normalizePath(musicFile.filePath);
                  if (!File(musicFile.filePath).existsSync()) {
                    debugPrint('文件不存在，跳过: ${musicFile.filePath}');
                    continue;
                  }
                  
                  if (normalizedPaths.contains(normalizedPath)) {
                    duplicateCount++;
                    continue;
                  }
                  
                  normalizedPaths.add(normalizedPath);
                }
                
                // 添加到加载的文件列表
                if (musicFile != null) {
                  loadedFiles.add(musicFile);
                }
              } catch (e) {
                debugPrint('处理音乐文件数据失败: $songItem, 错误: $e');
              }
            }
            
            _musicFiles = loadedFiles;
            
            if (duplicateCount > 0) {
              debugPrint('检测到$duplicateCount个重复文件路径，已自动跳过');
              // 检测到重复，保存一次清理后的库
              await _saveMusicLibrary();
            }
            
            debugPrint('所有音乐文件加载完成，共${_musicFiles.length}首歌曲');
          } catch (e) {
            debugPrint('解析音乐库JSON失败: $e');
          }
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
          await _saveMusicLibrary();
          
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
    debugPrint('尝试删除音乐文件，ID: $id');
    
    // 查找要删除的音乐文件
    MusicFile? musicFileToRemove;
    for (var file in _musicFiles) {
      if (file.id == id) {
        musicFileToRemove = file;
        break;
      }
    }
    
    // 输出要删除的文件信息
    if (musicFileToRemove != null) {
      debugPrint('删除音乐文件: ${musicFileToRemove.title} (${musicFileToRemove.filePath})');
    }
    
    // 从列表中移除匹配ID的文件
    final initialCount = _musicFiles.length;
    _musicFiles.removeWhere((file) => file.id == id);
    final removedCount = initialCount - _musicFiles.length;
    
    // 保存更新后的音乐库
    await _saveMusicLibrary();
    
    // 输出删除结果
    if (removedCount > 0) {
      debugPrint('成功删除 $removedCount 个音乐文件，ID: $id');
    } else {
      debugPrint('找不到ID为 $id 的音乐文件，没有删除任何内容');
    }
    
    notifyListeners();
  }
  
  // 清空音乐库
  Future<void> clearLibrary() async {
    debugPrint('清空音乐库，当前共有 ${_musicFiles.length} 首歌曲');
    _musicFiles = [];
    await _saveMusicLibrary();
    debugPrint('音乐库已清空');
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
          String extension = path.extension(entity.path).toLowerCase().replaceFirst('.', '');
          if (FileService.supportedAudioFormats.contains(extension)) {
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

  // 生成唯一ID的方法
  String _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(10000).toString();
  }
} 