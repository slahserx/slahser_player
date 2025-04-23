import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// 音乐应用缓存管理器
/// 负责管理音乐文件元数据、图片、歌词和云音乐的缓存
class MusicCacheManager {
  static final MusicCacheManager _instance = MusicCacheManager._internal();
  factory MusicCacheManager() => _instance;
  
  MusicCacheManager._internal();
  
  // 缓存目录路径
  String? _baseCachePath;
  String? _dataCachePath; // 新增总数据缓存目录
  String? _coverCachePath;
  String? _metadataCachePath;
  String? _lyricsCachePath;
  String? _cloudMusicCachePath;
  
  // 内存缓存
  final Map<String, List<int>> _coverMemoryCache = {};
  final Map<String, Map<String, dynamic>> _metadataMemoryCache = {}; 
  final Map<String, String> _lyricsMemoryCache = {};
  
  // 最大内存缓存条目
  static const int _maxMemoryCacheItems = 100;
  
  // 初始化缓存目录
  Future<void> initialize() async {
    try {
      final tempDir = await getApplicationDocumentsDirectory();
      _baseCachePath = '${tempDir.path}/slahser_player_cache';
      
      // 创建总数据缓存目录
      _dataCachePath = '$_baseCachePath/data';
      
      // 所有缓存数据放在data子目录下
      _coverCachePath = '$_dataCachePath/covers';
      _metadataCachePath = '$_dataCachePath/metadata';
      _lyricsCachePath = '$_dataCachePath/lyrics';
      _cloudMusicCachePath = '$_dataCachePath/cloud_music';
      
      // 创建缓存目录结构
      _createDirectory(_baseCachePath!);
      _createDirectory(_dataCachePath!);
      _createDirectory(_coverCachePath!);
      _createDirectory(_metadataCachePath!);
      _createDirectory(_lyricsCachePath!);
      _createDirectory(_cloudMusicCachePath!);
      
      // 检查并迁移旧缓存
      await _migrateOldCache();
      
      // 清理过期缓存
      _cleanExpiredCache();
      
      debugPrint('缓存管理器初始化完成，路径: $_baseCachePath');
      debugPrint('数据缓存路径: $_dataCachePath');
    } catch (e) {
      debugPrint('初始化缓存管理器失败: $e');
    }
  }
  
  // 迁移旧版本的缓存到新目录结构
  Future<void> _migrateOldCache() async {
    try {
      // 检查旧版本的缓存目录
      final oldCoverPath = '$_baseCachePath/covers';
      final oldMetadataPath = '$_baseCachePath/metadata';
      final oldLyricsPath = '$_baseCachePath/lyrics';
      final oldCloudMusicPath = '$_baseCachePath/cloud_music';
      
      // 迁移封面缓存
      await _migrateDirectory(oldCoverPath, _coverCachePath!);
      
      // 迁移元数据缓存
      await _migrateDirectory(oldMetadataPath, _metadataCachePath!);
      
      // 迁移歌词缓存
      await _migrateDirectory(oldLyricsPath, _lyricsCachePath!);
      
      // 迁移云音乐缓存
      await _migrateDirectory(oldCloudMusicPath, _cloudMusicCachePath!);
      
      debugPrint('缓存迁移完成');
    } catch (e) {
      debugPrint('迁移旧缓存失败: $e');
    }
  }
  
  // 从旧目录迁移文件到新目录
  Future<void> _migrateDirectory(String oldPath, String newPath) async {
    final oldDir = Directory(oldPath);
    
    // 如果旧目录不存在，直接返回
    if (!await oldDir.exists()) {
      return;
    }
    
    debugPrint('迁移缓存从 $oldPath 到 $newPath');
    
    try {
      // 创建新目录（如果不存在）
      final newDir = Directory(newPath);
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }
      
      // 复制文件到新目录
      await for (final entity in oldDir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final newFilePath = path.join(newPath, fileName);
          
          // 如果新目录中不存在该文件，则复制
          if (!await File(newFilePath).exists()) {
            await entity.copy(newFilePath);
            debugPrint('已迁移文件: $fileName');
          }
        }
      }
      
