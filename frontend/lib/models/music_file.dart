import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:slahser_player/services/file_service.dart';
import 'package:crypto/crypto.dart';

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
        
        if (embeddedCoverBytes != null && embeddedCoverBytes.isNotEmpty) {
          hasEmbeddedCover = true;
          debugPrint('MP3文件包含内嵌封面: ${embeddedCoverBytes.length} 字节');
        }
        
        if (embeddedLyrics != null && embeddedLyrics.isNotEmpty) {
          hasEmbeddedLyrics = true;
          debugPrint('MP3文件包含内嵌歌词: ${embeddedLyrics.length} 行');
        }
      } else if (fileExtension == 'flac') {
        // 使用专用方法解析FLAC元数据
        final metadata = await _readFLACMetadata(filePath);
        
        // 使用解析结果
        if (metadata['title'] != null && metadata['title'].isNotEmpty) {
          title = metadata['title'];
        }
        
        if (metadata['artist'] != null && metadata['artist'].isNotEmpty) {
          artist = metadata['artist'];
        }
        
        if (metadata['album'] != null && metadata['album'].isNotEmpty) {
          album = metadata['album'];
        }
        
        duration = metadata['duration'] ?? duration;
        embeddedCoverBytes = metadata['coverBytes'] as List<int>?;
        embeddedLyrics = metadata['lyrics'] as List<String>?;
        hasEmbeddedCover = metadata['hasEmbeddedCover'] ?? false;
        hasEmbeddedLyrics = metadata['hasEmbeddedLyrics'] ?? false;
        
      } else if (['ogg', 'wav', 'm4a', 'aac', 'wma'].contains(fileExtension)) {
        // 针对其他格式的增强元数据读取
        try {
          debugPrint('正在解析多媒体文件元数据: $filePath');
          final standardMetadata = await MetadataRetriever.fromFile(File(filePath));
          
          debugPrint('文件元数据处理: $fileName, 原始标题=${standardMetadata.trackName}, 艺术家=${standardMetadata.trackArtistNames}, 专辑=${standardMetadata.albumName}');
          
          // 基本元数据读取
          if (standardMetadata.trackName != null && standardMetadata.trackName!.isNotEmpty) {
            title = standardMetadata.trackName!;
          }
          
          if (standardMetadata.trackArtistNames != null && standardMetadata.trackArtistNames!.isNotEmpty) {
            artist = standardMetadata.trackArtistNames!.join(', ');
          }
          
          if (standardMetadata.albumName != null && standardMetadata.albumName!.isNotEmpty) {
            album = standardMetadata.albumName!;
          }
          
          duration = Duration(milliseconds: standardMetadata.trackDuration ?? 0);
          embeddedCoverBytes = standardMetadata.albumArt;
          
          // 如果获取元数据为空，尝试使用文件名解析
          if (title.isEmpty && artist == '未知艺术家') {
            debugPrint('元数据为空，尝试从文件名解析: $fileName');
            // 尝试从文件名解析艺术家和标题 (格式: 艺术家 - 标题.扩展名)
            final nameWithoutExt = path.basenameWithoutExtension(filePath);
            if (nameWithoutExt.contains('-')) {
              final parts = nameWithoutExt.split('-');
              if (parts.length >= 2) {
                // 设置默认值
                if (artist == '未知艺术家') {
                  artist = parts[0].trim();
                }
                if (title.isEmpty) {
                  title = parts.skip(1).join('-').trim();
                }
                debugPrint('已从文件名解析: 艺术家=$artist, 标题=$title');
              }
            }
          }
          
          // 尝试获取额外的元数据
          if (standardMetadata.trackNumber != null) {
            trackNumber = int.tryParse(standardMetadata.trackNumber.toString());
          }
          
          if (standardMetadata.year != null) {
            year = standardMetadata.year.toString();
          }
          
          genre = standardMetadata.genre;
          
          if (embeddedCoverBytes != null && embeddedCoverBytes.isNotEmpty) {
            hasEmbeddedCover = true;
            debugPrint('${fileExtension.toUpperCase()}文件包含内嵌封面: ${embeddedCoverBytes.length} 字节');
          }
        } catch (e) {
          debugPrint('解析多媒体文件元数据失败: $e');
          // 出错时尝试从文件名解析
          final nameWithoutExt = path.basenameWithoutExtension(filePath);
          if (nameWithoutExt.contains('-')) {
            final parts = nameWithoutExt.split('-');
            if (parts.length >= 2) {
              artist = parts[0].trim();
              title = parts.skip(1).join('-').trim();
              debugPrint('元数据解析失败，已从文件名提取: 艺术家=$artist, 标题=$title');
            }
          }
        }
      } else {
        // 使用标准元数据读取
        final metadata = await MetadataRetriever.fromFile(File(filePath));
        title = metadata.trackName ?? title;
        artist = metadata.trackArtistNames?.join(', ') ?? artist;
        album = metadata.albumName ?? album;
        duration = Duration(milliseconds: metadata.trackDuration ?? 0);
        embeddedCoverBytes = metadata.albumArt;
        
        if (embeddedCoverBytes != null && embeddedCoverBytes.isNotEmpty) {
          hasEmbeddedCover = true;
          debugPrint('媒体文件包含内嵌封面: ${embeddedCoverBytes.length} 字节');
        }
        
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
      }
    } catch (e) {
      debugPrint('读取元数据失败：$e');
    }
    
    // 从文件名提取信息（针对没有完整ID3标签的情况）
    String fileNameWithoutExt = path.basenameWithoutExtension(fileName);
    Map<String, String> fileNameInfo = _extractInfoFromFileName(fileNameWithoutExt);
    
    // 初始信息不完整时，尝试从文件名推断
    if (title == fileNameWithoutExt && fileNameInfo.containsKey('title')) {
      title = fileNameInfo['title']!;
    }
    
    if (artist == '未知艺术家' && fileNameInfo.containsKey('artist')) {
      artist = fileNameInfo['artist']!;
    }
    
    // 寻找外部封面图片
    String? coverPath;
    try {
      // 首先尝试异步方法找封面
      coverPath = await findCoverImageAsync(filePath);
      
      // 记录找到封面的情况
      if (coverPath != null) {
        debugPrint('找到外部封面图片: $coverPath');
      }
    } catch (e) {
      debugPrint('查找封面图片失败: $e');
    }
    
    // 寻找匹配的歌词文件
    String? lyricsFilePath;
    try {
      // 避免使用test.txt等测试文件作为歌词
      const List<String> validLrcExtensions = ['.lrc', '.txt'];
      
      // 首先查找同名的LRC或TXT文件
      final lyricsPath = '${filePath.substring(0, filePath.lastIndexOf('.'))}';
      
      for (final ext in validLrcExtensions) {
        final lrcFilePath = '$lyricsPath$ext';
        final lrcFile = File(lrcFilePath);
        
        if (await lrcFile.exists()) {
          // 对于txt文件，验证内容是否像歌词
          if (ext.toLowerCase() == '.txt') {
            final content = await lrcFile.readAsString();
            final sampleLines = content.split('\n').take(5).toList();
            
            // 检查是否包含类似时间标签的内容 [mm:ss.xx]
            final hasTimeTag = sampleLines.any((line) => 
                RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(line));
            
            // 如果不包含时间标签但文件名包含"test"，跳过这个文件
            if (!hasTimeTag && lrcFilePath.toLowerCase().contains('test')) {
              debugPrint('跳过可能的测试文件: $lrcFilePath');
              continue;
            }
          }
          
          lyricsFilePath = lrcFilePath;
          debugPrint('找到匹配的歌词文件: $lyricsFilePath');
          break;
        }
      }
      
      // 如果没有找到直接匹配的歌词文件，再查找同一目录下的其他可能匹配的LRC文件
      if (lyricsFilePath == null) {
        final dir = Directory(path.dirname(filePath));
        final files = await dir.list().toList();
        
        // 查找文件名包含歌曲标题或艺术家的LRC文件
        for (final entity in files) {
          if (entity is File && 
              validLrcExtensions.contains(path.extension(entity.path).toLowerCase()) &&
              !entity.path.toLowerCase().contains('test')) {  // 排除测试文件
            
            final basename = path.basenameWithoutExtension(entity.path).toLowerCase();
            
            // 检查歌词文件名是否包含歌曲标题或艺术家名称
            if ((title.isNotEmpty && basename.contains(title.toLowerCase())) ||
                (artist != '未知艺术家' && basename.contains(artist.toLowerCase()))) {
              
              // 对于txt文件，验证内容
              if (path.extension(entity.path).toLowerCase() == '.txt') {
                final content = await entity.readAsString();
                final sampleLines = content.split('\n').take(5).toList();
                
                // 检查是否包含类似时间标签的内容 [mm:ss.xx]
                final hasTimeTag = sampleLines.any((line) => 
                    RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(line));
                
                if (!hasTimeTag) {
                  continue;
                }
              }
              
              lyricsFilePath = entity.path;
              debugPrint('找到匹配的歌词文件: $lyricsFilePath');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('查找歌词文件失败: $e');
    }
    
    return MusicFile(
      id: id,
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
  
  // 确保封面数据可用，如果内存中没有但hasEmbeddedCover为true，则尝试重新加载
  Future<List<int>?> ensureCoverBytes() async {
    // 如果已经有封面数据，直接返回
    if (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty) {
      return embeddedCoverBytes;
    }
    
    // 如果标记为有内嵌封面但数据为空，尝试重新加载
    if (hasEmbeddedCover) {
      debugPrint('图片数据不在内存中但标记为有内嵌封面，尝试重新加载: $title');
      
      try {
        // 检查文件是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('文件不存在，无法重新加载封面: $filePath');
          return null;
        }
        
        // 根据文件扩展名决定加载方式
        if (fileExtension.toLowerCase() == 'mp3') {
          // 从MP3文件重新加载封面
          final metadata = await _readID3TagsFromMP3File(filePath);
          embeddedCoverBytes = metadata['coverBytes'] as List<int>?;
          if (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty) {
            debugPrint('成功从MP3文件重新加载封面: ${embeddedCoverBytes!.length} 字节');
            return embeddedCoverBytes;
          }
        } else if (fileExtension.toLowerCase() == 'flac') {
          // 从FLAC文件重新加载封面
          try {
            final standardMetadata = await MetadataRetriever.fromFile(file);
            if (standardMetadata.albumArt != null && standardMetadata.albumArt!.isNotEmpty) {
              embeddedCoverBytes = standardMetadata.albumArt;
              debugPrint('成功从FLAC文件重新加载封面: ${embeddedCoverBytes!.length} 字节');
              return embeddedCoverBytes;
            }
          } catch (e) {
            debugPrint('使用标准库从FLAC重新加载封面失败: $e');
            
            // 尝试手动加载FLAC封面
            final fileSize = await file.length();
            final headerSize = min(512 * 1024, fileSize);
            final headerData = await file.openRead(0, headerSize).toList();
            final fileHeader = Uint8List.fromList(headerData.expand((x) => x).toList());
            
            // 查找FLAC魔数 ("fLaC")
            if (fileHeader.length >= 4 && 
                fileHeader[0] == 0x66 && fileHeader[1] == 0x4C && 
                fileHeader[2] == 0x61 && fileHeader[3] == 0x43) {
              
              int offset = 4; // 跳过魔数
              bool isLastBlock = false;
              
              // 循环读取所有元数据块找PICTURE块
              while (!isLastBlock && offset < fileHeader.length - 4) {
                int blockHeader = fileHeader[offset];
                isLastBlock = (blockHeader & 0x80) != 0;
                int blockType = blockHeader & 0x7F;
                
                int blockLength = (fileHeader[offset + 1] << 16) | 
                                 (fileHeader[offset + 2] << 8) | 
                                 fileHeader[offset + 3];
                
                if (blockType == 6 && offset + 4 + blockLength <= fileHeader.length) {
                  // 找到PICTURE块，尝试提取图片
                  int pictureType = (fileHeader[offset + 4] << 24) | 
                                   (fileHeader[offset + 4 + 1] << 16) | 
                                   (fileHeader[offset + 4 + 2] << 8) | 
                                   fileHeader[offset + 4 + 3];
                  
                  int mimeLength = (fileHeader[offset + 4 + 4] << 24) | 
                                  (fileHeader[offset + 4 + 5] << 16) | 
                                  (fileHeader[offset + 4 + 6] << 8) | 
                                  fileHeader[offset + 4 + 7];
                  
                  if (mimeLength > 0 && offset + 4 + 8 + mimeLength <= offset + 4 + blockLength) {
                    int descLength = (fileHeader[offset + 4 + 8 + mimeLength] << 24) | 
                                    (fileHeader[offset + 4 + 8 + mimeLength + 1] << 16) | 
                                    (fileHeader[offset + 4 + 8 + mimeLength + 2] << 8) | 
                                    fileHeader[offset + 4 + 8 + mimeLength + 3];
                    
                    int pictureDataOffset = offset + 4 + 8 + mimeLength + 4 + descLength + 16;
                    
                    int pictureLength = (fileHeader[pictureDataOffset - 4] << 24) | 
                                       (fileHeader[pictureDataOffset - 3] << 16) | 
                                       (fileHeader[pictureDataOffset - 2] << 8) | 
                                       fileHeader[pictureDataOffset - 1];
                    
                    if (pictureLength > 0 && pictureDataOffset + pictureLength <= offset + 4 + blockLength) {
                      List<int> pictureData = fileHeader.sublist(pictureDataOffset, pictureDataOffset + pictureLength).toList();
                      
                      if (pictureData.length >= 8 && 
                          ((pictureData[0] == 0xFF && pictureData[1] == 0xD8) || // JPEG
                           (pictureData[0] == 0x89 && pictureData[1] == 0x50))) { // PNG
                        
                        embeddedCoverBytes = pictureData;
                        debugPrint('成功从FLAC PICTURE块手动重新加载封面: ${pictureData.length} 字节');
                        return embeddedCoverBytes;
                      }
                    }
                  }
                }
                
                offset += 4 + blockLength;
              }
            }
          }
        } else {
          // 从其他格式音频文件加载封面
          try {
            final standardMetadata = await MetadataRetriever.fromFile(file);
            if (standardMetadata.albumArt != null && standardMetadata.albumArt!.isNotEmpty) {
              embeddedCoverBytes = standardMetadata.albumArt;
              debugPrint('成功从音频文件重新加载封面: ${embeddedCoverBytes!.length} 字节');
              return embeddedCoverBytes;
            }
          } catch (e) {
            debugPrint('从音频文件重新加载封面失败: $e');
          }
        }
      } catch (e) {
        debugPrint('重新加载封面失败: $e');
      }
      
      debugPrint('无法重新加载封面: $title');
    }
    
    return null;
  }
  
  // 获取歌词内容（优先使用外部歌词文件，其次使用内嵌歌词）
  Future<List<String>?> getLyrics() async {
    debugPrint('获取歌词：$title, 外部歌词路径: $lyricsPath, 是否有内嵌歌词: $hasEmbeddedLyrics');
    // 优先检查外部歌词文件
    if (lyricsPath != null) {
      try {
        final file = File(lyricsPath!);
        if (await file.exists()) {
          // 读取文件内容前，检查文件大小
          final stat = await file.stat();
          if (stat.size > 10 * 1024 * 1024) { // 10MB限制
            debugPrint('歌词文件过大，跳过加载: ${stat.size} 字节');
            // 如果文件过大，考虑使用内嵌歌词
            if (hasEmbeddedLyrics && embeddedLyrics != null) {
              return embeddedLyrics;
            }
            return null;
          }
          
          // 检查文件名是否包含test
          if (lyricsPath!.toLowerCase().contains('test')) {
            final fileName = path.basename(lyricsPath!).toLowerCase();
            // 读取文件前几行，检查是否真的是歌词文件
            final content = await file.readAsString();
            final sampleLines = content.split('\n').take(5).toList();
            
            // 检查是否包含类似时间标签的内容 [mm:ss.xx]
            final hasTimeTag = sampleLines.any((line) => 
                RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(line));
                
            if (!hasTimeTag && fileName == 'test.txt') {
              debugPrint('跳过可能的测试文件: $lyricsPath');
              // 尝试使用内嵌歌词
              if (hasEmbeddedLyrics && embeddedLyrics != null) {
                return embeddedLyrics;
              }
              return null;
            }
          }
          
          // 读取歌词文件
          final String content = await file.readAsString();
          final List<String> lines = content.split('\n');
          
          // 检查是否是有效的歌词文件
          final validLyricLines = lines.where((line) {
            line = line.trim();
            // 空行跳过但不视为无效
            if (line.isEmpty) return false;
            // 检查是否包含时间标签或是纯文本歌词
            return RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(line) || !line.startsWith('[');
          }).toList();
          
          if (validLyricLines.isNotEmpty) {
            debugPrint('成功从外部文件加载歌词: $title');
            return lines;
          } else {
            debugPrint('外部歌词文件格式无效，尝试使用内嵌歌词');
          }
        }
      } catch (e) {
        debugPrint('读取外部歌词文件失败: $e');
      }
    }
    
    // 其次使用内嵌歌词
    if (hasEmbeddedLyrics && embeddedLyrics != null) {
      debugPrint('使用内嵌歌词: $title');
      return embeddedLyrics;
    }
    
    // 如果是FLAC或其他格式，尝试再次提取内嵌歌词
    if (fileExtension == 'flac') {
      try {
        final extractedLyrics = await _extractLyricsFromFlacFile(filePath);
        if (extractedLyrics != null && extractedLyrics.isNotEmpty) {
          debugPrint('成功从FLAC文件中提取内嵌歌词: $title');
          return extractedLyrics;
        }
      } catch (e) {
        debugPrint('重新提取FLAC歌词失败: $e');
      }
    }
    
    // 最后尝试从文件名生成占位歌词
    debugPrint('没有找到歌词，使用文件名作为占位歌词: $title');
    final displayTitle = title.isNotEmpty ? title : fileName;
    if (displayTitle.isNotEmpty) {
      return ['[00:00.00]$displayTitle - $artist', '[00:05.00]$album'];
    }
    
    return null;
  }
  
  // 从JSON创建MusicFile对象
  factory MusicFile.fromJson(Map<String, dynamic> json) {
    // 尝试从Base64字符串恢复封面图片数据
    List<int>? coverBytes;
    if (json['embeddedCoverBytes'] != null) {
      try {
        final String base64String = json['embeddedCoverBytes'].toString();
        if (base64String.isNotEmpty) {
          coverBytes = base64Decode(base64String);
          debugPrint('从JSON中恢复封面图片数据，大小: ${coverBytes.length} 字节，歌曲: ${json['title']}');
          
          // 验证图片数据的有效性
          if (coverBytes.length >= 8) {
            bool isValidImage = false;
            
            if ((coverBytes[0] == 0xFF && coverBytes[1] == 0xD8) || // JPEG
                (coverBytes[0] == 0x89 && coverBytes[1] == 0x50 && 
                 coverBytes[2] == 0x4E && coverBytes[3] == 0x47)) { // PNG
              isValidImage = true;
            }
            
            if (!isValidImage) {
              debugPrint('警告: 恢复的图片数据格式无效，歌曲: ${json['title']}');
              // 我们仍然保留数据，让应用尝试使用
            }
          } else {
            debugPrint('警告: 恢复的图片数据太小(${coverBytes.length}字节)，歌曲: ${json['title']}');
          }
        } else {
          debugPrint('警告: Base64字符串为空，歌曲: ${json['title']}');
        }
      } catch (e) {
        debugPrint('解码封面图片数据失败: $e，歌曲: ${json['title']}');
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
        debugPrint('从JSON中恢复内嵌歌词，行数: ${lyrics?.length ?? 0}，歌曲: ${json['title']}');
      } catch (e) {
        debugPrint('解码内嵌歌词数据失败: $e，歌曲: ${json['title']}');
      }
    }
    
    // 创建MusicFile对象
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
        final maxSize = 512 * 1024; // 从300KB增加到512KB
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
            try {
              // 如果GBK解码失败，尝试使用UTF-8
              lyrics = utf8.decode(lyricsData);
            } catch (_) {
              // 如果UTF-8也失败，回退到ISO-8859-1
              lyrics = String.fromCharCodes(lyricsData);
            }
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
            try {
              // 如果UTF-8解码失败，尝试GBK（常见于中文环境）
              lyrics = gbk.decode(lyricsData);
            } catch (_) {
              // 如果GBK也失败，回退到基本字符编码
              lyrics = String.fromCharCodes(lyricsData);
            }
          }
          break;
      }
      
      // 处理歌词文本，去除不必要的空白行和控制字符
      final processedLyrics = lyrics
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      
      // 检查是否包含时间标签 [mm:ss.xx]
      bool hasTimeTag = RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(processedLyrics);
      
      // 如果没有时间标签，检查是否需要添加
      if (!hasTimeTag) {
        debugPrint('歌词缺少时间标签，将使用简单格式');
      }
      
      return processedLyrics.trim();
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
        debugPrint('APIC帧数据长度不足: ${data.length}字节');
        return null;
      }
      
      int encoding = data[0];
      int offset = 1;
      
      // 跳过MIME类型直到遇到终止符(0)
      final initialMimeOffset = offset;
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      
      // 验证格式并跳过终止符
      if (offset >= data.length) {
        debugPrint('无效的APIC帧: 找不到MIME类型结束符');
        return null;
      }
      
      // 提取MIME类型用于调试
      final mimeType = String.fromCharCodes(data.sublist(initialMimeOffset, offset));
      debugPrint('检测到MIME类型: $mimeType');
      
      offset++; // 跳过终止符
      
      // 跳过图片类型(1字节)
      if (offset >= data.length) {
        debugPrint('无效的APIC帧: 数据不足以包含图片类型字节');
        return null;
      }
      int pictureType = data[offset];
      offset++;
      
      // 调试输出
      debugPrint('发现图片类型: $pictureType (${_getPictureTypeName(pictureType)})');
      
      // 跳过描述文本
      final initialDescOffset = offset;
      bool foundTerminator = false;
      
      if (encoding == 0 || encoding == 3) { // ISO-8859-1 或 UTF-8
        // 找到单字节终止符
        while (offset < data.length && data[offset] != 0) {
          offset++;
        }
        
        if (offset < data.length) {
          foundTerminator = true;
          offset++; // 跳过终止符
        }
      } else if (encoding == 1) { // UTF-16 with BOM
        // 检查BOM并跳过
        if (offset + 1 < data.length) {
          // 检查UTF-16 BOM (0xFF 0xFE or 0xFE 0xFF)
          bool isBomPresent = (data[offset] == 0xFF && data[offset + 1] == 0xFE) || 
                             (data[offset] == 0xFE && data[offset + 1] == 0xFF);
          
          if (isBomPresent) {
            offset += 2; // 跳过BOM
          }
          
          // 查找双字节终止符 (0x00 0x00)
          while (offset < data.length - 1) {
            if (data[offset] == 0 && data[offset + 1] == 0) {
              foundTerminator = true;
              offset += 2; // 跳过终止符
              break;
            }
            offset += 2;
          }
        }
      } else if (encoding == 2) { // UTF-16BE without BOM
        // 查找双字节终止符 (0x00 0x00)
        while (offset < data.length - 1) {
          if (data[offset] == 0 && data[offset + 1] == 0) {
            foundTerminator = true;
            offset += 2; // 跳过终止符
            break;
          }
          offset += 2;
        }
      }
      
      // 提取描述文本用于调试
      if (initialDescOffset < offset - (foundTerminator ? (encoding == 0 || encoding == 3 ? 1 : 2) : 0)) {
        final descriptionData = data.sublist(initialDescOffset, offset - (foundTerminator ? (encoding == 0 || encoding == 3 ? 1 : 2) : 0));
        String? description;
        try {
          if (encoding == 0) { // ISO-8859-1
            description = String.fromCharCodes(descriptionData);
          } else if (encoding == 3) { // UTF-8
            description = utf8.decode(descriptionData, allowMalformed: true);
          } else { // UTF-16
            description = "(UTF-16 编码描述)";
          }
          if (description.isNotEmpty) {
            debugPrint('图片描述: $description');
          }
        } catch (e) {
          debugPrint('解码图片描述失败: $e');
        }
      }
      
      // 如果没有找到终止符，但我们已经接近数据末尾，可以假设剩余部分是图片数据
      if (!foundTerminator) {
        debugPrint('警告: 未找到描述文本终止符，尝试继续处理');
        // 保守处理，确保我们有足够空间用于图片头
        if (data.length - offset < 8) {
          debugPrint('数据剩余不足以包含有效图片');
          return null;
        }
      }
      
      // 检查是否有足够的数据包含图片
      if (offset >= data.length) {
        debugPrint('无效的APIC帧: 没有图片数据');
        return null;
      }
      
      // 剩余部分是图片数据
      final imageData = data.sublist(offset);
      
      // 验证图片数据格式
      if (imageData.length >= 8) {
        // 检查常见图片格式头部标记
        bool isValidImage = false;
        String imageFormat = "未知";
        
        if (imageData[0] == 0xFF && imageData[1] == 0xD8) {
          isValidImage = true;
          imageFormat = "JPEG";
        } else if (imageData[0] == 0x89 && imageData[1] == 0x50 && 
                  imageData[2] == 0x4E && imageData[3] == 0x47) {
          isValidImage = true;
          imageFormat = "PNG";
        } else if (imageData[0] == 0x47 && imageData[1] == 0x49 && 
                  imageData[2] == 0x46 && imageData[3] == 0x38) {
          isValidImage = true;
          imageFormat = "GIF";
        } else if (imageData[0] == 0x42 && imageData[1] == 0x4D) {
          isValidImage = true;
          imageFormat = "BMP";
        } else if (imageData[0] == 0x52 && imageData[1] == 0x49 && 
                  imageData[2] == 0x46 && imageData[3] == 0x46 &&
                  imageData[8] == 0x57 && imageData[9] == 0x45 && 
                  imageData[10] == 0x42 && imageData[11] == 0x50) {
          isValidImage = true;
          imageFormat = "WebP";
        }
        
        if (isValidImage) {
          debugPrint('成功提取 $imageFormat 格式图片数据: ${imageData.length} 字节');
          
          // 限制图片大小，防止内存问题
          final maxSize = 5 * 1024 * 1024; // 5MB
          if (imageData.length > maxSize) {
            debugPrint('图片过大，截断到 $maxSize 字节');
            return imageData.sublist(0, maxSize);
          }
          
          return imageData;
        } else {
          // 尝试寻找常见图片格式的标记
          for (int i = 0; i < imageData.length - 4; i++) {
            if ((imageData[i] == 0xFF && imageData[i+1] == 0xD8) || // JPEG
                (imageData[i] == 0x89 && imageData[i+1] == 0x50 && 
                 imageData[i+2] == 0x4E && imageData[i+3] == 0x47)) { // PNG
              debugPrint('在偏移 $i 处发现图片头，尝试从此处提取');
              final validImage = imageData.sublist(i);
              
              // 限制图片大小
              final maxSize = 5 * 1024 * 1024; // 5MB
              if (validImage.length > maxSize) {
                return validImage.sublist(0, maxSize);
              }
              
              return validImage;
            }
          }
          
          final hexPrefix = imageData.take(min(16, imageData.length))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
          debugPrint('提取的数据不是有效的图片格式。头部字节: $hexPrefix...');
        }
      } else {
        debugPrint('图片数据过小，不可能是有效图片: ${imageData.length} 字节');
      }
      
      return null;
    } catch (e) {
      debugPrint('提取APIC图片数据失败: $e');
      return null;
    }
  }
  
  // 获取图片类型名称
  static String _getPictureTypeName(int type) {
    switch (type) {
      case 0: return "其他";
      case 1: return "32x32像素文件图标";
      case 2: return "其他文件图标";
      case 3: return "封面（前）";
      case 4: return "封面（背）";
      case 5: return "传单页";
      case 6: return "媒体";
      case 7: return "主导艺术家/表演者";
      case 8: return "艺术家/表演者";
      case 9: return "指挥";
      case 10: return "乐队/管弦乐队";
      case 11: return "作曲家";
      case 12: return "作词家/文本作者";
      case 13: return "录音地点";
      case 14: return "录音期间";
      case 15: return "录像";
      case 16: return "鱼/开心";
      case 17: return "表演者";
      case 18: return "作品";
      case 19: return "网页设计";
      case 20: return "官方标志";
      default: return "未知类型";
    }
  }
  
  // 从FLAC文件提取歌词
  static Future<List<String>?> _extractLyricsFromFlacFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      
      // 读取文件头部用于识别FLAC格式
      final headerBytes = await file.openRead(0, 4).toList();
      final header = Uint8List.fromList(headerBytes.expand((x) => x).toList());
      
      // 检查FLAC魔数 ("fLaC")
      if (header.length < 4 || 
          header[0] != 0x66 || header[1] != 0x4C || 
          header[2] != 0x61 || header[3] != 0x43) {
        debugPrint('不是有效的FLAC文件');
        return null;
      }
      
      // 使用flutter_media_metadata尝试获取元数据
      final metadataRetriever = await MetadataRetriever.fromFile(file);
      
      // 尝试从各种来源提取歌词
      // 1. 查看标准元数据字段
      String? lyricsContent;
      final trackName = metadataRetriever.trackName;
      final artistNames = metadataRetriever.trackArtistNames;
      final albumName = metadataRetriever.albumName;
      
      debugPrint('FLAC元数据: 标题=$trackName, 艺术家=${artistNames?.join(", ")}, 专辑=$albumName');
      
      // 2. 尝试从文件名和路径提取可能的歌词文件路径
      final directory = path.dirname(filePath);
      final baseName = path.basenameWithoutExtension(filePath);
      final possibleLyricsFiles = [
        path.join(directory, '$baseName.lrc'),
        path.join(directory, '$baseName.txt'),
      ];
      
      for (final lyricsPath in possibleLyricsFiles) {
        try {
          final lyricsFile = File(lyricsPath);
          if (await lyricsFile.exists()) {
            final content = await lyricsFile.readAsString();
            if (content.isNotEmpty && content.contains('[') && 
                RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(content)) {
              debugPrint('找到FLAC对应的外部歌词文件: $lyricsPath');
              return content.split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList();
            }
          }
        } catch (e) {
          debugPrint('读取可能的歌词文件失败: $e');
        }
      }
      
      // 3. 直接尝试在二进制数据中搜索歌词内容
      try {
        final maxReadSize = 32 * 1024; // 32KB
        final firstPortion = await file.openRead(0, maxReadSize).toList();
        final firstPortionData = Uint8List.fromList(firstPortion.expand((x) => x).toList());
        
        // 尝试从二进制数据中提取可能的歌词内容
        String? possibleLyrics = _searchForLyricsInBinaryData(firstPortionData);
        if (possibleLyrics != null && 
            possibleLyrics.contains('[') && 
            RegExp(r'\[\d{2}:\d{2}\.\d{2}\]').hasMatch(possibleLyrics)) {
          debugPrint('在FLAC二进制数据中找到可能的歌词');
          return possibleLyrics.split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('读取FLAC二进制数据失败: $e');
      }
      
      return null;
    } catch (e) {
      debugPrint('提取FLAC歌词时发生错误: $e');
      return null;
    }
  }

  // 在二进制数据中搜索歌词内容
  static String? _searchForLyricsInBinaryData(Uint8List data) {
    try {
      // 尝试不同的编码方式解码
      List<String> attemptedTexts = [];
      
      // 尝试UTF-8解码
      try {
        String utf8Text = utf8.decode(data);
        attemptedTexts.add(utf8Text);
      } catch (e) {
        // 解码失败，忽略
      }
      
      // 尝试Latin1解码
      try {
        String latin1Text = String.fromCharCodes(data);
        attemptedTexts.add(latin1Text);
      } catch (e) {
        // 解码失败，忽略
      }
      
      // 尝试GBK解码
      try {
        String gbkText = gbk.decode(data);
        attemptedTexts.add(gbkText);
      } catch (e) {
        // 解码失败，忽略
      }
      
      // 在所有解码的文本中搜索歌词
      for (final text in attemptedTexts) {
        // 寻找可能的歌词开始标记
        int lyricsStartIndex = text.indexOf('[00:');
        if (lyricsStartIndex == -1) {
          lyricsStartIndex = text.indexOf('[0:');
        }
        
        if (lyricsStartIndex != -1) {
          // 从可能的歌词开始位置截取数据
          String potentialLyrics = text.substring(lyricsStartIndex);
          
          // 找到几个连续的时间标签，确认是歌词内容
          int timeTagCount = RegExp(r'\[\d{1,2}:\d{2}\.\d{2}\]').allMatches(
              potentialLyrics.substring(0, min(potentialLyrics.length, 200))).length;
          
          if (timeTagCount >= 2) {
            // 清理并截断过长的内容
            int endIndex = potentialLyrics.indexOf('\0');
            if (endIndex != -1) {
              potentialLyrics = potentialLyrics.substring(0, endIndex);
            }
            
            // 清理无效字符
            potentialLyrics = potentialLyrics.replaceAll(RegExp(r'[\x00-\x1F]'), '');
            return potentialLyrics;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('在二进制数据中搜索歌词失败: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _readFLACMetadata(String filePath) async {
    debugPrint('使用专用方法解析FLAC元数据: $filePath');
    Map<String, dynamic> metadata = {
      'title': '',
      'artist': '',
      'album': '',
      'duration': const Duration(seconds: 0),
      'coverBytes': null,
      'lyrics': null,
      'hasEmbeddedCover': false,
      'hasEmbeddedLyrics': false
    };
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('FLAC文件不存在: $filePath');
        return metadata;
      }
      
      // 首先尝试使用flutter_media_metadata作为主要元数据和封面提取方法
      try {
        final standardMetadata = await MetadataRetriever.fromFile(file);
        
        // 保存可用的元数据
        if (standardMetadata.trackName != null && standardMetadata.trackName!.isNotEmpty) {
          metadata['title'] = standardMetadata.trackName!;
        }
        
        if (standardMetadata.trackArtistNames != null && standardMetadata.trackArtistNames!.isNotEmpty) {
          metadata['artist'] = standardMetadata.trackArtistNames!.join(', ');
        }
        
        if (standardMetadata.albumName != null && standardMetadata.albumName!.isNotEmpty) {
          metadata['album'] = standardMetadata.albumName!;
        }
        
        if (standardMetadata.trackDuration != null && standardMetadata.trackDuration! > 0) {
          metadata['duration'] = Duration(milliseconds: standardMetadata.trackDuration!);
        }
        
        // 提取封面
        if (standardMetadata.albumArt != null && standardMetadata.albumArt!.isNotEmpty) {
          metadata['coverBytes'] = standardMetadata.albumArt;
          metadata['hasEmbeddedCover'] = true;
          debugPrint('使用flutter_media_metadata成功提取FLAC封面: ${standardMetadata.albumArt!.length} 字节');
        }
      } catch (e) {
        debugPrint('使用标准库解析FLAC元数据失败: $e, 尝试手动解析');
      }
      
      // 如果标准库未能提取封面，尝试从文件中手动读取PICTURE块
      if (!metadata['hasEmbeddedCover']) {
        // 增加读取大小以确保捕获封面图片
        final fileSize = await file.length();
        final headerSize = min(512 * 1024, fileSize); // 读取前512KB用于查找PICTURE块，从128KB增加
        
        try {
          final headerData = await file.openRead(0, headerSize).toList();
          final fileHeader = Uint8List.fromList(headerData.expand((x) => x).toList());
          
          // 查找FLAC魔数 ("fLaC")
          if (fileHeader.length >= 4 && 
              fileHeader[0] == 0x66 && fileHeader[1] == 0x4C && 
              fileHeader[2] == 0x61 && fileHeader[3] == 0x43) {
            
            int offset = 4; // 跳过魔数
            bool isLastBlock = false;
            
            // 循环读取所有元数据块找PICTURE块
            while (!isLastBlock && offset < fileHeader.length - 4) {
              // 读取块头
              int blockHeader = fileHeader[offset];
              isLastBlock = (blockHeader & 0x80) != 0;
              int blockType = blockHeader & 0x7F;
              
              // 块长度 (24位大端序)
              int blockLength = (fileHeader[offset + 1] << 16) | 
                               (fileHeader[offset + 2] << 8) | 
                               fileHeader[offset + 3];
              
              // 确保我们有足够的数据读取整个块
              if (offset + 4 + blockLength > fileHeader.length) {
                break;
              }
              
              // 检查是否为PICTURE块(类型6)
              if (blockType == 6) {
                try {
                  // 图片类型 (4字节)
                  int pictureType = (fileHeader[offset + 4] << 24) | 
                                   (fileHeader[offset + 4 + 1] << 16) | 
                                   (fileHeader[offset + 4 + 2] << 8) | 
                                   fileHeader[offset + 4 + 3];
                  
                  // MIME类型长度 (4字节)
                  int mimeLength = (fileHeader[offset + 4 + 4] << 24) | 
                                  (fileHeader[offset + 4 + 5] << 16) | 
                                  (fileHeader[offset + 4 + 6] << 8) | 
                                  fileHeader[offset + 4 + 7];
                  
                  if (mimeLength > 0 && offset + 4 + 8 + mimeLength <= offset + 4 + blockLength) {
                    // MIME类型
                    Uint8List mimeData = fileHeader.sublist(offset + 4 + 8, offset + 4 + 8 + mimeLength);
                    String mimeType = utf8.decode(mimeData);
                    
                    // 描述长度 (4字节)
                    int descLength = (fileHeader[offset + 4 + 8 + mimeLength] << 24) | 
                                    (fileHeader[offset + 4 + 8 + mimeLength + 1] << 16) | 
                                    (fileHeader[offset + 4 + 8 + mimeLength + 2] << 8) | 
                                    fileHeader[offset + 4 + 8 + mimeLength + 3];
                    
                    int pictureDataOffset = offset + 4 + 8 + mimeLength + 4 + descLength + 16;
                    
                    // 图片数据长度 (4字节)
                    int pictureLength = (fileHeader[pictureDataOffset - 4] << 24) | 
                                       (fileHeader[pictureDataOffset - 3] << 16) | 
                                       (fileHeader[pictureDataOffset - 2] << 8) | 
                                       fileHeader[pictureDataOffset - 1];
                    
                    debugPrint('找到FLAC图片块: 类型=$pictureType, MIME=$mimeType, 描述长度=$descLength, 数据长度=$pictureLength');
                    
                    if (pictureLength > 0 && pictureDataOffset + pictureLength <= offset + 4 + blockLength) {
                      // 提取图片数据
                      List<int> pictureData = fileHeader.sublist(pictureDataOffset, pictureDataOffset + pictureLength).toList();
                      
                      // 验证图片数据格式
                      if (pictureData.length >= 8) {
                        bool isValidImage = false;
                        
                        if ((pictureData[0] == 0xFF && pictureData[1] == 0xD8) || // JPEG
                            (pictureData[0] == 0x89 && pictureData[1] == 0x50 && 
                             pictureData[2] == 0x4E && pictureData[3] == 0x47)) { // PNG
                          isValidImage = true;
                        }
                        
                        if (isValidImage) {
                          metadata['coverBytes'] = pictureData;
                          metadata['hasEmbeddedCover'] = true;
                          debugPrint('成功手动提取FLAC封面: $pictureLength 字节, MIME类型=$mimeType');
                          break; // 找到封面后退出循环
                        }
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('解析FLAC PICTURE块出错: $e');
                }
              }
              
              // 移动到下一个元数据块
              offset += 4 + blockLength;
            }
          }
        } catch (e) {
          debugPrint('手动提取FLAC封面失败: $e');
        }
      }
      
      // 从文件名尝试获取基本信息（如果标准库未能提取）
      if (metadata['title'].isEmpty || metadata['artist'].isEmpty) {
        final nameWithoutExt = path.basenameWithoutExtension(filePath);
        
        // 尝试从文件名解析艺术家和标题 (格式: 艺术家 - 标题.flac)
        if (nameWithoutExt.contains('-')) {
          final parts = nameWithoutExt.split('-');
          if (parts.length >= 2) {
            if (metadata['artist'].isEmpty) {
              metadata['artist'] = parts[0].trim();
            }
            if (metadata['title'].isEmpty) {
              metadata['title'] = parts.skip(1).join('-').trim();
            }
            debugPrint('从文件名解析: 艺术家=${metadata['artist']}, 标题=${metadata['title']}');
          }
        } else if (metadata['title'].isEmpty) {
          metadata['title'] = nameWithoutExt;
        }
      }
      
      // 如果没有设置时长，尝试根据文件大小估算
      if (metadata['duration'].inSeconds == 0) {
        // 粗略估计: FLAC约1MB/分钟
        final fileSize = await file.length();
        int estimatedSeconds = (fileSize / (1024 * 1024) * 60).round();
        metadata['duration'] = Duration(seconds: max(1, estimatedSeconds)); // 确保至少1秒
        debugPrint('根据文件大小估算FLAC时长: ${metadata['duration'].inSeconds}秒');
      }
      
      // 显示解析结果
      debugPrint('FLAC元数据解析完成: 标题=${metadata['title']}, 艺术家=${metadata['artist']}, 专辑=${metadata['album']}');
      debugPrint('FLAC时长: ${metadata['duration'].inSeconds}秒, 有封面=${metadata['hasEmbeddedCover']}, 有歌词=${metadata['hasEmbeddedLyrics']}');
      
      return metadata;
    } catch (e) {
      debugPrint('解析FLAC元数据失败: $e');
      return metadata;
    }
  }
} 