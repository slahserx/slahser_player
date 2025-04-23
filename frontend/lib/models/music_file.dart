import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:slahser_player/services/file_service.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../utils/media_parser.dart';
import '../utils/cache_manager.dart';

class MusicFile {
  final String id;
  final String filePath;
  final String fileName;
  final String fileExtension;
  final String title;
  final String artist;
  final String album;
  final String? lyricsPath;
  final String? coverPath;
  final String? coverUrl;  // 新增：封面URL（用于远程音乐）
  final Duration duration;
  List<int>? embeddedCoverBytes;
  List<String>? embeddedLyrics; // 存储内嵌歌词
  final int? trackNumber;
  final String? year;
  final String? genre;
  final DateTime? lastModified;
  final int? fileSize;
  bool hasEmbeddedCover;
  bool hasEmbeddedLyrics; // 是否有内嵌歌词
  bool isFavorite;
  int playCount;
  DateTime? lastPlayed;
  bool isRemote; // 新增：是否为远程音乐
  
  MusicFile({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileExtension,
    required this.title,
    required this.artist,
    required this.album,
    this.lyricsPath,
    this.coverPath,
    this.coverUrl,
    required this.duration,
    this.embeddedCoverBytes,
    this.embeddedLyrics,
    this.trackNumber,
    this.year,
    this.genre,
    this.lastModified,
    this.fileSize,
    this.hasEmbeddedCover = false,
    this.hasEmbeddedLyrics = false,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayed,
    this.isRemote = false,
  });
  
  // 获取封面图片数据
  Future<List<int>?> getCoverBytes() async {
    // 如果已经有缓存的封面数据，直接返回
    if (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty) {
      return embeddedCoverBytes;
    }
    
    // 对于远程音乐，从URL获取封面数据
    if (isRemote && coverUrl != null && coverUrl!.isNotEmpty) {
      try {
        debugPrint('🔍 从URL获取远程封面: $coverUrl');
        final response = await http.get(Uri.parse(coverUrl!)).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('获取远程封面超时');
          },
        );
        
        if (response.statusCode == 200) {
          embeddedCoverBytes = response.bodyBytes;
          hasEmbeddedCover = true;
          debugPrint('✅ 成功获取远程封面: ${embeddedCoverBytes!.length} 字节');
          return embeddedCoverBytes;
        } else {
          debugPrint('❌ 获取远程封面失败，状态码: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ 获取远程封面错误: $e');
      }
      return null;
    }
    
    // 如果embeddedCoverBytes为空但hasEmbeddedCover为true，尝试重新解析
    if (!isRemote && filePath.isNotEmpty) {
      try {
        debugPrint('🔍 尝试重新解析文件获取封面: $filePath');
        final coverBytes = await MediaParser.extractCoverImageFromFile(filePath);
        if (coverBytes != null && coverBytes.isNotEmpty) {
          debugPrint('✅ 成功重新提取封面: ${coverBytes.length} 字节');
          embeddedCoverBytes = coverBytes.toList(); // 更新缓存
          hasEmbeddedCover = true;
          return embeddedCoverBytes;
        }
      } catch (e) {
        debugPrint('⚠️ 重新提取封面失败: $e');
      }
    }
    
