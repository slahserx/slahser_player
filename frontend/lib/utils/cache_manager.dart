import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// 音乐应用缓存管理器
/// 负责管理音乐文件元数据、图片和歌词的缓存
class MusicCacheManager {
  static final MusicCacheManager _instance = MusicCacheManager._internal();
  factory MusicCacheManager() => _instance;
  
  MusicCacheManager._internal();
  
  // 缓存目录路径
  String? _baseCachePath;
  String? _coverCachePath;
  String? _metadataCachePath;
  String? _lyricsCachePath;
  
  // 初始化缓存目录
  Future<void> initialize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _baseCachePath = '${tempDir.path}/slahser_player_cache';
      
      _coverCachePath = '$_baseCachePath/covers';
      _metadataCachePath = '$_baseCachePath/metadata';
      _lyricsCachePath = '$_baseCachePath/lyrics';
      
      // 创建缓存目录
      _createDirectory(_baseCachePath!);
      _createDirectory(_coverCachePath!);
      _createDirectory(_metadataCachePath!);
      _createDirectory(_lyricsCachePath!);
      
      debugPrint('缓存管理器初始化完成，路径: $_baseCachePath');
    } catch (e) {
      debugPrint('初始化缓存管理器失败: $e');
    }
  }
  
  // 创建目录
  void _createDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
  
  // 计算文件的哈希值，用作缓存键
  String getFileHash(String filePath) {
    return md5.convert(utf8.encode(filePath)).toString();
  }
  
  // 获取文件的修改时间戳
  Future<int> getFileModificationTimestamp(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified.millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('获取文件修改时间失败: $e');
    }
    return 0;
  }
  
  // 保存图片缓存
  Future<bool> saveCoverCache(String filePath, List<int> imageData) async {
    if (_coverCachePath == null) await initialize();
    if (imageData.isEmpty) return false;
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_coverCachePath/$fileHash.img';
      
      final cacheFile = File(cacheFilePath);
      await cacheFile.writeAsBytes(imageData);
      
      // 保存元数据(修改时间戳)
      final timestamp = await getFileModificationTimestamp(filePath);
      final metaFile = File('$_coverCachePath/$fileHash.meta');
      await metaFile.writeAsString(timestamp.toString());
      
      debugPrint('保存封面缓存: $cacheFilePath, 大小: ${imageData.length}字节');
      return true;
    } catch (e) {
      debugPrint('保存封面缓存失败: $e');
      return false;
    }
  }
  
  // 加载图片缓存
  Future<List<int>?> loadCoverCache(String filePath) async {
    if (_coverCachePath == null) await initialize();
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_coverCachePath/$fileHash.img';
      final metaFilePath = '$_coverCachePath/$fileHash.meta';
      
      final cacheFile = File(cacheFilePath);
      final metaFile = File(metaFilePath);
      
      // 检查缓存和元文件是否存在
      if (await cacheFile.exists() && await metaFile.exists()) {
        // 检查源文件是否被修改
        final cachedTimestamp = int.parse(await metaFile.readAsString());
        final currentTimestamp = await getFileModificationTimestamp(filePath);
        
        if (cachedTimestamp == currentTimestamp) {
          final imageData = await cacheFile.readAsBytes();
          debugPrint('从缓存加载封面: $cacheFilePath, 大小: ${imageData.length}字节');
          return imageData;
        } else {
          debugPrint('文件已修改，缓存无效: $filePath');
          // 删除过期缓存
          await cacheFile.delete();
          await metaFile.delete();
          return null;
        }
      }
    } catch (e) {
      debugPrint('加载封面缓存失败: $e');
    }
    
    return null;
  }
  
  // 保存元数据缓存
  Future<bool> saveMetadataCache(String filePath, Map<String, dynamic> metadata) async {
    if (_metadataCachePath == null) await initialize();
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_metadataCachePath/$fileHash.json';
      
      final cacheFile = File(cacheFilePath);
      await cacheFile.writeAsString(jsonEncode(metadata));
      
      // 保存元数据(修改时间戳)
      final timestamp = await getFileModificationTimestamp(filePath);
      final metaFile = File('$_metadataCachePath/$fileHash.meta');
      await metaFile.writeAsString(timestamp.toString());
      
      debugPrint('保存元数据缓存: $cacheFilePath');
      return true;
    } catch (e) {
      debugPrint('保存元数据缓存失败: $e');
      return false;
    }
  }
  
  // 加载元数据缓存
  Future<Map<String, dynamic>?> loadMetadataCache(String filePath) async {
    if (_metadataCachePath == null) await initialize();
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_metadataCachePath/$fileHash.json';
      final metaFilePath = '$_metadataCachePath/$fileHash.meta';
      
      final cacheFile = File(cacheFilePath);
      final metaFile = File(metaFilePath);
      
      // 检查缓存和元文件是否存在
      if (await cacheFile.exists() && await metaFile.exists()) {
        // 检查源文件是否被修改
        final cachedTimestamp = int.parse(await metaFile.readAsString());
        final currentTimestamp = await getFileModificationTimestamp(filePath);
        
        if (cachedTimestamp == currentTimestamp) {
          final metadataStr = await cacheFile.readAsString();
          final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
          debugPrint('从缓存加载元数据: $cacheFilePath');
          return metadata;
        } else {
          debugPrint('文件已修改，元数据缓存无效: $filePath');
          // 删除过期缓存
          await cacheFile.delete();
          await metaFile.delete();
          return null;
        }
      }
    } catch (e) {
      debugPrint('加载元数据缓存失败: $e');
    }
    
    return null;
  }
  
  // 保存歌词缓存
  Future<bool> saveLyricsCache(String filePath, String lyrics) async {
    if (_lyricsCachePath == null) await initialize();
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_lyricsCachePath/$fileHash.lrc';
      
      final cacheFile = File(cacheFilePath);
      await cacheFile.writeAsString(lyrics);
      
      debugPrint('保存歌词缓存: $cacheFilePath');
      return true;
    } catch (e) {
      debugPrint('保存歌词缓存失败: $e');
      return false;
    }
  }
  
  // 加载歌词缓存
  Future<String?> loadLyricsCache(String filePath) async {
    if (_lyricsCachePath == null) await initialize();
    
    try {
      final fileHash = getFileHash(filePath);
      final cacheFilePath = '$_lyricsCachePath/$fileHash.lrc';
      
      final cacheFile = File(cacheFilePath);
      
      if (await cacheFile.exists()) {
        final lyrics = await cacheFile.readAsString();
        debugPrint('从缓存加载歌词: $cacheFilePath');
        return lyrics;
      }
    } catch (e) {
      debugPrint('加载歌词缓存失败: $e');
    }
    
    return null;
  }
  
  // 清理指定类型的缓存
  Future<void> clearCache(CacheType type) async {
    if (_baseCachePath == null) await initialize();
    
    String cachePath;
    switch (type) {
      case CacheType.cover:
        cachePath = _coverCachePath!;
        break;
      case CacheType.metadata:
        cachePath = _metadataCachePath!;
        break;
      case CacheType.lyrics:
        cachePath = _lyricsCachePath!;
        break;
      case CacheType.all:
        cachePath = _baseCachePath!;
        break;
    }
    
    try {
      final dir = Directory(cachePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('缓存已清理: $cachePath');
        
        // 如果清理所有缓存，重新创建目录结构
        if (type == CacheType.all) {
          await initialize();
        } else {
          _createDirectory(cachePath);
        }
      }
    } catch (e) {
      debugPrint('清理缓存失败: $e');
    }
  }
  
  // 获取缓存大小
  Future<int> getCacheSize(CacheType type) async {
    if (_baseCachePath == null) await initialize();
    
    String cachePath;
    switch (type) {
      case CacheType.cover:
        cachePath = _coverCachePath!;
        break;
      case CacheType.metadata:
        cachePath = _metadataCachePath!;
        break;
      case CacheType.lyrics:
        cachePath = _lyricsCachePath!;
        break;
      case CacheType.all:
        cachePath = _baseCachePath!;
        break;
    }
    
    int totalSize = 0;
    try {
      final dir = Directory(cachePath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('获取缓存大小失败: $e');
    }
    
    return totalSize;
  }
}

// 缓存类型枚举
enum CacheType {
  cover,
  metadata,
  lyrics,
  all,
} 