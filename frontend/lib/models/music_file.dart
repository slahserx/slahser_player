import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:slahser_player/services/file_service.dart';

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
  });
  
  // 从文件路径创建MusicFile对象
  static Future<MusicFile> fromPath(String filePath) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final fileExtension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    
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
    } catch (e) {
      debugPrint('获取文件信息失败: $e');
    }
    
    // 尝试从媒体文件读取元数据
    try {
      if (fileExtension == 'mp3') {
        // 使用直接读取ID3标签的方法
        final metadata = await _readID3TagsFromMP3File(filePath);
        title = metadata['title'] ?? title;
        artist = metadata['artist'] ?? artist;
        album = metadata['album'] ?? album;
        duration = metadata['duration'] ?? duration;
        embeddedCoverBytes = metadata['coverBytes'] as List<int>?;
        embeddedLyrics = metadata['lyrics'] as List<String>?;
        trackNumber = metadata['trackNumber'] as int?;
        year = metadata['year'] as String?;
        genre = metadata['genre'] as String?;
        
        if (embeddedLyrics != null && embeddedLyrics.isNotEmpty) {
          hasEmbeddedLyrics = true;
          debugPrint('MP3文件包含内嵌歌词');
        }
      } else {
        // 使用标准元数据读取
        final metadata = await MetadataRetriever.fromFile(File(filePath));
        title = metadata.trackName ?? title;
        artist = metadata.trackArtistNames?.join(', ') ?? artist;
        album = metadata.albumName ?? album;
        duration = Duration(milliseconds: metadata.trackDuration ?? 0);
        embeddedCoverBytes = metadata.albumArt;
        
        // 尝试获取曲目编号
        if (metadata.trackNumber != null) {
          trackNumber = int.tryParse(metadata.trackNumber.toString());
        }
        
        // 尝试获取年份
        if (metadata.year != null) {
          year = metadata.year.toString();
        }
        
        // 尝试获取流派
        genre = metadata.genre;
        
        // 注意: flutter_media_metadata包的Metadata类不支持直接获取歌词
        // 将通过其他方式尝试获取歌词内容
      }
    } catch (e) {
      debugPrint('读取元数据失败：$e');
    }
    
    // 从文件名提取信息（针对没有完整ID3标签的情况）
    String fileNameWithoutExt = path.basenameWithoutExtension(fileName);
    Map<String, String> fileNameInfo = _extractInfoFromFileName(fileNameWithoutExt);
    
    // 初始信息不完整时，尝试从文件名推断
    if (title == fileNameWithoutExt || title.isEmpty) {
      title = fileNameInfo['title'] ?? fileNameWithoutExt;
      debugPrint('从文件名提取标题: $title');
    }
    
    if (artist == '未知艺术家' || artist.isEmpty) {
      artist = fileNameInfo['artist'] ?? '未知艺术家';
      debugPrint('从文件名提取艺术家: $artist');
    }
    
    debugPrint('最终元数据: 标题="$title", 艺术家="$artist", 专辑="$album", 时长=${duration.inSeconds}秒');
    
    // 查找歌词文件
    String? lyricsFilePath;
    try {
      final lyricsPath = '${filePath.substring(0, filePath.lastIndexOf('.'))}';
      
      // 更全面的歌词文件扩展名检查
      for (final ext in FileService.supportedLyricFormats.map((e) => '.$e')) {
        final lrcFilePath = '$lyricsPath$ext';
        if (await File(lrcFilePath).exists()) {
          debugPrint('找到歌词文件: $lrcFilePath');
          lyricsFilePath = lrcFilePath;
          break;
        }
      }
      
      // 如果在同名文件中找不到，尝试在目录中查找与歌曲标题匹配的歌词文件
      if (lyricsFilePath == null) {
        final directory = path.dirname(filePath);
        final dir = Directory(directory);
        final files = await dir.list().toList();
        
        // 准备歌曲标题的不同形式，用于匹配
        final searchTitles = [
          title.toLowerCase(),
          title.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase(),
          fileNameWithoutExt.toLowerCase()
        ];
        
        for (final entity in files) {
          if (entity is File) {
            final ext = path.extension(entity.path).toLowerCase();
            if (FileService.supportedLyricFormats.contains(ext.replaceFirst('.', ''))) {
              final basename = path.basenameWithoutExtension(entity.path).toLowerCase();
              
              // 检查是否与任何标题形式匹配
              for (final searchTitle in searchTitles) {
                if (basename.contains(searchTitle) || searchTitle.contains(basename)) {
                  lyricsFilePath = entity.path;
                  debugPrint('找到匹配的歌词文件: $lyricsFilePath');
                  break;
                }
              }
              
              if (lyricsFilePath != null) break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('查找歌词文件失败: $e');
    }
    
    // 查找专辑封面图像
    String? coverPath;
    try {
      coverPath = await _findCoverImage(filePath);
    } catch (e) {
      debugPrint('查找封面图像失败: $e');
    }
    
    // 时长如果无效，使用默认值
    if (duration.inSeconds <= 0) {
      duration = const Duration(seconds: 180); // 默认3分钟
      debugPrint('时长无效，设置默认时长: ${duration.inSeconds}秒');
    }
    
    // 检查嵌入式封面
    if (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty) {
      hasEmbeddedCover = true;
      debugPrint('成功读取内嵌封面图片');
    }
    
    // 生成稳定ID（基于文件路径）
    final fileId = _generateStableId(filePath);
    debugPrint('为文件生成稳定ID: $fileId');
    
    return MusicFile(
      id: fileId,
      filePath: filePath.replaceAll('\\', '/'),
      fileName: fileName,
      fileExtension: fileExtension,
      fileSize: fileSize ?? 0,
      title: title.isNotEmpty ? title : path.basenameWithoutExtension(fileName),
      artist: artist,
      album: album,
      duration: duration,
      coverPath: coverPath,
      embeddedCoverBytes: embeddedCoverBytes,
      embeddedLyrics: embeddedLyrics,
      hasEmbeddedCover: hasEmbeddedCover,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      trackNumber: trackNumber,
      year: year,
      genre: genre,
      lastModified: lastModified ?? DateTime.now(),
      isFavorite: false,
      playCount: 0,
      lastPlayed: null,
      lyricsPath: lyricsFilePath,
    );
  }
  
  // 生成稳定的ID (基于文件路径)
  static String generateStableId(String filePath) {
    // 规范化路径，防止不同格式导致不同的ID
    String normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    
    // 计算文件路径的哈希值
    int hashCode = normalizedPath.hashCode;
    
    // 转换为32位十六进制字符串
    String hexString = hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    
    // 格式化为类似UUID的格式
    return 'music-$hexString';
  }
  
  // 直接从MP3文件读取ID3标签
  static Future<Map<String, dynamic>> _readID3TagsFromMP3File(String filePath) async {
    Map<String, dynamic> result = {};
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      
      // 读取文件头部，寻找ID3v2标签
      final headerBytes = await file.openRead(0, 10).toList();
      final header = Uint8List.fromList(headerBytes.expand((x) => x).toList());
      
      // 读取文件尾部，寻找ID3v1标签
      final tailBytes = await file.openRead(max(0, fileSize - 128), fileSize).toList();
      final tail = Uint8List.fromList(tailBytes.expand((x) => x).toList());
      
      debugPrint('文件尺寸: $fileSize 字节');
      
      // 解析ID3v2标签（如果存在）
      if (fileSize > 10 && header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
        try {
          final version = header[3]; // 版本
          final revision = header[4]; // 修订号
          
          // 计算标签大小（7位，忽略最高位）
          final tagSize = ((header[6] & 0x7F) << 21) |
                         ((header[7] & 0x7F) << 14) |
                         ((header[8] & 0x7F) << 7) |
                         (header[9] & 0x7F);
          
          debugPrint('ID3v2标签: 版本${version}.${revision}, 大小: $tagSize 字节');
          
          // 读取整个ID3v2标签
          final maxTagSize = 1024 * 1024; // 限制最大读取大小为1MB
          final actualTagSize = tagSize > maxTagSize ? maxTagSize : tagSize;
          
          final tagBytes = await file.openRead(10, 10 + actualTagSize).toList();
          final tagData = Uint8List.fromList(tagBytes.expand((x) => x).toList());
          
          // 解析ID3v2帧
          int offset = 0;
          while (offset < tagData.length - 10) {
            // 读取帧ID
            if (tagData.length - offset < 10) break; // 确保有足够的数据读取帧头
            
            String frameId = '';
            // 确保帧ID是有效的ASCII字符
            for (int i = 0; i < 4; i++) {
              int charCode = tagData[offset + i];
              if (charCode >= 32 && charCode <= 126) { // 可打印ASCII字符
                frameId += String.fromCharCode(charCode);
              } else {
                break; // 遇到无效字符，结束帧ID读取
              }
            }
            
            // 如果帧ID无效，跳出循环
            if (frameId.length != 4) {
              break;
            }
            
            // 读取帧大小
            int frameSize = 0;
            if (version == 4) { // ID3v2.4
              frameSize = (tagData[offset + 4] << 21) |
                         (tagData[offset + 5] << 14) |
                         (tagData[offset + 6] << 7) |
                         tagData[offset + 7];
            } else { // ID3v2.3及以下
              frameSize = (tagData[offset + 4] << 24) |
                         (tagData[offset + 5] << 16) |
                         (tagData[offset + 6] << 8) |
                         tagData[offset + 7];
            }
            
            // 帧头标志
            final flags = (tagData[offset + 8] << 8) | tagData[offset + 9];
            
            // 跳过过大的帧（可能是错误数据）
            if (frameSize <= 0 || frameSize > 1024 * 1024 || offset + 10 + frameSize > tagData.length) {
              offset += 10; // 跳过帧头，继续下一帧
              continue;
            }
            
            // 提取帧数据
            final frameData = Uint8List.fromList(
              tagData.sublist(offset + 10, offset + 10 + frameSize)
            );
            
            // 根据帧ID解析内容
            if (['TIT2', 'TT2'].contains(frameId)) { // 标题
              String title = _decodeTextFromFrameData(frameData, frameId);
              if (title.isNotEmpty) {
                result['title'] = title;
                debugPrint('解析到标题: $title');
              }
            } else if (['TPE1', 'TP1'].contains(frameId)) { // 艺术家
              String artist = _decodeTextFromFrameData(frameData, frameId);
              if (artist.isNotEmpty) {
                result['artist'] = artist;
                debugPrint('解析到艺术家: $artist');
              }
            } else if (['TALB', 'TAL'].contains(frameId)) { // 专辑
              String album = _decodeTextFromFrameData(frameData, frameId);
              if (album.isNotEmpty) {
                result['album'] = album;
                debugPrint('解析到专辑: $album');
              }
            } else if (['TYER', 'TYE', 'TDRC'].contains(frameId)) { // 年份
              String year = _decodeTextFromFrameData(frameData, frameId);
              if (year.isNotEmpty) {
                result['year'] = year;
                debugPrint('解析到年份: $year');
              }
            } else if (['TCON', 'TCO'].contains(frameId)) { // 流派
              String genre = _decodeTextFromFrameData(frameData, frameId);
              if (genre.isNotEmpty) {
                result['genre'] = genre;
                debugPrint('解析到流派: $genre');
              }
            } else if (['APIC', 'PIC'].contains(frameId)) { // 内嵌封面
              try {
                List<int>? imageBytes = _extractImageFromAPICFrame(frameData, frameId);
                if (imageBytes != null) {
                  result['coverBytes'] = imageBytes;
                  debugPrint('解析到封面图片: ${imageBytes.length} 字节');
                }
              } catch (e) {
                debugPrint('解析封面图片失败: $e');
              }
            } else if (['TRCK', 'TRK'].contains(frameId)) { // 曲目编号
              String trackStr = _decodeTextFromFrameData(frameData, frameId);
              if (trackStr.isNotEmpty) {
                try {
                  // 处理可能的'1/10'格式
                  final parts = trackStr.split('/');
                  result['trackNumber'] = int.parse(parts[0]);
                  debugPrint('解析到曲目编号: ${parts[0]}');
                } catch (e) {
                  debugPrint('解析曲目编号失败: $trackStr');
                }
              }
            } else if (['USLT', 'ULT'].contains(frameId)) { // 非同步歌词
              try {
                String lyricsText = _extractLyricsFromUSLTFrame(frameData, frameId);
                if (lyricsText.isNotEmpty) {
                  // 将歌词文本按行分割并存储
                  List<String> lyrics = lyricsText.split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .toList();
                  
                  if (lyrics.isNotEmpty) {
                    result['lyrics'] = lyrics;
                    debugPrint('解析到非同步歌词: ${lyrics.length} 行');
                  }
                }
              } catch (e) {
                debugPrint('解析非同步歌词失败: $e');
              }
            } else if (['SYLT', 'SLT'].contains(frameId)) { // 同步歌词
              try {
                List<String> syncedLyrics = _extractLyricsFromSYLTFrame(frameData, frameId);
                if (syncedLyrics.isNotEmpty && !result.containsKey('lyrics')) {
                  result['lyrics'] = syncedLyrics;
                  debugPrint('解析到同步歌词: ${syncedLyrics.length} 行');
                }
              } catch (e) {
                debugPrint('解析同步歌词失败: $e');
              }
            }
            
            // 移动到下一帧
            offset += 10 + frameSize;
          }
        } catch (e) {
          debugPrint('解析ID3v2标签失败: $e');
        }
      }
      
      // 尝试解析ID3v1标签（如果存在）
      if (tail.length == 128 && 
          tail[0] == 0x54 && // 'T'
          tail[1] == 0x41 && // 'A'
          tail[2] == 0x47) { // 'G'
        
        debugPrint('找到ID3v1标签');
        
        // 只有当ID3v2没有提供信息时才使用ID3v1
        if (!result.containsKey('title')) {
          final titleBytes = tail.sublist(3, 33);
          final title = _decodeID3v1Text(titleBytes);
          if (title.isNotEmpty) {
            result['title'] = title;
            debugPrint('从ID3v1解析到标题: $title');
          }
        }
        
        if (!result.containsKey('artist')) {
          final artistBytes = tail.sublist(33, 63);
          final artist = _decodeID3v1Text(artistBytes);
          if (artist.isNotEmpty) {
            result['artist'] = artist;
            debugPrint('从ID3v1解析到艺术家: $artist');
          }
        }
        
        if (!result.containsKey('album')) {
          final albumBytes = tail.sublist(63, 93);
          final album = _decodeID3v1Text(albumBytes);
          if (album.isNotEmpty) {
            result['album'] = album;
            debugPrint('从ID3v1解析到专辑: $album');
          }
        }
      }
      
      // 如果没有从ID3v2和MP3帧头都没有获取到时长，尝试使用文件大小粗略估算
      if (!result.containsKey('duration')) {
        // 使用平均比特率估算
        final avgBitrate = 128 * 1000; // 假设平均128kbps
        final dataSize = fileSize;
        final estimatedSeconds = (dataSize * 8) / avgBitrate;
        
        // 限制在合理范围内（5秒到3小时）
        final constrainedSeconds = min(10800, max(5, estimatedSeconds.round()));
        result['duration'] = Duration(seconds: constrainedSeconds);
        debugPrint('使用文件大小粗略估算时长: ${constrainedSeconds}秒');
      }
      
    } catch (e) {
      debugPrint('读取MP3标签失败: $e');
    }
    
    return result;
  }
  
  // 解码ID3v2帧中的文本数据
  static String _decodeTextFromFrameData(Uint8List data, String frameId) {
    if (data.isEmpty) return '';
    
    try {
      // 处理Text Frame (T开头的帧如TIT2, TPE1等)
      if (frameId.startsWith('T') && frameId != 'TXXX') {
        // 第一个字节是文本编码
        int encoding = data[0];
        Uint8List textData = data.sublist(1);  // 跳过编码字节
        
        // 移除尾部的空字节
        while (textData.isNotEmpty && textData.last == 0) {
          textData = textData.sublist(0, textData.length - 1);
        }
        
        if (textData.isEmpty) return '';
        
        String result = '';
        
        switch (encoding) {
          case 0: // ISO-8859-1
            // 先尝试使用GBK解码，这可能适用于一些中文MP3
            try {
              result = gbk.decode(textData);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            // 尝试使用UTF-8解码
            try {
              result = utf8.decode(textData, allowMalformed: true);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            // 回退到ISO-8859-1
            return String.fromCharCodes(textData).trim();
            
          case 1: // UTF-16 with BOM
            if (textData.length >= 2) {
              // 检查BOM
              if (textData[0] == 0xFF && textData[1] == 0xFE) {
                // UTF-16LE (小端序)
                return _decodeUtf16Le(textData.sublist(2)).trim();
              } else if (textData[0] == 0xFE && textData[1] == 0xFF) {
                // UTF-16BE (大端序)
                return _decodeUtf16Be(textData.sublist(2)).trim();
              }
            }
            
            // 没有BOM或长度不足，尝试两种方式
            String le = _decodeUtf16Le(textData).trim();
            if (le.isNotEmpty && !le.contains('')) return le;
            
            String be = _decodeUtf16Be(textData).trim();
            if (be.isNotEmpty && !be.contains('')) return be;
            
            // 最后尝试GBK和UTF-8
            try {
              result = gbk.decode(textData);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            try {
              result = utf8.decode(textData, allowMalformed: true);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            return le.isEmpty ? be : le; // 返回较好的结果
            
          case 2: // UTF-16BE without BOM
            return _decodeUtf16Be(textData).trim();
            
          case 3: // UTF-8
            try {
              return utf8.decode(textData, allowMalformed: true).trim();
            } catch (_) {
              // 如果UTF-8解码失败，尝试GBK
              try {
                result = gbk.decode(textData);
                if (result.isNotEmpty) {
                  return result.trim();
                }
              } catch (_) {}
              
              // 最后尝试ISO-8859-1
              return String.fromCharCodes(textData).trim();
            }
            
          default: // 未知编码，尝试多种方法
            // 尝试GBK
            try {
              result = gbk.decode(textData);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            // 尝试UTF-8
            try {
              result = utf8.decode(textData, allowMalformed: true);
              if (result.isNotEmpty && !result.contains('')) {
                return result.trim();
              }
            } catch (_) {}
            
            // 尝试UTF-16 LE/BE
            String le = _decodeUtf16Le(textData).trim();
            if (le.isNotEmpty && !le.contains('')) return le;
            
            String be = _decodeUtf16Be(textData).trim();
            if (be.isNotEmpty && !be.contains('')) return be;
            
            // 回退到ISO-8859-1
            return String.fromCharCodes(textData).trim();
        }
      }
      
      // 对于其他类型的帧，尝试使用UTF-8解码
      try {
        return utf8.decode(data, allowMalformed: true).trim();
      } catch (e) {
        // 尝试使用GBK解码
        try {
          String result = gbk.decode(data);
          if (result.isNotEmpty) {
            return result.trim();
          }
        } catch (_) {}
        
        // 最后尝试ISO-8859-1
        return String.fromCharCodes(data).trim();
      }
    } catch (e) {
      debugPrint('解码ID3v2文本帧失败 ($frameId): $e');
      return '';
    }
  }
  
  // 解码UTF-16LE（小尾序）
  static String _decodeUtf16Le(Uint8List bytes) {
    try {
      // 确保字节长度是偶数
      int length = bytes.length;
      if (length % 2 != 0) {
        length -= 1;  // 截断为偶数长度
      }
      
      if (length <= 0) {
        return '';  // 空字符串
      }
      
      // 尝试使用Uint16List直接解码
      try {
        final shorts = Uint16List.view(
          bytes.buffer, 
          bytes.offsetInBytes, 
          length ~/ 2
        );
        return String.fromCharCodes(shorts);
      } catch (e) {
        // 回退到逐字符构建
        List<int> codeUnits = [];
        for (int i = 0; i < length; i += 2) {
          int codeUnit = bytes[i] | (bytes[i + 1] << 8);
          if (codeUnit >= 0 && codeUnit <= 0xFFFF) {
            codeUnits.add(codeUnit);
          }
        }
        return String.fromCharCodes(codeUnits);
      }
    } catch (e) {
      debugPrint('UTF-16LE解码错误: $e');
      return '';  // 出错时返回空字符串
    }
  }
  
  // 解码UTF-16BE（大尾序）
  static String _decodeUtf16Be(Uint8List bytes) {
    try {
      // 确保字节长度是偶数
      int length = bytes.length;
      if (length % 2 != 0) {
        length -= 1;  // 截断为偶数长度
      }
      
      if (length <= 0) {
        return '';  // 空字符串
      }
      
      // 尝试先进行字节交换，然后使用本地字节序
      List<int> swappedBytes = List<int>.filled(length, 0);
      for (int i = 0; i < length; i += 2) {
        swappedBytes[i] = bytes[i + 1];
        swappedBytes[i + 1] = bytes[i];
      }
      
      try {
        final data = Uint8List.fromList(swappedBytes);
        final shorts = Uint16List.view(
          data.buffer, 
          data.offsetInBytes, 
          length ~/ 2
        );
        return String.fromCharCodes(shorts);
      } catch (e) {
        // 回退到逐字符构建
        List<int> codeUnits = [];
        for (int i = 0; i < length; i += 2) {
          int codeUnit = (bytes[i] << 8) | bytes[i + 1];
          if (codeUnit >= 0 && codeUnit <= 0xFFFF) {
            codeUnits.add(codeUnit);
          }
        }
        return String.fromCharCodes(codeUnits);
      }
    } catch (e) {
      debugPrint('UTF-16BE解码错误: $e');
      return '';  // 出错时返回空字符串
    }
  }
  
  // 解码ID3v1标签中的文本（通常是ISO-8859-1或本地编码）
  static String _decodeID3v1Text(Uint8List data) {
    if (data.isEmpty) return '';
    
    try {
      // 删除结尾的空字节
      int endPos = data.length;
      while (endPos > 0 && data[endPos - 1] == 0) {
        endPos--;
      }
      
      if (endPos == 0) return '';
      
      // 获取有效数据
      final validData = data.sublist(0, endPos);
      
      // 首先尝试GBK/GB2312解码（常见于中文MP3）
      try {
        // 检查是否可能包含中文字符（高位字节）
        if (validData.any((b) => b > 0x7F)) {
          final result = gbk.decode(validData);
          if (result.isNotEmpty && !result.contains('')) {
            return result.trim();
          }
        }
      } catch (_) {}
      
      // 然后尝试UTF-8解码
      try {
        final result = utf8.decode(validData, allowMalformed: true);
        if (result.isNotEmpty && !result.contains('')) {
          return result.trim();
        }
      } catch (_) {}
      
      // 最后回退到ISO-8859-1（ID3v1的标准编码）
      final result = String.fromCharCodes(validData);
      return result.trim();
    } catch (e) {
      debugPrint('解码ID3v1文本失败: $e');
      return '';
    }
  }
  
  // 辅助函数：求最小值
  static int min(int a, int b) => a < b ? a : b;
  
  // 辅助函数：求最大值
  static int max(int a, int b) => a > b ? a : b;
  
  // 从文件名提取艺术家和标题信息
  static Map<String, String> _extractInfoFromFileName(String fileName) {
    Map<String, String> result = {};
    
    // 常见的分隔符模式: "艺术家 - 标题", "艺术家-标题", "艺术家_标题" 等
    final separators = [' - ', ' – ', '-', '_', '：', ':', '  '];
    
    for (final separator in separators) {
      if (fileName.contains(separator)) {
        final parts = fileName.split(separator);
        if (parts.length >= 2) {
          String firstPart = parts[0].trim();
          // 合并剩余部分作为第二部分
          String secondPart = parts.sublist(1).join(' ').trim();
          
          // 处理特殊情况
          firstPart = _cleanupText(firstPart);
          secondPart = _cleanupText(secondPart);
          
          // 判断顺序：是"艺术家-标题"还是"标题-艺术家"
          // 有些特定的艺术家，比如"周杰伦"，如果出现在第二部分，很可能是"标题-艺术家"格式
          final commonArtists = ['周杰伦', '陈奕迅', '林俊杰', '张学友', '刘德华', '王力宏', '薛之谦'];
          bool isReversed = false;
          
          // 如果第二部分是常见艺术家名，可能是颠倒的格式
          if (commonArtists.any((artist) => secondPart.contains(artist))) {
            isReversed = true;
          }
          
          // 如果文件名以中文数字或者英文数字开头（如"01 - 歌名"），则更可能是"曲号-歌名"格式
          final startsWithNumber = RegExp(r'^(\d+|[一二三四五六七八九十百]+)\s*[\.、\-_]').hasMatch(firstPart);
          if (startsWithNumber) {
            isReversed = false; // 曲号在前，不颠倒
            // 从第一部分删除序号
            firstPart = firstPart.replaceFirst(RegExp(r'^(\d+|[一二三四五六七八九十百]+)\s*[\.、\-_]\s*'), '');
          }
                    
          if (isReversed) {
            // 颠倒顺序：第二部分是艺术家，第一部分是标题
            if (secondPart.isNotEmpty) {
              result['artist'] = secondPart;
            }
            if (firstPart.isNotEmpty) {
              result['title'] = firstPart;
            }
          } else {
            // 常规顺序：第一部分是艺术家，第二部分是标题
            if (firstPart.isNotEmpty) {
              result['artist'] = firstPart;
            }
            if (secondPart.isNotEmpty) {
              result['title'] = secondPart;
            }
          }
          
          break;
        }
      }
    }
    
    return result;
  }
  
  // 清理文本（用于标题和艺术家）
  static String _cleanupText(String text) {
    // 移除常见的文件后缀和质量标记
    final suffixesToRemove = [
      '.mp3', '.flac', '.wav', '.ogg', '.m4a',
      '(320k)', '(128k)', '[320k]', '[128k]',
      '(高品质)', '(无损)', '(HQ)', '(SQ)',
      '(官方版)', '(原版)', '(Live)', '(现场)',
      '（Cover）', '(Cover)', '[Cover]',
    ];
    
    String result = text;
    for (final suffix in suffixesToRemove) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length).trim();
      }
    }
    
    return result;
  }
  
  // 查找歌词文件（异步方法）
  static Future<String?> findLyricsFileAsync(String audioFilePath) async {
    final directory = path.dirname(audioFilePath);
    final baseName = path.basenameWithoutExtension(audioFilePath);
    final lrcPath = path.join(directory, '$baseName.lrc');
    
    try {
      if (await File(lrcPath).exists()) {
        return lrcPath;
      }
      
      // 查找同名但不同大小写的lrc文件
      final dir = Directory(directory);
      final files = await dir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final name = path.basename(entity.path).toLowerCase();
          if (name == '$baseName.lrc'.toLowerCase()) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      debugPrint('查找歌词文件失败: $e');
    }
    
    return null;
  }
  
  // 查找封面图片（异步方法）
  static Future<String?> findCoverImageAsync(String audioFilePath) async {
    final directory = path.dirname(audioFilePath);
    final baseName = path.basenameWithoutExtension(audioFilePath);
    
    // 检查常见的封面文件名
    final possibleNames = [
      '$baseName.jpg',
      '$baseName.jpeg',
      '$baseName.png',
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'folder.jpg',
      'folder.jpeg',
      'folder.png',
      'album.jpg',
      'album.jpeg',
      'album.png',
    ];
    
    try {
      for (final name in possibleNames) {
        final coverPath = path.join(directory, name);
        if (await File(coverPath).exists()) {
          return coverPath;
        }
      }
      
      // 查找目录中任何图像文件
      final dir = Directory(directory);
      final files = await dir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png'].contains(ext)) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      debugPrint('查找封面图片失败: $e');
    }
    
    return null;
  }
  
  // 为了兼容性保留同步版本
  static String? findLyricsFile(String audioFilePath) {
    final directory = path.dirname(audioFilePath);
    final baseName = path.basenameWithoutExtension(audioFilePath);
    final lrcPath = path.join(directory, '$baseName.lrc');
    
    try {
    if (File(lrcPath).existsSync()) {
      return lrcPath;
      }
    } catch (e) {
      debugPrint('查找歌词文件失败: $e');
    }
    
    return null;
  }
  
  // 创建私有的封面图片查找方法
  static String? _findCoverImage(String audioFilePath) {
    final directory = path.dirname(audioFilePath);
    final baseName = path.basenameWithoutExtension(audioFilePath);
    
    // 检查常见的封面文件名
    final possibleNames = [
      '$baseName.jpg',
      '$baseName.jpeg',
      '$baseName.png',
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'folder.jpg',
      'folder.jpeg',
      'folder.png',
      'album.jpg',
      'album.jpeg',
      'album.png',
    ];
    
    try {
      for (final name in possibleNames) {
        final coverPath = path.join(directory, name);
        if (File(coverPath).existsSync()) {
          return coverPath;
        }
      }
      
      // 查找目录中任何图像文件
      final dir = Directory(directory);
      final files = dir.listSync();
      for (final entity in files) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png'].contains(ext)) {
            return entity.path;
          }
        }
      }
    } catch (e) {
      debugPrint('查找封面图片失败: $e');
    }
    
    return null;
  }
  
  // 私有的生成稳定ID方法
  static String _generateStableId(String filePath) {
    // 规范化路径，防止不同格式导致不同的ID
    String normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
    
    // 计算文件路径的哈希值
    int hashCode = normalizedPath.hashCode;
    
    // 转换为32位十六进制字符串
    String hexString = hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    
    // 格式化为类似UUID的格式
    return 'music-$hexString';
  }
  
  // 获取封面图片路径
  String? get coverImagePath => coverPath;
  
  // 判断是否有封面图片（无论内嵌或外部文件）
  bool hasCover() {
    return coverPath != null || (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty);
  }
  
  // 获取内存中封面数据
  List<int>? getCoverBytes() {
    return embeddedCoverBytes;
  }
  
  // 获取歌词内容（优先使用外部歌词文件，其次使用内嵌歌词）
  Future<List<String>?> getLyrics() async {
    // 优先检查外部歌词文件
    if (lyricsPath != null) {
      try {
        final file = File(lyricsPath!);
        if (await file.exists()) {
          final String content = await file.readAsString();
          return content.split('\n');
        }
      } catch (e) {
        debugPrint('读取外部歌词文件失败: $e');
      }
    }
    
    // 其次使用内嵌歌词
    if (hasEmbeddedLyrics && embeddedLyrics != null) {
      return embeddedLyrics;
    }
    
    return null;
  }
  
  // 从JSON创建MusicFile对象
  factory MusicFile.fromJson(Map<String, dynamic> json) {
    // 尝试从Base64字符串恢复封面图片数据
    List<int>? coverBytes;
    if (json['embeddedCoverBytes'] != null) {
      try {
        coverBytes = base64Decode(json['embeddedCoverBytes']);
        debugPrint('从JSON中恢复封面图片数据，大小: ${coverBytes.length} 字节');
      } catch (e) {
        debugPrint('解码封面图片数据失败: $e');
      }
    }
    
    // 尝试恢复内嵌歌词数据
    List<String>? lyrics;
    if (json['embeddedLyrics'] != null) {
      try {
        if (json['embeddedLyrics'] is List) {
          lyrics = (json['embeddedLyrics'] as List).cast<String>();
        } else if (json['embeddedLyrics'] is String) {
          lyrics = (json['embeddedLyrics'] as String).split('\n');
        }
        debugPrint('从JSON中恢复内嵌歌词，行数: ${lyrics?.length ?? 0}');
      } catch (e) {
        debugPrint('解码内嵌歌词数据失败: $e');
      }
    }
    
    return MusicFile(
      id: json['id'] ?? const Uuid().v4(),
      filePath: json['filePath'] ?? '',
      fileName: json['fileName'] ?? '',
      fileExtension: json['fileExtension'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '未知艺术家',
      album: json['album'] ?? '未知专辑',
      lyricsPath: json['lyricsPath'],
      coverPath: json['coverPath'],
      duration: Duration(seconds: json['durationInSeconds'] ?? 0),
      trackNumber: json['trackNumber'],
      year: json['year'],
      genre: json['genre'],
      lastModified: json['lastModified'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastModified']) : null,
      fileSize: json['fileSize'],
      hasEmbeddedCover: json['hasEmbeddedCover'] ?? false,
      hasEmbeddedLyrics: json['hasEmbeddedLyrics'] ?? false,
      embeddedLyrics: lyrics,
      isFavorite: json['isFavorite'] ?? false,
      playCount: json['playCount'] ?? 0,
      lastPlayed: json['lastPlayed'] != null ? DateTime.fromMillisecondsSinceEpoch(json['lastPlayed']) : null,
      embeddedCoverBytes: coverBytes,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'title': title,
      'artist': artist,
      'album': album,
      'lyricsPath': lyricsPath,
      'coverPath': coverPath,
      'durationInSeconds': duration.inSeconds,
      'fileSize': fileSize,
      'hasEmbeddedCover': hasEmbeddedCover,
      'hasEmbeddedLyrics': hasEmbeddedLyrics,
      'trackNumber': trackNumber,
      'year': year,
      'genre': genre,
      'isFavorite': isFavorite,
      'playCount': playCount,
    };
    
    // 添加最后修改时间和最后播放时间（如果存在）
    if (lastModified != null) {
      json['lastModified'] = lastModified!.millisecondsSinceEpoch;
    }
    
    if (lastPlayed != null) {
      json['lastPlayed'] = lastPlayed!.millisecondsSinceEpoch;
    }
    
    // 如果有内嵌封面，转换为Base64存储
    if (hasEmbeddedCover && embeddedCoverBytes != null) {
      try {
        // 限制封面大小，防止JSON过大
        final maxSize = 300 * 1024; // 300KB
        if (embeddedCoverBytes!.length > maxSize) {
          debugPrint('封面图片过大(${embeddedCoverBytes!.length}字节)，跳过存储');
        } else {
          json['embeddedCoverBytes'] = base64Encode(embeddedCoverBytes!);
        }
      } catch (e) {
        debugPrint('编码封面图片数据失败: $e');
      }
    }
    
    // 如果有内嵌歌词，同样存储
    if (hasEmbeddedLyrics && embeddedLyrics != null) {
      json['embeddedLyrics'] = embeddedLyrics;
    }
    
    return json;
  }
  
  @override
  String toString() {
    return 'MusicFile{title: $title, artist: $artist, album: $album}';
  }
  
  // 创建MusicFile的副本，包括embeddedCoverBytes
  MusicFile copy() {
    return MusicFile(
      id: id,
      filePath: filePath,
      fileName: fileName,
      fileExtension: fileExtension,
      title: title,
      artist: artist,
      album: album,
      lyricsPath: lyricsPath,
      coverPath: coverPath,
      duration: duration,
      trackNumber: trackNumber,
      year: year,
      genre: genre,
      lastModified: lastModified,
      fileSize: fileSize,
      hasEmbeddedCover: hasEmbeddedCover,
      hasEmbeddedLyrics: hasEmbeddedLyrics,
      embeddedCoverBytes: embeddedCoverBytes != null ? List<int>.from(embeddedCoverBytes!) : null,
      embeddedLyrics: embeddedLyrics != null ? List<String>.from(embeddedLyrics!) : null,
      isFavorite: isFavorite,
      playCount: playCount,
      lastPlayed: lastPlayed,
    );
  }
  
  // 覆盖重写equals
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MusicFile) return false;
    return id == other.id;
  }
  
  // 覆盖重写hashCode
  @override
  int get hashCode => id.hashCode;
  
  // 从USLT帧中提取歌词
  static String _extractLyricsFromUSLTFrame(Uint8List data, String frameId) {
    try {
      if (data.length < 4) {
        return '';
      }
      
      // USLT帧结构: 编码(1) + 语言(3) + 内容描述 + 空字节 + 歌词文本
      int encoding = data[0];
      
      // 跳过语言代码(3字节)
      int offset = 4;
      
      // 根据文本编码找到内容描述的结尾
      int contentEnd = offset;
      switch (encoding) {
        case 0: // ISO-8859-1
        case 3: // UTF-8
          while (contentEnd < data.length && data[contentEnd] != 0) {
            contentEnd++;
          }
          break;
        case 1: // UTF-16 with BOM
        case 2: // UTF-16 without BOM
          // UTF-16使用两个字节表示一个字符，寻找0x00 0x00表示结束
          while (contentEnd < data.length - 1) {
            if (data[contentEnd] == 0 && data[contentEnd + 1] == 0) {
              break;
            }
            contentEnd += 2;
          }
          break;
      }
      
      // 跳过内容描述和分隔符
      if (contentEnd >= data.length) {
        return '';
      }
      
      // 根据编码跳过分隔符
      if (encoding == 1 || encoding == 2) {
        contentEnd += 2; // UTF-16 使用两个字节的分隔符
      } else {
        contentEnd += 1; // ISO-8859-1 和 UTF-8 使用一个字节的分隔符
      }
      
      // 提取歌词文本
      if (contentEnd >= data.length) {
        return '';
      }
      
      final lyricsData = data.sublist(contentEnd);
      
      // 根据编码解码文本
      String lyrics = '';
      switch (encoding) {
        case 0: // ISO-8859-1
          try {
            // 尝试用GBK解码(常见于中文MP3)
            lyrics = gbk.decode(lyricsData);
          } catch (_) {
            lyrics = String.fromCharCodes(lyricsData);
          }
          break;
        case 1: // UTF-16 with BOM
          if (lyricsData.length >= 2) {
            if (lyricsData[0] == 0xFF && lyricsData[1] == 0xFE) {
              // UTF-16LE (小尾序)
              lyrics = _decodeUtf16Le(lyricsData.sublist(2));
            } else if (lyricsData[0] == 0xFE && lyricsData[1] == 0xFF) {
              // UTF-16BE (大尾序)
              lyrics = _decodeUtf16Be(lyricsData.sublist(2));
            } else {
              // 没有BOM，假设为LE
              lyrics = _decodeUtf16Le(lyricsData);
            }
          }
          break;
        case 2: // UTF-16BE without BOM
          lyrics = _decodeUtf16Be(lyricsData);
          break;
        case 3: // UTF-8
          try {
            lyrics = utf8.decode(lyricsData);
          } catch (_) {
            lyrics = String.fromCharCodes(lyricsData);
          }
          break;
      }
      
      return lyrics.trim();
    } catch (e) {
      debugPrint('解析USLT歌词失败: $e');
      return '';
    }
  }
  
  // 从SYLT帧中提取歌词
  static List<String> _extractLyricsFromSYLTFrame(Uint8List data, String frameId) {
    try {
      if (data.length < 7) { // 至少需要: 编码(1) + 语言(3) + 时间戳格式(1) + 内容类型(1) + 描述结束符(至少1)
        return [];
      }
      
      // SYLT帧结构: 编码(1) + 语言(3) + 时间戳格式(1) + 内容类型(1) + 内容描述 + 空字节 + 同步歌词
      int encoding = data[0];
      int timeStampFormat = data[4]; // 毫秒、帧数等
      int contentType = data[5]; // 类型: 其他、歌词、翻译等
      
      // 跳过前面的数据
      int offset = 6;
      
      // 跳过内容描述
      while (offset < data.length) {
        // 根据编码方式确定结束符
        if (encoding == 0 || encoding == 3) { // ISO/UTF-8使用单字节00作为终止符
          if (data[offset] == 0) {
            offset++;
            break;
          }
        } else { // UTF-16使用双字节0000作为终止符
          if (offset + 1 < data.length && data[offset] == 0 && data[offset + 1] == 0) {
            offset += 2;
            break;
          }
        }
        offset++;
      }
      
      // 现在offset指向歌词数据的起始位置
      List<String> lyrics = [];
      
      // 处理同步歌词
      while (offset < data.length) {
        // 寻找文本结束符
        int textEnd = offset;
        if (encoding == 0 || encoding == 3) { // ISO/UTF-8
          while (textEnd < data.length && data[textEnd] != 0) {
            textEnd++;
          }
        } else { // UTF-16
          while (textEnd < data.length - 1) {
            if (data[textEnd] == 0 && data[textEnd + 1] == 0) {
              break;
            }
            textEnd += 2;
          }
        }
        
        // 无法找到结束符，可能是数据损坏
        if (textEnd >= data.length) {
          break;
        }
        
        // 提取文本
        final textData = data.sublist(offset, textEnd);
        String text = '';
        
        // 根据编码解码文本
        switch (encoding) {
          case 0: // ISO-8859-1
            try {
              text = gbk.decode(textData);
            } catch (_) {
              text = String.fromCharCodes(textData);
            }
            break;
          case 1: // UTF-16 with BOM
            if (textData.length >= 2) {
              if (textData[0] == 0xFF && textData[1] == 0xFE) {
                text = _decodeUtf16Le(textData.sublist(2));
              } else if (textData[0] == 0xFE && textData[1] == 0xFF) {
                text = _decodeUtf16Be(textData.sublist(2));
              } else {
                text = _decodeUtf16Le(textData);
              }
            }
            break;
          case 2: // UTF-16BE without BOM
            text = _decodeUtf16Be(textData);
            break;
          case 3: // UTF-8
            try {
              text = utf8.decode(textData);
            } catch (_) {
              text = String.fromCharCodes(textData);
            }
            break;
        }
        
        if (text.isNotEmpty) {
          lyrics.add(text);
        }
        
        // 跳过文本和结束符
        if (encoding == 0 || encoding == 3) {
          offset = textEnd + 1;
        } else {
          offset = textEnd + 2;
        }
        
        // 跳过时间戳(4字节)
        if (offset + 4 <= data.length) {
          offset += 4;
        } else {
          break;
        }
      }
      
      return lyrics;
    } catch (e) {
      debugPrint('解析SYLT同步歌词失败: $e');
      return [];
    }
  }
  
  static List<int>? _extractImageFromAPICFrame(Uint8List data, String frameId) {
    try {
      if (data.length < 4) {
        return null;
      }
      
      int encoding = data[0];
      int offset = 1;
      
      // 跳过MIME类型直到遇到终止符(0)
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      
      // 跳过终止符
      offset++;
      
      // 跳过图片类型(1字节)
      offset++;
      
      // 跳过描述文本直到遇到终止符
      if (encoding == 0 || encoding == 3) { // ISO-8859-1 或 UTF-8
        while (offset < data.length && data[offset] != 0) {
          offset++;
        }
        offset++; // 跳过终止符
      } else { // UTF-16
        while (offset < data.length - 1) {
          if (data[offset] == 0 && data[offset + 1] == 0) {
            break;
          }
          offset += 2;
        }
        offset += 2; // 跳过终止符
      }
      
      // 现在 offset 指向图片数据的开始
      if (offset >= data.length) {
        return null;
      }
      
      // 返回剩余的数据作为图片
      return data.sublist(offset).toList();
    } catch (e) {
      debugPrint('解析APIC图片数据失败: $e');
      return null;
    }
  }
} 