    return null;
  }
  
  // 获取歌词
  Future<List<String>?> getLyrics() async {
    if (hasEmbeddedLyrics && embeddedLyrics != null) {
      return embeddedLyrics;
    }
    
    if (lyricsPath != null) {
      try {
        final lyricsFile = File(lyricsPath!);
        if (await lyricsFile.exists()) {
          final lyrics = await lyricsFile.readAsLines();
          return lyrics;
        }
      } catch (e) {
        debugPrint('读取歌词文件失败: $e');
      }
    }
    
    return null;
  }
  
  // 从文件路径创建MusicFile对象
  static Future<MusicFile> fromPath(String filePath) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileExtension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    
    // 生成唯一ID，使用文件路径的哈希值
    final String id = _generateMusicFileId(filePath);
    debugPrint('为音乐文件生成ID: $id, 路径: $filePath');
    
    // 默认值
    String title = path.basenameWithoutExtension(filePath);
    String artist = '未知艺术家';
    String album = '未知专辑';
    Duration duration = const Duration(seconds: 0);
    List<int>? embeddedCoverBytes;
    List<String>? embeddedLyrics;
    int? trackNumber;
    String? year;
    String? genre;
    DateTime? lastModified;
    int? fileSize;
    bool hasEmbeddedCover = false;
    bool hasEmbeddedLyrics = false;
    
    // 获取文件信息
    try {
      final fileStat = await file.stat();
      lastModified = fileStat.modified;
      fileSize = fileStat.size;
      debugPrint('文件尺寸: $fileSize 字节');
    } catch (e) {
      debugPrint('获取文件信息失败: $e');
    }
    
    bool loadedFromCache = false;
    
    // 首先尝试从缓存中加载元数据
    final cacheManager = MusicCacheManager();
    final cachedMetadata = await cacheManager.loadMetadataCache(filePath);
    
    if (cachedMetadata != null) {
      // 从缓存中恢复基本元数据
      if (cachedMetadata['title'] != null) title = cachedMetadata['title'];
      if (cachedMetadata['artist'] != null) artist = cachedMetadata['artist'];
      if (cachedMetadata['album'] != null) album = cachedMetadata['album'];
      
      if (cachedMetadata['duration'] != null) {
        duration = Duration(milliseconds: cachedMetadata['duration']);
      }
      
      trackNumber = cachedMetadata['trackNumber'];
      year = cachedMetadata['year'];
      genre = cachedMetadata['genre'];
      
      // 尝试加载缓存的封面图片
      embeddedCoverBytes = await cacheManager.loadCoverCache(filePath);
      if (embeddedCoverBytes != null && embeddedCoverBytes.isNotEmpty) {
        hasEmbeddedCover = true;
      }
      
      debugPrint('从缓存加载元数据成功: $filePath');
      loadedFromCache = true;
    }
    
    // 如果缓存的元数据不完整，使用MediaParser解析
    if (!loadedFromCache || duration.inSeconds <= 0) {
      debugPrint('需要重新解析元数据: 缓存=${loadedFromCache}, 时长=${duration.inSeconds}');
      
      try {
        final metadata = await MediaParser.parseAudioFile(filePath);
        
        // 提取元数据
        if (metadata['title'] != null && metadata['title'].isNotEmpty) {
          title = metadata['title'];
        }
        
        if (metadata['artist'] != null && metadata['artist'].isNotEmpty) {
          artist = metadata['artist'];
        }
        
        if (metadata['album'] != null && metadata['album'].isNotEmpty) {
          album = metadata['album'];
        }
        
        if (metadata['duration'] != null && (duration.inSeconds <= 0 || metadata['duration'].inSeconds > 0)) {
          duration = metadata['duration'];
        }
        
        if (metadata['trackNumber'] != null) trackNumber = metadata['trackNumber'];
        if (metadata['year'] != null) year = metadata['year'];
        if (metadata['genre'] != null) genre = metadata['genre'];
        
        // 处理封面图片
        if (metadata['coverBytes'] != null && metadata['coverBytes'].isNotEmpty) {
          embeddedCoverBytes = metadata['coverBytes'];
          hasEmbeddedCover = true;
          
          // 缓存封面图片
          await cacheManager.saveCoverCache(filePath, embeddedCoverBytes!);
        }
        
        // 处理歌词
        if (metadata['lyrics'] != null && metadata['lyrics'].isNotEmpty) {
          embeddedLyrics = [metadata['lyrics']];
          hasEmbeddedLyrics = true;
        }
        
        // 缓存元数据
        final metadataToCache = {
          'title': title,
          'artist': artist,
          'album': album,
          'duration': duration.inMilliseconds,
          'trackNumber': trackNumber,
          'year': year,
          'genre': genre,
        };
        
        await cacheManager.saveMetadataCache(filePath, metadataToCache);
        
        debugPrint('解析完成并缓存: $title - $artist, 时长: ${duration.inSeconds}秒, 封面: $hasEmbeddedCover');
      } catch (e) {
        debugPrint('MediaParser解析失败: $e');
      }
    }
    
    // 特殊情况处理 - 如果标题以"-"结尾，移除它
    if (title.endsWith(" -")) {
      title = title.substring(0, title.length - 2).trim();
    }
    
    // 确保路径是存在的文件路径
    if (filePath.isEmpty || !await File(filePath).exists()) {
      throw Exception('文件不存在: $filePath');
    }
    
    // 如果封面为空，尝试再次提取
    if (!hasEmbeddedCover || embeddedCoverBytes == null) {
      final coverBytes = await MediaParser.extractCoverImageFromFile(filePath);
      if (coverBytes != null && coverBytes.isNotEmpty) {
        embeddedCoverBytes = coverBytes.toList();
        hasEmbeddedCover = true;
        
        // 缓存封面图片
        await cacheManager.saveCoverCache(filePath, embeddedCoverBytes);
        debugPrint('成功提取并缓存封面: ${embeddedCoverBytes.length} 字节');
      }
    }
    
    return MusicFile(
      id: id,
      filePath: filePath,
      fileName: fileName,
      fileExtension: fileExtension,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      embeddedCoverBytes: embeddedCoverBytes,
      embeddedLyrics: embeddedLyrics,
      trackNumber: trackNumber,
      year: year,
      genre: genre,
      lastModified: lastModified,
      fileSize: fileSize,
      hasEmbeddedCover: hasEmbeddedCover,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      isRemote: false,
    );
  }
  
  // 创建MusicFile副本
  MusicFile copy({
    String? id,
    String? filePath,
    String? fileName,
    String? fileExtension,
    String? title,
    String? artist,
    String? album,
    String? lyricsPath,
    String? coverPath,
    String? coverUrl,
    Duration? duration,
    List<int>? embeddedCoverBytes,
    List<String>? embeddedLyrics,
    int? trackNumber,
    String? year,
    String? genre,
    DateTime? lastModified,
    int? fileSize,
    bool? hasEmbeddedCover,
    bool? hasEmbeddedLyrics,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    bool? isRemote,
  }) {
    return MusicFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      embeddedCoverBytes: embeddedCoverBytes ?? this.embeddedCoverBytes,
      embeddedLyrics: embeddedLyrics ?? this.embeddedLyrics,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      lastModified: lastModified ?? this.lastModified,
      fileSize: fileSize ?? this.fileSize,
      hasEmbeddedCover: hasEmbeddedCover ?? this.hasEmbeddedCover,
      hasEmbeddedLyrics: hasEmbeddedLyrics ?? this.hasEmbeddedLyrics,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      isRemote: isRemote ?? this.isRemote,
    );
  }
  
  // 生成音乐文件的唯一ID
  static String _generateMusicFileId(String filePath) {
    // 规范化路径（统一路径分隔符，小写处理）
    final normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    
    // 使用路径生成一个哈希，然后取前8位作为ID前缀
    final bytes = utf8.encode(normalizedPath);
    final digest = sha1.convert(bytes);
    final hashString = digest.toString().substring(0, 8);
    
    // 返回带有前缀的ID
    return 'music-$hashString';
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration.inMilliseconds,
      'hasEmbeddedCover': hasEmbeddedCover,
      'hasEmbeddedLyrics': hasEmbeddedLyrics,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'isRemote': isRemote,
    };
    
    // 添加可选字段（如果不为null）
    if (lyricsPath != null) json['lyricsPath'] = lyricsPath;
    if (coverPath != null) json['coverPath'] = coverPath;
    if (coverUrl != null) json['coverUrl'] = coverUrl;
    if (trackNumber != null) json['trackNumber'] = trackNumber;
    if (year != null) json['year'] = year;
    if (genre != null) json['genre'] = genre;
    if (lastModified != null) json['lastModified'] = lastModified!.millisecondsSinceEpoch;
    if (fileSize != null) json['fileSize'] = fileSize;
    if (lastPlayed != null) json['lastPlayed'] = lastPlayed!.millisecondsSinceEpoch;
    
    // 保存封面图片到JSON，限制大小为2MB
    if (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty) {
      if (embeddedCoverBytes!.length <= 2 * 1024 * 1024) {
        json['coverBytes'] = base64Encode(embeddedCoverBytes!);
      } else {
        debugPrint('封面图片太大 (${embeddedCoverBytes!.length}字节)，不保存到JSON中');
      }
    }
    
    // 保存歌词
    if (embeddedLyrics != null && embeddedLyrics!.isNotEmpty) {
      json['lyrics'] = embeddedLyrics;
    }
    
    return json;
  }
  
  // 从JSON创建MusicFile对象
  factory MusicFile.fromJson(Map<String, dynamic> json) {
    // 获取基本字段
    final String id = json['id'] ?? '';
    final String filePath = json['filePath'] ?? '';
    final String fileName = json['fileName'] ?? path.basename(filePath);
    final String fileExtension = json['fileExtension'] ?? path.extension(filePath).toLowerCase().replaceFirst('.', '');
    
    // 获取必需的元数据
    final String title = json['title'] ?? path.basenameWithoutExtension(filePath);
    final String artist = json['artist'] ?? '未知艺术家';
    final String album = json['album'] ?? '未知专辑';
    
    // 获取时长
    Duration duration;
    if (json['duration'] != null) {
      // 新格式：直接使用毫秒值
      duration = Duration(milliseconds: json['duration']);
    } else if (json['durationInSeconds'] != null) {
      // 旧格式：使用秒值
      duration = Duration(seconds: json['durationInSeconds']);
    } else {
      duration = const Duration(seconds: 0);
    }
    
    // 获取封面图片
    List<int>? coverBytes;
    if (json['coverBytes'] != null) {
      // 新格式：coverBytes
      try {
        coverBytes = base64Decode(json['coverBytes']);
      } catch (e) {
        debugPrint('解码封面图片失败: $e');
      }
    } else if (json['embeddedCoverBytes'] != null) {
      // 旧格式：embeddedCoverBytes
      try {
        coverBytes = base64Decode(json['embeddedCoverBytes']);
      } catch (e) {
        debugPrint('解码封面图片失败: $e');
      }
    }
    
    // 获取歌词
    List<String>? lyrics;
    if (json['lyrics'] != null) {
      // 新格式：lyrics
      lyrics = List<String>.from(json['lyrics']);
    } else if (json['embeddedLyrics'] != null) {
      // 旧格式：embeddedLyrics
      lyrics = List<String>.from(json['embeddedLyrics']);
    }
    
    // 获取其他元数据
    final int? trackNumber = json['trackNumber'];
    final String? year = json['year'];
    final String? genre = json['genre'];
    
    // 获取文件属性
    int? fileSize = json['fileSize'];
    DateTime? lastModified;
    if (json['lastModified'] != null) {
      lastModified = DateTime.fromMillisecondsSinceEpoch(json['lastModified']);
    }
    
    // 获取播放信息
    bool isFavorite = json['isFavorite'] ?? false;
    int playCount = json['playCount'] ?? 0;
    DateTime? lastPlayed;
    if (json['lastPlayed'] != null) {
      lastPlayed = DateTime.fromMillisecondsSinceEpoch(json['lastPlayed']);
    }
    
    // 检查是否有封面和歌词
    bool hasEmbeddedCover = json['hasEmbeddedCover'] ?? (coverBytes != null && coverBytes.isNotEmpty);
    bool hasEmbeddedLyrics = json['hasEmbeddedLyrics'] ?? (lyrics != null && lyrics.isNotEmpty);
    
    // 是否为远程音乐
    bool isRemote = json['isRemote'] ?? false;
    
    // 创建MusicFile对象
    return MusicFile(
      id: id,
      filePath: filePath,
      fileName: fileName,
      fileExtension: fileExtension,
      title: title,
      artist: artist,
      album: album,
      lyricsPath: json['lyricsPath'],
      coverPath: json['coverPath'],
      coverUrl: json['coverUrl'],
      duration: duration,
      embeddedCoverBytes: coverBytes,
      embeddedLyrics: lyrics,
      trackNumber: trackNumber,
      year: year,
      genre: genre,
      lastModified: lastModified,
      fileSize: fileSize,
      hasEmbeddedCover: hasEmbeddedCover,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      isFavorite: isFavorite,
      playCount: playCount,
      lastPlayed: lastPlayed,
      isRemote: isRemote,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicFile && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'MusicFile{id: $id, title: $title, artist: $artist, album: $album, isRemote: $isRemote}';
  }
} 