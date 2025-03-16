import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';

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
  final List<int>? embeddedCoverBytes;
  
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
    
    // 先从文件名提取基本信息（作为备用）
    Map<String, String> fileNameInfo = _extractInfoFromFileName(title);
    String fileNameArtist = fileNameInfo['artist'] ?? artist;
    String fileNameTitle = fileNameInfo['title'] ?? title;
    
    // 使用直接文件名解析结果作为初始值
    title = fileNameTitle;
    artist = fileNameArtist;
    
    debugPrint('尝试读取文件元数据: $filePath');
    
    // 尝试多种方式读取元数据
    bool metadataReadSuccess = false;
    
    // 方法1: 使用直接ID3标签读取（针对MP3）
    if (fileExtension.toLowerCase() == 'mp3') {
      try {
        debugPrint('尝试直接读取MP3 ID3标签...');
        Map<String, dynamic> id3Tags = await _readID3TagsFromMP3File(filePath);
        
        if (id3Tags.isNotEmpty) {
          metadataReadSuccess = true;
          
          if (id3Tags.containsKey('title') && id3Tags['title'].isNotEmpty) {
            title = id3Tags['title'];
            debugPrint('直接从ID3读取标题: $title');
          }
          
          if (id3Tags.containsKey('artist') && id3Tags['artist'].isNotEmpty) {
            artist = id3Tags['artist'];
            debugPrint('直接从ID3读取艺术家: $artist');
          }
          
          if (id3Tags.containsKey('album') && id3Tags['album'].isNotEmpty) {
            album = id3Tags['album'];
            debugPrint('直接从ID3读取专辑: $album');
          }
          
          if (id3Tags.containsKey('duration') && id3Tags['duration'] is Duration) {
            duration = id3Tags['duration'];
            debugPrint('直接从ID3读取时长: ${duration.inSeconds}秒');
          }
        }
      } catch (e) {
        debugPrint('直接ID3标签读取失败: $e');
      }
    }
    
    // 方法2: 使用flutter_media_metadata库读取元数据
    if (!metadataReadSuccess) {
      try {
        debugPrint('尝试使用flutter_media_metadata读取...');
        final metadata = await MetadataRetriever.fromFile(file);
        
        // 提取元数据 - 标题
        if (metadata.trackName != null && metadata.trackName!.isNotEmpty) {
          title = metadata.trackName!;
          metadataReadSuccess = true;
          debugPrint('成功从元数据读取标题: $title');
        }
        
        // 提取元数据 - 专辑
        if (metadata.albumName != null && metadata.albumName!.isNotEmpty) {
          album = metadata.albumName!;
          metadataReadSuccess = true;
          debugPrint('成功从元数据读取专辑: $album');
        }
        
        // 提取元数据 - 艺术家
        if (metadata.trackArtistNames != null && metadata.trackArtistNames!.isNotEmpty) {
          artist = metadata.trackArtistNames!.join(', ');
          metadataReadSuccess = true;
          debugPrint('成功从元数据读取艺术家: $artist');
        } else if (metadata.albumArtistName != null && metadata.albumArtistName!.isNotEmpty) {
          artist = metadata.albumArtistName!;
          metadataReadSuccess = true;
          debugPrint('成功从元数据读取专辑艺术家: $artist');
        }
        
        // 提取元数据 - 时长
        if (metadata.trackDuration != null && metadata.trackDuration! > 0) {
          duration = Duration(milliseconds: metadata.trackDuration!);
          metadataReadSuccess = true;
          debugPrint('成功从元数据读取时长: ${duration.inSeconds}秒');
        }
        
        // 提取内嵌封面
        if (metadata.albumArt != null && metadata.albumArt!.isNotEmpty) {
          embeddedCoverBytes = metadata.albumArt;
          debugPrint('成功读取内嵌封面图片');
        }
      } catch (e) {
        debugPrint('flutter_media_metadata读取失败: $e');
      }
    }
    
    // 方法3: 如果前两种方法失败，尝试直接从文件读取
    if (!metadataReadSuccess) {
      debugPrint('尝试备用方法读取元数据...');
      try {
        // 读取文件头部获取信息
        final fileSize = await file.length();
        
        if (fileExtension.toLowerCase() == 'mp3') {
          // 使用文件大小计算大致时长（假设128kbps的比特率）
          final bitRate = 128 * 1024; // 默认128kbps
          final estimatedSeconds = ((fileSize * 8) / bitRate).floor();
          duration = Duration(seconds: estimatedSeconds > 0 ? estimatedSeconds : 180);
          debugPrint('使用文件大小估算时长: ${duration.inSeconds}秒 (文件大小: ${fileSize}字节)');
        }
      } catch (e) {
        debugPrint('备用方法读取元数据失败: $e');
      }
    }
    
    debugPrint('最终元数据: 标题="$title", 艺术家="$artist", 专辑="$album", 时长=${duration.inSeconds}秒');
    
    // 查找歌词文件
    final lyricsPath = await findLyricsFileAsync(filePath);
    if (lyricsPath != null) {
      debugPrint('找到歌词文件: $lyricsPath');
    }
    
    // 查找封面图片
    final coverPath = await findCoverImageAsync(filePath);
    if (coverPath != null) {
      debugPrint('找到封面图片: $coverPath');
    }
    
    // 如果时长为0，设置一个默认值
    if (duration.inSeconds <= 0) {
      duration = const Duration(seconds: 180); // 3分钟
      debugPrint('时长无效，设置默认时长: 180秒');
    }
    
    return MusicFile(
      id: const Uuid().v4(),
      filePath: filePath,
      fileName: fileName,
      fileExtension: fileExtension,
      title: title.isNotEmpty ? title : path.basenameWithoutExtension(fileName),
      artist: artist.isNotEmpty ? artist : '未知艺术家',
      album: album.isNotEmpty ? album : '未知专辑',
      lyricsPath: lyricsPath,
      coverPath: coverPath,
      duration: duration,
      embeddedCoverBytes: embeddedCoverBytes,
    );
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
      if (fileSize > 10 && 
          header[0] == 0x49 && // 'I'
          header[1] == 0x44 && // 'D'
          header[2] == 0x33) { // '3'
        
        debugPrint('找到ID3v2标签标记');
        
        // 标签版本
        final id3v2Version = header[3];
        // 标签大小（不包括头部的10字节）
        final tagSize = ((header[6] & 0x7F) << 21) |
                       ((header[7] & 0x7F) << 14) |
                       ((header[8] & 0x7F) << 7) |
                       (header[9] & 0x7F);
        
        debugPrint('ID3v2版本: $id3v2Version, 标签大小: $tagSize 字节');
        
        // 读取完整标签（最大限制读取1MB，防止过大内存分配）
        if (tagSize > 0 && tagSize < min(fileSize, 1024 * 1024)) {
          try {
            final completeTagBytes = await file.openRead(10, min(fileSize, 10 + tagSize)).toList();
            final completeTag = Uint8List.fromList(completeTagBytes.expand((x) => x).toList());
            
            // 解析各种帧
            int offset = 0;
            while (offset < completeTag.length - 10) {
              // ID3v2.3+的帧头是10字节：4字节ID，4字节大小，2字节标志
              if (offset + 10 > completeTag.length) break;
              
              // 读取帧ID
              String frameId = '';
              bool validFrameId = true;
              for (int i = 0; i < 4; i++) {
                final charCode = completeTag[offset + i];
                if (charCode >= 0x20 && charCode <= 0x7E) { // 有效可打印ASCII字符
                  frameId += String.fromCharCode(charCode);
                } else {
                  validFrameId = false;
                  break;
                }
              }
              
              // 无效的帧ID，可能到达了填充区域或数据结尾
              if (!validFrameId || frameId.isEmpty) {
                break;
              }
              
              // 读取帧大小 - 防止无效数据
              int frameSize;
              if (id3v2Version >= 4) {
                // ID3v2.4使用同步安全的整数
                frameSize = ((completeTag[offset + 4] & 0x7F) << 21) |
                           ((completeTag[offset + 5] & 0x7F) << 14) |
                           ((completeTag[offset + 6] & 0x7F) << 7) |
                           (completeTag[offset + 7] & 0x7F);
              } else {
                // ID3v2.3及更早版本使用常规整数
                frameSize = (completeTag[offset + 4] << 24) |
                           (completeTag[offset + 5] << 16) |
                           (completeTag[offset + 6] << 8) |
                           completeTag[offset + 7];
              }
              
              // 帧大小检查
              if (frameSize <= 0 || frameSize > completeTag.length - offset - 10) {
                // 无效的帧大小，跳过这个帧
                offset += 1; // 只前进一个字节，尝试重新同步
                continue;
              }
              
              if (frameId.isNotEmpty && frameSize > 0 && 
                  offset + 10 + frameSize <= completeTag.length) {
                
                debugPrint('发现帧: $frameId, 大小: $frameSize 字节');
                
                // 帧内容（跳过帧头）
                if (frameSize > 1) {
                  // 第一个字节通常是文本编码
                  int encodingByte = completeTag[offset + 10];
                  final frameData = completeTag.sublist(offset + 10, offset + 10 + frameSize);
                  
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
                  } else if (['TLEN', 'TLE'].contains(frameId)) { // 时长
                    String durationStr = _decodeTextFromFrameData(frameData, frameId);
                    if (durationStr.isNotEmpty) {
                      try {
                        // 移除非数字字符
                        durationStr = durationStr.replaceAll(RegExp(r'[^0-9]'), '');
                        if (durationStr.isNotEmpty) {
                          int ms = int.parse(durationStr);
                          // 仅接受合理的时长值（最小1秒，最大10小时）
                          if (ms >= 1000 && ms < 36000000) {
                            result['duration'] = Duration(milliseconds: ms);
                            debugPrint('解析到时长: ${ms}毫秒');
                          }
                        }
                      } catch (e) {
                        debugPrint('解析时长失败: $e');
                      }
                    }
                  }
                }
              }
              
              // 移动到下一帧
              offset += 10 + frameSize;
            }
          } catch (e) {
            debugPrint('解析ID3v2标签失败: $e');
          }
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
      
      // 如果没有从ID3标签获取到时长，尝试计算MP3帧头来估算时长
      if (!result.containsKey('duration')) {
        debugPrint('尝试通过解析MP3帧头估算时长...');
        
        // 寻找第一个MP3帧的位置（跳过ID3v2标签）
        int startPos = 0;
        if (fileSize > 10 && 
            header[0] == 0x49 && // 'I'
            header[1] == 0x44 && // 'D'
            header[2] == 0x33) { // '3'
          
          final tagSize = ((header[6] & 0x7F) << 21) |
                         ((header[7] & 0x7F) << 14) |
                         ((header[8] & 0x7F) << 7) |
                         (header[9] & 0x7F);
          startPos = 10 + tagSize;
        }
        
        try {
          // 读取更多数据用于查找MP3帧
          final searchSize = min(4096, fileSize - startPos);
          final searchBytes = await file.openRead(startPos, startPos + searchSize).toList();
          final searchData = Uint8List.fromList(searchBytes.expand((x) => x).toList());
          
          // 查找MPEG帧同步标记（每个有效的MP3帧都以0xFF开头）
          for (int i = 0; i < searchData.length - 4; i++) {
            if ((searchData[i] == 0xFF) && ((searchData[i + 1] & 0xE0) == 0xE0)) {
              // 可能找到MP3帧头
              debugPrint('在偏移 ${startPos + i} 找到可能的MP3帧头');
              
              // 解析帧头信息
              final versionBits = (searchData[i + 1] & 0x18) >> 3;
              final layerBits = (searchData[i + 1] & 0x06) >> 1;
              final bitrateIndex = (searchData[i + 2] & 0xF0) >> 4;
              final samplingRateIndex = (searchData[i + 2] & 0x0C) >> 2;
              
              // 确定版本
              String version;
              switch (versionBits) {
                case 0: version = '2.5'; break;
                case 2: version = '2'; break;
                case 3: version = '1'; break;
                default: version = 'unknown';
              }
              
              // 确定层
              int layer;
              switch (layerBits) {
                case 1: layer = 3; break; // Layer III
                case 2: layer = 2; break; // Layer II
                case 3: layer = 1; break; // Layer I
                default: layer = 0;
              }
              
              debugPrint('版本: MPEG-$version, 层: $layer');
              
              // 如果是有效的MP3帧
              if (version != 'unknown' && layer > 0) {
                // 比特率表（索引 -> kbps）
                final bitrateTable = {
                  // MPEG 1, Layer III
                  '1-3': [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
                  // MPEG 2/2.5, Layer III
                  '2-3': [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
                  // MPEG 1, Layer II
                  '1-2': [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
                  // MPEG 2/2.5, Layer II
                  '2-2': [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
                  // MPEG 1, Layer I
                  '1-1': [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
                  // MPEG 2/2.5, Layer I
                  '2-1': [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
                };
                
                // 采样率表（索引 -> Hz）
                final sampleRateTable = {
                  '1': [44100, 48000, 32000],
                  '2': [22050, 24000, 16000],
                  '2.5': [11025, 12000, 8000],
                };
                
                // 获取比特率和采样率
                final bitrateKey = version == '1' ? '1-$layer' : '2-$layer';
                final bitrate = bitrateTable[bitrateKey]?[bitrateIndex] ?? 0;
                final sampleRate = sampleRateTable[version]?[samplingRateIndex] ?? 0;
                
                if (bitrate > 0 && sampleRate > 0) {
                  debugPrint('比特率: $bitrate kbps, 采样率: $sampleRate Hz');
                  
                  // 估算时长（秒）= 文件大小（位）/ 比特率（位/秒）
                  final dataSize = fileSize - startPos;
                  final estimatedSeconds = (dataSize * 8) / (bitrate * 1000);
                  
                  // 确保时长是一个合理的值
                  if (estimatedSeconds > 0 && estimatedSeconds < 10800) { // 最大3小时
                    result['duration'] = Duration(seconds: estimatedSeconds.round());
                    debugPrint('估算时长: ${estimatedSeconds.round()}秒');
                    
                    // 找到一个有效帧后退出
                    break;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('解析MP3帧头失败: $e');
        }
      }
      
      // 如果从ID3v2和MP3帧头都没有获取到时长，尝试使用文件大小粗略估算
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
          String artistPart = parts[0].trim();
          // 合并剩余部分作为标题
          String titlePart = parts.sublist(1).join(' ').trim();
          
          // 处理特殊情况
          titlePart = _cleanupTitle(titlePart);
          artistPart = _cleanupArtist(artistPart);
          
          if (artistPart.isNotEmpty) {
            result['artist'] = artistPart;
          }
          
          if (titlePart.isNotEmpty) {
            result['title'] = titlePart;
          }
          
          break;
        }
      }
    }
    
    return result;
  }
  
  // 清理标题中的常见后缀
  static String _cleanupTitle(String title) {
    // 移除常见的文件后缀和质量标记
    final suffixesToRemove = [
      '.mp3', '.flac', '.wav', '.ogg', '.m4a',
      '(320k)', '(128k)', '[320k]', '[128k]',
      '(高品质)', '(无损)', '(HQ)', '(SQ)',
      '(官方版)', '(原版)', '(Live)', '(现场)',
      '（Cover）', '(Cover)', '[Cover]',
    ];
    
    String result = title;
    for (final suffix in suffixesToRemove) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length).trim();
      }
      if (result.contains(suffix)) {
        result = result.replaceAll(suffix, '').trim();
      }
    }
    
    return result;
  }
  
  // 清理艺术家名称
  static String _cleanupArtist(String artist) {
    // 移除一些常见的前缀
    final prefixesToRemove = [
      '歌手：', '歌手:', 'Singer:', 'Singer：',
      '演唱：', '演唱:', '演唱者：', '演唱者:',
      '演唱 ', '演唱',
    ];
    
    String result = artist;
    for (final prefix in prefixesToRemove) {
      if (result.startsWith(prefix)) {
        result = result.substring(prefix.length).trim();
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
  
  // 为了兼容性保留同步版本
  static String? findCoverImage(String audioFilePath) {
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
    } catch (e) {
      debugPrint('查找封面图片失败: $e');
    }
    
    return null;
  }
  
  // 获取封面图片路径
  String? get coverImagePath => coverPath;
  
  // 判断是否有封面图片（无论内嵌或外部文件）
  bool hasCoverImage() {
    return coverPath != null || (embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty);
  }
  
  // 判断是否有内嵌封面数据
  bool hasEmbeddedCover() {
    return embeddedCoverBytes != null && embeddedCoverBytes!.isNotEmpty;
  }
  
  // 获取内存中封面数据
  List<int>? getCoverBytes() {
    return embeddedCoverBytes;
  }
  
  // 从JSON构造
  factory MusicFile.fromJson(Map<String, dynamic> json) {
    return MusicFile(
      id: json['id'] ?? const Uuid().v4(),
      filePath: json['filePath'] ?? '',
      fileName: json['fileName'] ?? '',
      fileExtension: json['fileExtension'] ?? '',
      title: json['title'] ?? '未知标题',
      artist: json['artist'] ?? '未知艺术家',
      album: json['album'] ?? '未知专辑',
      lyricsPath: json['lyricsPath'],
      coverPath: json['coverPath'],
      duration: json['durationInSeconds'] != null
          ? Duration(seconds: json['durationInSeconds'])
          : const Duration(seconds: 0),
      embeddedCoverBytes: null,
    );
  }
  
  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
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
    };
  }
  
  @override
  String toString() {
    return 'MusicFile{title: $title, artist: $artist, album: $album}';
  }
} 