      // 删除旧目录
      await oldDir.delete(recursive: true);
      debugPrint('已删除旧缓存目录: $oldPath');
    } catch (e) {
      debugPrint('迁移目录失败 $oldPath: $e');
    }
  }
  
  // 获取云音乐缓存路径
  String? getCloudMusicCachePath() {
    return _cloudMusicCachePath;
  }

  // 清理云音乐缓存目录
  Future<void> clearCloudMusicCache() async {
    if (_cloudMusicCachePath == null) await initialize();
    await _clearDirectory(_cloudMusicCachePath!);
    debugPrint('云音乐缓存已清理');
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
    return md5.convert(utf8.encode(filePath.toLowerCase())).toString();
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
      
      // 添加到内存缓存
      _coverMemoryCache[fileHash] = List<int>.from(imageData);
      _limitMemoryCacheSize(_coverMemoryCache, _maxMemoryCacheItems);
      
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
      
      // 先从内存缓存中查找
      if (_coverMemoryCache.containsKey(fileHash)) {
        return List<int>.from(_coverMemoryCache[fileHash]!);
      }
      
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
          
          // 添加到内存缓存
          _coverMemoryCache[fileHash] = List<int>.from(imageData);
          _limitMemoryCacheSize(_coverMemoryCache, _maxMemoryCacheItems);
          
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
      
      // 添加到内存缓存
      _metadataMemoryCache[fileHash] = Map<String, dynamic>.from(metadata);
      _limitMemoryCacheSize(_metadataMemoryCache, _maxMemoryCacheItems);
      
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
      
      // 先从内存缓存中查找
      if (_metadataMemoryCache.containsKey(fileHash)) {
        return Map<String, dynamic>.from(_metadataMemoryCache[fileHash]!);
      }
      
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
          
          // 添加到内存缓存
          _metadataMemoryCache[fileHash] = Map<String, dynamic>.from(metadata);
          _limitMemoryCacheSize(_metadataMemoryCache, _maxMemoryCacheItems);
          
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
      
      // 添加到内存缓存
      _lyricsMemoryCache[fileHash] = lyrics;
      _limitMemoryCacheSize(_lyricsMemoryCache, _maxMemoryCacheItems);
      
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
      
      // 先从内存缓存中查找
      if (_lyricsMemoryCache.containsKey(fileHash)) {
        return _lyricsMemoryCache[fileHash];
      }
      
      final cacheFilePath = '$_lyricsCachePath/$fileHash.lrc';
      
      final cacheFile = File(cacheFilePath);
      
      if (await cacheFile.exists()) {
        final lyrics = await cacheFile.readAsString();
        
        // 添加到内存缓存
        _lyricsMemoryCache[fileHash] = lyrics;
        _limitMemoryCacheSize(_lyricsMemoryCache, _maxMemoryCacheItems);
        
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
    
    try {
      switch (type) {
        case CacheType.cover:
          _coverMemoryCache.clear();
          await _clearDirectory(_coverCachePath!);
          break;
        case CacheType.metadata:
          _metadataMemoryCache.clear();
          await _clearDirectory(_metadataCachePath!);
          break;
        case CacheType.lyrics:
          _lyricsMemoryCache.clear();
          await _clearDirectory(_lyricsCachePath!);
          break;
        case CacheType.cloudMusic:
          await _clearDirectory(_cloudMusicCachePath!);
          break;
        case CacheType.all:
          _coverMemoryCache.clear();
          _metadataMemoryCache.clear();
          _lyricsMemoryCache.clear();
          await _clearDirectory(_dataCachePath!);
          
          // 重建目录结构
          _createDirectory(_coverCachePath!);
          _createDirectory(_metadataCachePath!);
          _createDirectory(_lyricsCachePath!);
          _createDirectory(_cloudMusicCachePath!);
          break;
      }
      
      debugPrint('缓存已清理: ${type.toString()}');
      
    } catch (e) {
      debugPrint('清理缓存失败: $e');
    }
  }
  
  // 清空目录下的所有文件
  Future<void> _clearDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        await entity.delete();
      }
    }
  }
  
  // 获取缓存大小
  Future<int> getCacheSize(CacheType type) async {
    if (_baseCachePath == null) await initialize();
    
    int totalSize = 0;
    try {
      switch (type) {
        case CacheType.cover:
          totalSize = await _getDirectorySize(_coverCachePath!);
          break;
        case CacheType.metadata:
          totalSize = await _getDirectorySize(_metadataCachePath!);
          break;
        case CacheType.lyrics:
          totalSize = await _getDirectorySize(_lyricsCachePath!);
          break;
        case CacheType.cloudMusic:
          totalSize = await _getDirectorySize(_cloudMusicCachePath!);
          break;
        case CacheType.all:
          totalSize = await _getDirectorySize(_dataCachePath!);
          break;
      }
    } catch (e) {
      debugPrint('获取缓存大小失败: $e');
    }
    
    return totalSize;
  }
  
  // 获取目录大小
  Future<int> _getDirectorySize(String dirPath) async {
    int totalSize = 0;
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('获取目录大小失败: $e');
    }
    
    return totalSize;
  }
  
  // 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    try {
      // 清理一周前的缓存
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      await _cleanOldFilesInDirectory(_coverCachePath!, oneWeekAgo);
      await _cleanOldFilesInDirectory(_metadataCachePath!, oneWeekAgo);
      await _cleanOldFilesInDirectory(_lyricsCachePath!, oneWeekAgo);
      await _cleanOldFilesInDirectory(_cloudMusicCachePath!, oneWeekAgo);
      
      debugPrint('已清理过期缓存文件');
    } catch (e) {
      debugPrint('清理过期缓存失败: $e');
    }
  }
  
  // 清理目录中的旧文件
  Future<void> _cleanOldFilesInDirectory(String dirPath, DateTime cutoffDate) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('清理目录中的旧文件失败: $e');
    }
  }
  
  // 限制内存缓存大小
  void _limitMemoryCacheSize<T>(Map<String, T> cache, int maxItems) {
    if (cache.length > maxItems) {
      // 移除最旧的条目 (简单实现：移除第一个键)
      final keyToRemove = cache.keys.first;
      cache.remove(keyToRemove);
    }
  }
}

/// 缓存类型枚举
enum CacheType {
  /// 封面缓存
  cover,
  /// 元数据缓存
  metadata,
  /// 歌词缓存
  lyrics,
  /// 云音乐缓存
  cloudMusic,
  /// 所有缓存
  all,
} 