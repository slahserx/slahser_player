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
    
    List<MusicFile> newFiles = [];
    
    for (String filePath in filePaths) {
      // 检查文件是否已存在
      bool exists = _musicFiles.any((file) => file.filePath == filePath);
      if (!exists) {
        try {
          MusicFile musicFile = await MusicFile.fromPath(filePath);
          newFiles.add(musicFile);
        } catch (e) {
          print('处理音乐文件失败: $filePath, 错误: $e');
        }
      }
    }
    
    if (newFiles.isNotEmpty) {
      _musicFiles.addAll(newFiles);
      await _saveLibrary();
      notifyListeners();
    }
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