import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:gbk_codec/gbk_codec.dart';

/// 用于解析和提取音频文件元数据的工具类
class MediaParser {
  // 最大封面图片大小设为10MB
  static const int maxCoverSize = 10 * 1024 * 1024;
  
  // 解析音频文件元数据
  static Future<Map<String, dynamic>> parseAudioFile(String filePath) async {
    // 基础元数据结构
    Map<String, dynamic> metadata = {
      'title': path.basenameWithoutExtension(filePath),
      'artist': '',
      'album': '',
      'duration': const Duration(seconds: 0),
      'coverBytes': null,
      'lyrics': null,
      'hasEmbeddedCover': false,
      'hasEmbeddedLyrics': false,
      'trackNumber': null,
      'year': null,
      'genre': null,
    };
    
    debugPrint('📝 开始解析媒体文件: $filePath');
    
    // 1. 尝试从文件名提取信息
    try {
      _extractFromFileName(filePath, metadata);
    } catch (e) {
      debugPrint('⚠️ 从文件名提取信息失败: $e');
    }
    
    // 2. 尝试查找外部封面和歌词文件
    try {
      await _findExternalFiles(filePath, metadata);
    } catch (e) {
      debugPrint('⚠️ 查找外部文件失败: $e');
    }
    
    // 3. 如果时长未知，根据文件大小进行估算
    try {
      if (metadata['duration'].inSeconds <= 0) {
        await _estimateDuration(filePath, metadata);
        debugPrint('📝 估算时长成功: ${metadata['duration'].inSeconds}秒');
      } else {
        debugPrint('📝 已有时长数据: ${metadata['duration'].inSeconds}秒');
      }
    } catch (e) {
      debugPrint('⚠️ 估算时长失败: $e');
      // 时长估算失败，设置一个默认值
      metadata['duration'] = const Duration(minutes: 3);
    }
    
    // 记录解析结果
    debugPrint('✅ 媒体文件解析完成: ${metadata['title']} - ${metadata['artist']}');
    debugPrint('✅ 时长: ${metadata['duration'].inSeconds}秒, 是否有封面: ${metadata['hasEmbeddedCover']}');
    
    return metadata;
  }
  
  // 从文件名解析元数据
  static void _extractFromFileName(String filePath, Map<String, dynamic> metadata) {
    // 如果元数据已存在，不尝试提取
    if (metadata['title'].isNotEmpty && metadata['artist'].isNotEmpty) {
      return;
    }
    
    final nameWithoutExt = path.basenameWithoutExtension(filePath);
    
    // 尝试从文件名解析艺术家和标题 (格式: 艺术家 - 标题)
    if (nameWithoutExt.contains('-')) {
      final parts = nameWithoutExt.split('-');
      if (parts.length >= 2) {
        if (metadata['artist'].isEmpty) {
          metadata['artist'] = parts[0].trim();
        }
        if (metadata['title'].isEmpty) {
          metadata['title'] = parts.skip(1).join('-').trim();
        }
      }
    } else if (metadata['title'].isEmpty) {
      metadata['title'] = nameWithoutExt;
    }
  }
  
  // 根据文件大小估算时长
  static Future<void> _estimateDuration(String filePath, Map<String, dynamic> metadata) async {
    if (metadata['duration'].inSeconds > 0) return;
    
    final file = File(filePath);
    if (!await file.exists()) return;
    
    final fileSize = await file.length();
    final ext = path.extension(filePath).toLowerCase();
    
    int estimatedSeconds = 0;
    switch (ext) {
      case '.flac':
        // FLAC约5-7MB/分钟（高质量）
        estimatedSeconds = (fileSize / (6 * 1024 * 1024) * 60).round();
        break;
      case '.mp3':
        // MP3约1MB/分钟（128kbps），约2MB/分钟（256kbps）
        estimatedSeconds = (fileSize / (2 * 1024 * 1024) * 60).round();
        break;
      case '.wav':
        // WAV约10MB/分钟 (44.1kHz, 16位, 立体声)
        estimatedSeconds = (fileSize / (10 * 1024 * 1024) * 60).round();
        break;
      case '.ape':
        // APE约4-8MB/分钟（取中间值6MB/分钟）
        estimatedSeconds = (fileSize / (6 * 1024 * 1024) * 60).round();
        break;
      default:
        // 通用估算，假设中等比特率
        estimatedSeconds = (fileSize / (3 * 1024 * 1024) * 60).round();
    }
    
    // 对估算值进行合理性检查
    if (estimatedSeconds > 0) {
      // 大多数歌曲不会超过15分钟，如果超过可能是估算错误
      if (estimatedSeconds > 900 && ext != '.flac' && !filePath.contains("version") && !filePath.contains("Version")) {
        // 如果估算的时长过长且不是FLAC文件或特殊版本，则限制在10分钟内
        estimatedSeconds = min(estimatedSeconds, 600);
        debugPrint('估算时长过长，调整为: $estimatedSeconds 秒');
      }
      metadata['duration'] = Duration(seconds: estimatedSeconds);
      debugPrint('根据文件大小估算时长: $estimatedSeconds 秒');
    } else {
      metadata['duration'] = const Duration(seconds: 180); // 默认3分钟
    }
  }
  
