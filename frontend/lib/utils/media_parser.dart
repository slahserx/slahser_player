import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:gbk_codec/gbk_codec.dart';
import 'package:crypto/crypto.dart';

/// 用于解析和提取音频文件元数据的工具类
/// 包含更可靠的FLAC、MP3和其他格式的元数据和封面图片提取方法
class MediaParser {
  // 最大封面图片大小设为3MB
  static const int maxCoverSize = 3 * 1024 * 1024;
  
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
    
    try {
      // 1. 使用标准库尝试提取所有格式的元数据
      try {
        await _extractWithStandardLibrary(filePath, metadata);
      } catch (e) {
        debugPrint('使用标准库提取元数据失败: $e');
      }
      
      // 2. 对于不同格式，使用特定的解析器进行补充提取
      final ext = path.extension(filePath).toLowerCase().replaceFirst('.', '');
      switch (ext) {
        case 'flac':
          await _extractFlacMetadata(filePath, metadata);
          break;
        case 'mp3':
          await _extractMp3Metadata(filePath, metadata);
          break;
        case 'wav':
          await _extractWavMetadata(filePath, metadata);
          break;
        // 可以添加更多特定格式的解析
      }
      
      // 3. 尝试从文件名提取信息
      _extractFromFileName(filePath, metadata);
      
      // 4. 如果时长仍然未知，根据文件大小进行估算
      if (metadata['duration'].inSeconds <= 0) {
        await _estimateDuration(filePath, metadata);
      }
      
      // 5. 验证图片数据
      _validateCoverData(metadata);
      
      // 6. 尝试查找外部封面和歌词文件
      await _findExternalFiles(filePath, metadata);
      
      // 记录解析结果
      debugPrint('媒体文件解析完成: ${metadata['title']} - ${metadata['artist']}');
      debugPrint('时长: ${metadata['duration'].inSeconds}秒, 是否有封面: ${metadata['hasEmbeddedCover']}');
      
      return metadata;
    } catch (e) {
      debugPrint('解析媒体文件失败: $filePath, 错误: $e');
      // 返回基础元数据，确保至少有文件名作为标题
      return metadata;
    }
  }
  
  // 使用标准库提取元数据
  static Future<void> _extractWithStandardLibrary(String filePath, Map<String, dynamic> metadata) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    
    final standardMetadata = await MetadataRetriever.fromFile(file);
    
    // 处理基本元数据
    if (standardMetadata.trackName != null && standardMetadata.trackName!.isNotEmpty) {
      metadata['title'] = standardMetadata.trackName!;
    }
    
    if (standardMetadata.trackArtistNames != null && standardMetadata.trackArtistNames!.isNotEmpty) {
      metadata['artist'] = standardMetadata.trackArtistNames!.join(', ');
    }
    
    if (standardMetadata.albumName != null && standardMetadata.albumName!.isNotEmpty) {
      metadata['album'] = standardMetadata.albumName!;
    }
    
    // 处理时长
    if (standardMetadata.trackDuration != null && standardMetadata.trackDuration! > 0) {
      metadata['duration'] = Duration(milliseconds: standardMetadata.trackDuration!);
    }
    
    // 提取封面图片
    if (standardMetadata.albumArt != null && standardMetadata.albumArt!.isNotEmpty) {
      metadata['coverBytes'] = standardMetadata.albumArt;
      metadata['hasEmbeddedCover'] = true;
      debugPrint('标准库成功提取封面: ${standardMetadata.albumArt!.length} 字节');
    }
  }
  
  // FLAC文件特定的元数据提取
  static Future<void> _extractFlacMetadata(String filePath, Map<String, dynamic> metadata) async {
    if (metadata['hasEmbeddedCover'] && metadata['coverBytes'] != null) {
      // 如果已经有封面，不再尝试提取
      return;
    }
    
    final file = File(filePath);
    if (!await file.exists()) return;
    
    final fileSize = await file.length();
    // 读取更大部分以确保能捕获大型封面
    final headerSize = min(3 * 1024 * 1024, fileSize);
    
    try {
      final headerData = await file.openRead(0, headerSize).toList();
      final fileHeader = Uint8List.fromList(headerData.expand((x) => x).toList());
      
      // 查找FLAC魔数 ("fLaC")
      if (fileHeader.length >= 4 && 
          fileHeader[0] == 0x66 && fileHeader[1] == 0x4C && 
          fileHeader[2] == 0x61 && fileHeader[3] == 0x43) {
        
        int offset = 4; // 跳过魔数
        bool isLastBlock = false;
        
        // 循环读取所有元数据块
        while (!isLastBlock && offset < fileHeader.length - 8) {
          // 读取块头
          if (offset + 4 > fileHeader.length) break;
          
          int blockHeader = fileHeader[offset];
          isLastBlock = (blockHeader & 0x80) != 0;
          int blockType = blockHeader & 0x7F;
          
          // 块长度 (24位大端序)
          int blockLength = (fileHeader[offset + 1] << 16) | 
                           (fileHeader[offset + 2] << 8) | 
                           fileHeader[offset + 3];
          
          if (blockLength <= 0 || offset + 4 + blockLength > fileHeader.length) {
            // 无效块长度或超出读取范围
            offset += 4;
            continue;
          }
          
          // 检查VORBIS_COMMENT块(类型4)
          if (blockType == 4 && metadata['title'].isEmpty) {
            try {
              // 提取VORBIS评论元数据
              int vendorLength = (fileHeader[offset + 4] | 
                                (fileHeader[offset + 5] << 8) | 
                                (fileHeader[offset + 6] << 16) | 
                                (fileHeader[offset + 7] << 24));
              
              if (vendorLength > 0 && offset + 8 + vendorLength + 4 <= offset + 4 + blockLength) {
                // 跳过vendor字符串
                int commentsOffset = offset + 8 + vendorLength;
                
                // 读取评论数量
                int commentCount = (fileHeader[commentsOffset] | 
                                   (fileHeader[commentsOffset + 1] << 8) | 
                                   (fileHeader[commentsOffset + 2] << 16) | 
                                   (fileHeader[commentsOffset + 3] << 24));
                
                int currentOffset = commentsOffset + 4;
                
                // 读取所有评论
                for (int i = 0; i < commentCount && currentOffset < offset + 4 + blockLength; i++) {
                  // 读取评论长度
                  if (currentOffset + 4 > offset + 4 + blockLength) break;
                  
                  int commentLength = (fileHeader[currentOffset] | 
                                      (fileHeader[currentOffset + 1] << 8) | 
                                      (fileHeader[currentOffset + 2] << 16) | 
                                      (fileHeader[currentOffset + 3] << 24));
                  
                  if (commentLength > 0 && currentOffset + 4 + commentLength <= offset + 4 + blockLength) {
                    // 提取评论
                    Uint8List commentData = fileHeader.sublist(currentOffset + 4, currentOffset + 4 + commentLength);
                    String comment = utf8.decode(commentData, allowMalformed: true);
                    
                    // 解析评论 (格式: "TITLE=歌曲标题")
                    if (comment.contains('=')) {
                      String key = comment.substring(0, comment.indexOf('=')).toUpperCase();
                      String value = comment.substring(comment.indexOf('=') + 1);
                      
                      switch(key) {
                        case 'TITLE':
                          if (metadata['title'].isEmpty) metadata['title'] = value;
                          break;
                        case 'ARTIST':
                          if (metadata['artist'].isEmpty) metadata['artist'] = value;
                          break;
                        case 'ALBUM':
                          if (metadata['album'].isEmpty) metadata['album'] = value;
                          break;
                        case 'DATE':
                        case 'YEAR':
                          if (metadata['year'] == null) metadata['year'] = value;
                          break;
                        case 'GENRE':
                          if (metadata['genre'] == null) metadata['genre'] = value;
                          break;
                        case 'TRACKNUMBER':
                          if (metadata['trackNumber'] == null) {
                            try {
                              metadata['trackNumber'] = int.parse(value);
                            } catch (e) {
                              // 忽略无效的轨道号
                            }
                          }
                          break;
                      }
                    }
                  }
                  
                  currentOffset += 4 + commentLength;
                }
              }
            } catch (e) {
              debugPrint('解析FLAC VORBIS评论块出错: $e');
            }
          }
          
          // 检查PICTURE块(类型6)
          if (blockType == 6 && !metadata['hasEmbeddedCover']) {
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
              
              if (mimeLength > 0 && offset + 4 + 8 + mimeLength + 8 <= offset + 4 + blockLength) {
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
                
                if (pictureLength > 0 && pictureDataOffset + pictureLength <= offset + 4 + blockLength) {
                  // 提取图片数据
                  List<int> pictureData = fileHeader.sublist(pictureDataOffset, pictureDataOffset + pictureLength).toList();
                  
                  // 检查图片签名
                  if (_isValidImageData(pictureData)) {
                    metadata['coverBytes'] = pictureData;
                    metadata['hasEmbeddedCover'] = true;
                    debugPrint('成功手动提取FLAC图片块: $pictureLength 字节, 类型=$pictureType');
                    break; // 已找到封面，退出循环
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
      debugPrint('手动解析FLAC元数据失败: $e');
    }
  }
  
  // MP3文件特定的元数据提取
  static Future<void> _extractMp3Metadata(String filePath, Map<String, dynamic> metadata) async {
    if (metadata['hasEmbeddedCover'] && metadata['coverBytes'] != null) {
      // 如果已经有封面，不再尝试提取
      return;
    }
    
    final file = File(filePath);
    if (!await file.exists()) return;
    
    try {
      // 读取文件头部以查找ID3标签
      final headerSize = min(10 * 1024 * 1024, await file.length());
      final headerData = await file.openRead(0, headerSize).toList();
      final fileHeader = Uint8List.fromList(headerData.expand((x) => x).toList());
      
      // 检查ID3v2标签
      if (fileHeader.length >= 10 && 
          fileHeader[0] == 0x49 && fileHeader[1] == 0x44 && fileHeader[2] == 0x33) {
        
        // 获取ID3标签版本
        int versionMajor = fileHeader[3];
        int versionMinor = fileHeader[4];
        
        // 获取标签大小 (去除同步字节)
        int tagSize = ((fileHeader[6] & 0x7F) << 21) | 
                     ((fileHeader[7] & 0x7F) << 14) | 
                     ((fileHeader[8] & 0x7F) << 7) | 
                     (fileHeader[9] & 0x7F);
        
        tagSize += 10; // 加上头部10字节
        
        if (tagSize <= fileHeader.length) {
          int offset = 10; // 跳过标签头
          
          // 循环查找帧
          while (offset + 10 < tagSize) {
            // ID3v2.3和ID3v2.4的帧头
            if (versionMajor >= 3) {
              // 读取帧ID (4字节)
              String frameId = String.fromCharCodes(fileHeader.sublist(offset, offset + 4));
              
              // 读取帧大小 (4字节)
              int frameSize = 0;
              if (versionMajor == 3) {
                // ID3v2.3 - 大端序
                frameSize = (fileHeader[offset + 4] << 24) | 
                           (fileHeader[offset + 5] << 16) | 
                           (fileHeader[offset + 6] << 8) | 
                            fileHeader[offset + 7];
              } else {
                // ID3v2.4 - 同步安全的整数
                frameSize = ((fileHeader[offset + 4] & 0x7F) << 21) | 
                           ((fileHeader[offset + 5] & 0x7F) << 14) | 
                           ((fileHeader[offset + 6] & 0x7F) << 7) | 
                            (fileHeader[offset + 7] & 0x7F);
              }
              
              // 跳过帧标志 (2字节)
              // 拿到帧数据
              if (frameSize > 0 && offset + 10 + frameSize <= tagSize) {
                // 处理常见帧
                if (frameId == 'APIC' && !metadata['hasEmbeddedCover']) {
                  // 提取图片数据
                  List<int> frameData = fileHeader.sublist(offset + 10, offset + 10 + frameSize).toList();
                  List<int>? imageData = _extractImageFromAPICFrame(frameData);
                  
                  if (imageData != null) {
                    metadata['coverBytes'] = imageData;
                    metadata['hasEmbeddedCover'] = true;
                    debugPrint('从MP3 ID3v2标签成功提取封面: ${imageData.length} 字节');
                  }
                }
              }
              
              // 移动到下一帧
              offset += 10 + frameSize;
            } else {
              // ID3v2.2帧头
              // 读取帧ID (3字节)
              String frameId = String.fromCharCodes(fileHeader.sublist(offset, offset + 3));
              
              // 读取帧大小 (3字节)
              int frameSize = (fileHeader[offset + 3] << 16) | 
                             (fileHeader[offset + 4] << 8) | 
                              fileHeader[offset + 5];
              
              // 拿到帧数据
              if (frameSize > 0 && offset + 6 + frameSize <= tagSize) {
                // 处理常见帧
                if (frameId == 'PIC' && !metadata['hasEmbeddedCover']) {
                  // 提取图片数据
                  List<int> frameData = fileHeader.sublist(offset + 6, offset + 6 + frameSize).toList();
                  List<int>? imageData = _extractImageFromPICFrame(frameData);
                  
                  if (imageData != null) {
                    metadata['coverBytes'] = imageData;
                    metadata['hasEmbeddedCover'] = true;
                    debugPrint('从MP3 ID3v2.2标签成功提取封面: ${imageData.length} 字节');
                  }
                }
              }
              
              // 移动到下一帧
              offset += 6 + frameSize;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('手动解析MP3元数据失败: $e');
    }
  }
  
  // WAV文件特定的元数据提取
  static Future<void> _extractWavMetadata(String filePath, Map<String, dynamic> metadata) async {
    // WAV文件通常没有内嵌元数据，但可以通过RIFF头部获取音频特性
    final file = File(filePath);
    if (!await file.exists()) return;
    
    try {
      // 读取WAV文件头
      final headerSize = min(44, await file.length());
      final headerData = await file.openRead(0, headerSize).toList();
      final fileHeader = Uint8List.fromList(headerData.expand((x) => x).toList());
      
      // 检查RIFF WAV头
      if (fileHeader.length >= 44 && 
          fileHeader[0] == 0x52 && fileHeader[1] == 0x49 && 
          fileHeader[2] == 0x46 && fileHeader[3] == 0x46 &&
          fileHeader[8] == 0x57 && fileHeader[9] == 0x41 && 
          fileHeader[10] == 0x56 && fileHeader[11] == 0x45) {
        
        // 获取格式块
        if (fileHeader[12] == 0x66 && fileHeader[13] == 0x6D && 
            fileHeader[14] == 0x74 && fileHeader[15] == 0x20) {
          
          // 获取音频参数
          int channels = fileHeader[22] | (fileHeader[23] << 8);
          int sampleRate = fileHeader[24] | (fileHeader[25] << 8) | 
                          (fileHeader[26] << 16) | (fileHeader[27] << 24);
          int bitsPerSample = fileHeader[34] | (fileHeader[35] << 8);
          
          // 寻找数据块以获取音频数据大小
          int audioDataSize = 0;
          if (fileHeader.length >= 44 && 
              fileHeader[36] == 0x64 && fileHeader[37] == 0x61 && 
              fileHeader[38] == 0x74 && fileHeader[39] == 0x61) {
            audioDataSize = fileHeader[40] | (fileHeader[41] << 8) | 
                           (fileHeader[42] << 16) | (fileHeader[43] << 24);
          }
          
          if (audioDataSize > 0 && sampleRate > 0 && channels > 0 && bitsPerSample > 0) {
            // 计算时长（秒） = 数据大小 / (采样率 * 通道数 * (位深/8))
            int durationSeconds = (audioDataSize / (sampleRate * channels * (bitsPerSample / 8))).round();
            if (durationSeconds > 0) {
              metadata['duration'] = Duration(seconds: durationSeconds);
              debugPrint('从WAV头部计算时长: $durationSeconds 秒');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('解析WAV文件头失败: $e');
    }
  }
  
  // 从APIC帧提取图片数据
  static List<int>? _extractImageFromAPICFrame(List<int> frameData) {
    try {
      int offset = 0;
      
      // 跳过文本编码字节
      offset++;
      
      // 查找MIME类型字符串结束位置
      while (offset < frameData.length && frameData[offset] != 0) {
        offset++;
      }
      offset++; // 跳过终止符
      
      // 跳过图片类型字节
      if (offset < frameData.length) {
        offset++;
      }
      
      // 跳过描述字符串
      while (offset < frameData.length && frameData[offset] != 0) {
        offset++;
      }
      offset++; // 跳过终止符
      
      // 剩余数据就是图片数据
      if (offset < frameData.length) {
        List<int> imageData = frameData.sublist(offset);
        
        // 检查图片签名
        if (_isValidImageData(imageData)) {
          if (imageData.length > maxCoverSize) {
            debugPrint('APIC图片过大 (${imageData.length}字节)，截断到$maxCoverSize字节');
            return imageData.sublist(0, maxCoverSize);
          }
          return imageData;
        }
      }
    } catch (e) {
      debugPrint('解析APIC帧失败: $e');
    }
    
    return null;
  }
  
  // 从PIC帧提取图片数据 (ID3v2.2)
  static List<int>? _extractImageFromPICFrame(List<int> frameData) {
    try {
      int offset = 0;
      
      // 跳过文本编码字节
      offset++;
      
      // 跳过图像格式串 (3字节)
      offset += 3;
      
      // 跳过图片类型字节
      offset++;
      
      // 跳过描述字符串
      while (offset < frameData.length && frameData[offset] != 0) {
        offset++;
      }
      offset++; // 跳过终止符
      
      // 剩余数据就是图片数据
      if (offset < frameData.length) {
        List<int> imageData = frameData.sublist(offset);
        
        // 检查图片签名
        if (_isValidImageData(imageData)) {
          if (imageData.length > maxCoverSize) {
            return imageData.sublist(0, maxCoverSize);
          }
          return imageData;
        }
      }
    } catch (e) {
      debugPrint('解析PIC帧失败: $e');
    }
    
    return null;
  }
  
  // 检查数据是否为有效图片
  static bool _isValidImageData(List<int> data) {
    if (data.length < 8) return false;
    
    // 检查JPEG/PNG/GIF签名
    if ((data[0] == 0xFF && data[1] == 0xD8) || // JPEG
        (data[0] == 0x89 && data[1] == 0x50 && 
         data[2] == 0x4E && data[3] == 0x47) || // PNG
        (data[0] == 0x47 && data[1] == 0x49 && 
         data[2] == 0x46)) { // GIF
      return true;
    }
    
    return false;
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
  
  // 验证和修正封面数据
  static void _validateCoverData(Map<String, dynamic> metadata) {
    // 检查封面数据是否存在且有效
    if (metadata['coverBytes'] != null) {
      List<int> coverBytes = metadata['coverBytes'];
      
      // 检查尺寸和格式
      if (coverBytes.length >= 8 && _isValidImageData(coverBytes)) {
        // 如果超过最大大小，截断
        if (coverBytes.length > maxCoverSize) {
          metadata['coverBytes'] = coverBytes.sublist(0, maxCoverSize);
          debugPrint('封面图片过大，已截断到 $maxCoverSize 字节');
        }
        
        metadata['hasEmbeddedCover'] = true;
      } else {
        debugPrint('封面数据无效，移除');
        metadata['coverBytes'] = null;
        metadata['hasEmbeddedCover'] = false;
      }
    } else {
      metadata['hasEmbeddedCover'] = false;
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
        // FLAC约1MB/分钟
        estimatedSeconds = (fileSize / (1024 * 1024) * 60).round();
        break;
      case '.mp3':
        // MP3约1MB/10分钟 (128kbps)
        estimatedSeconds = (fileSize / (1024 * 1024) * 600).round();
        break;
      case '.wav':
        // WAV约10MB/分钟 (44.1kHz, 16位, 立体声)
        estimatedSeconds = (fileSize / (10 * 1024 * 1024) * 60).round();
        break;
      default:
        // 通用估算，假设中等比特率
        estimatedSeconds = (fileSize / (1024 * 1024) * 120).round();
    }
    
    if (estimatedSeconds > 0) {
      metadata['duration'] = Duration(seconds: estimatedSeconds);
      debugPrint('根据文件大小估算时长: $estimatedSeconds 秒');
    } else {
      metadata['duration'] = const Duration(seconds: 60); // 默认1分钟
    }
  }
  
  // 查找外部封面和歌词文件
  static Future<void> _findExternalFiles(String filePath, Map<String, dynamic> metadata) async {
    final directory = path.dirname(filePath);
    final baseName = path.basenameWithoutExtension(filePath);
    
    // 查找封面文件
    if (!metadata['hasEmbeddedCover']) {
      final possibleCoverNames = [
        '$baseName.jpg', '$baseName.jpeg', '$baseName.png',
        'cover.jpg', 'cover.jpeg', 'cover.png',
        'folder.jpg', 'folder.jpeg', 'folder.png',
        'album.jpg', 'album.jpeg', 'album.png',
      ];
      
      for (final name in possibleCoverNames) {
        final coverPath = path.join(directory, name);
        if (await File(coverPath).exists()) {
          metadata['coverPath'] = coverPath;
          debugPrint('找到外部封面文件: $coverPath');
          break;
        }
      }
    }
    
    // 查找歌词文件
    final possibleLyricNames = [
      '$baseName.lrc', '$baseName.txt',
      '${baseName}.lrc', '${baseName}.txt',
    ];
    
    for (final name in possibleLyricNames) {
      final lyricsPath = path.join(directory, name);
      if (await File(lyricsPath).exists()) {
        metadata['lyricsPath'] = lyricsPath;
        debugPrint('找到外部歌词文件: $lyricsPath');
        break;
      }
    }
  }
  
  // 获取文件哈希值用于缓存索引
  static String getFileHash(String filePath) {
    // 创建MD5哈希值作为缓存键
    return md5.convert(utf8.encode(filePath)).toString();
  }
} 