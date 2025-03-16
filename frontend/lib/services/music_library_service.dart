import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/file_service.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MusicLibraryService extends ChangeNotifier {
  List<MusicFile> _musicFiles = [];
  List<MusicFile> get musicFiles => _musicFiles;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
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
    
    List<MusicFile> newFiles = [];
    int processedCount = 0;
    int totalFiles = filePaths.length;
    
    for (String filePath in filePaths) {
      // 规范化文件路径
      String normalizedPath = filePath.replaceAll('\\', '/');
      
      processedCount++;
      if (processedCount % 5 == 0 || processedCount == totalFiles) {
        debugPrint('正在处理文件: $processedCount / $totalFiles');
        // 更新UI但保持loading状态
        notifyListeners();
      }
      
      // 检查文件是否已存在
      bool exists = _musicFiles.any((file) => file.filePath == normalizedPath);
      if (!exists) {
        try {
          // 验证文件是否存在且可读
          final file = File(normalizedPath);
          if (await file.exists()) {
            debugPrint('开始解析文件: $normalizedPath');
            MusicFile musicFile = await MusicFile.fromPath(normalizedPath);
            newFiles.add(musicFile);
            debugPrint('文件解析完成: ${musicFile.title} - ${musicFile.artist}');
          } else {
            debugPrint('文件不存在: $normalizedPath');
          }
        } catch (e) {
          debugPrint('处理音乐文件失败: $normalizedPath, 错误: $e');
        }
      } else {
        debugPrint('文件已存在，跳过: $normalizedPath');
      }
    }
    
    debugPrint('处理完成，新增 ${newFiles.length} 个文件');
    
    if (newFiles.isNotEmpty) {
      _musicFiles.addAll(newFiles);
      await _saveLibrary();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // 保存音乐库
  Future<void> _saveLibrary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 将音乐文件列表转换为简单的路径列表
      List<String> paths = _musicFiles.map((file) => file.filePath).toList();
      await prefs.setStringList('music_library', paths);
    } catch (e) {
      print('保存音乐库失败: $e');
    }
  }
  
  // 加载音乐库
  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? paths = prefs.getStringList('music_library');
      
      if (paths != null && paths.isNotEmpty) {
        _musicFiles = [];
        
        for (String filePath in paths) {
          // 检查文件是否仍然存在
          if (File(filePath).existsSync()) {
            try {
              MusicFile musicFile = await MusicFile.fromPath(filePath);
              _musicFiles.add(musicFile);
            } catch (e) {
              print('加载音乐文件失败: $filePath, 错误: $e');
            }
          }
        }
      }
    } finally {
      _isLoading = false;
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
} 