  // 查找外部封面和歌词文件
  static Future<void> _findExternalFiles(String filePath, Map<String, dynamic> metadata) async {
    final directory = path.dirname(filePath);
    final baseName = path.basenameWithoutExtension(filePath);
    
    // 查找封面文件
    if (metadata['coverBytes'] == null) {
      final possibleCoverNames = [
        '$baseName.jpg', '$baseName.jpeg', '$baseName.png',
        'cover.jpg', 'cover.jpeg', 'cover.png',
        'folder.jpg', 'folder.jpeg', 'folder.png',
        'album.jpg', 'album.jpeg', 'album.png',
      ];
      
      for (final name in possibleCoverNames) {
        final coverPath = path.join(directory, name);
        final coverFile = File(coverPath);
        if (await coverFile.exists()) {
          try {
            final bytes = await coverFile.readAsBytes();
            metadata['coverBytes'] = bytes;
            metadata['hasEmbeddedCover'] = true;
            debugPrint('找到外部封面文件: $coverPath (${bytes.length} 字节)');
            break;
          } catch (e) {
            debugPrint('读取封面文件失败: $e');
          }
        }
      }
    }
    
    // 查找歌词文件
    if (metadata['lyrics'] == null) {
      final possibleLyricNames = [
        '$baseName.lrc', '$baseName.txt',
        '${baseName}.lrc', '${baseName}.txt',
      ];
      
      for (final name in possibleLyricNames) {
        final lyricsPath = path.join(directory, name);
        final lyricsFile = File(lyricsPath);
        if (await lyricsFile.exists()) {
          try {
            final content = await lyricsFile.readAsString();
            metadata['lyrics'] = content;
            metadata['hasEmbeddedLyrics'] = true;
            debugPrint('找到外部歌词文件: $lyricsPath (${content.length} 字符)');
            break;
          } catch (e) {
            debugPrint('读取歌词文件失败: $e');
            // 尝试使用GBK编码读取
            try {
              final bytes = await lyricsFile.readAsBytes();
              final content = gbk.decode(bytes);
              metadata['lyrics'] = content;
              metadata['hasEmbeddedLyrics'] = true;
              debugPrint('使用GBK编码成功读取歌词文件: $lyricsPath');
              break;
            } catch (e2) {
              debugPrint('使用GBK编码读取歌词文件失败: $e2');
            }
          }
        }
      }
    }
  }
  
  // 获取文件哈希值用于缓存索引
  static String getFileHash(String filePath) {
    // 创建MD5哈希值作为缓存键
    return md5.convert(utf8.encode(filePath)).toString();
  }

  // 直接从文件中提取封面图片
  static Future<Uint8List?> extractCoverImageFromFile(String filePath) async {
    debugPrint('🔍 尝试提取封面: $filePath');
    
    // 查找外部封面文件
    final directory = path.dirname(filePath);
    final baseName = path.basenameWithoutExtension(filePath);
    
    final possibleCoverNames = [
      '$baseName.jpg', '$baseName.jpeg', '$baseName.png',
      'cover.jpg', 'cover.jpeg', 'cover.png',
      'folder.jpg', 'folder.jpeg', 'folder.png',
      'album.jpg', 'album.jpeg', 'album.png',
    ];
    
    for (final name in possibleCoverNames) {
      final coverPath = path.join(directory, name);
      final coverFile = File(coverPath);
      if (await coverFile.exists()) {
        try {
          final bytes = await coverFile.readAsBytes();
          if (bytes.length > 0 && bytes.length < maxCoverSize) {
            debugPrint('找到外部封面文件: $coverPath (${bytes.length} 字节)');
            return Uint8List.fromList(bytes);
          }
        } catch (e) {
          debugPrint('读取封面文件失败: $e');
        }
      }
    }
    
    return null;
  }
} 