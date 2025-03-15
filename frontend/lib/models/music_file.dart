import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

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
    
    // 尝试读取元数据 - 暂时简化处理，后续可以添加更多格式支持
    try {
      // 这里简化处理，暂不读取元数据
      // 后续可以添加对MP3、FLAC等格式的元数据读取支持
    } catch (e) {
      print('读取元数据失败: $e');
    }
    
    // 查找歌词文件
    final lyricsPath = findLyricsFile(filePath);
    
    // 查找封面图片
    final coverPath = findCoverImage(filePath);
    
    return MusicFile(
      id: const Uuid().v4(),
      filePath: filePath,
      fileName: fileName,
      fileExtension: fileExtension,
      title: title,
      artist: artist,
      album: album,
      lyricsPath: lyricsPath,
      coverPath: coverPath,
      duration: duration,
    );
  }
  
  // 查找歌词文件
  static String? findLyricsFile(String audioFilePath) {
    final directory = path.dirname(audioFilePath);
    final baseName = path.basenameWithoutExtension(audioFilePath);
    final lrcPath = path.join(directory, '$baseName.lrc');
    
    if (File(lrcPath).existsSync()) {
      return lrcPath;
    }
    
    return null;
  }
  
  // 查找封面图片
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
    
    for (final name in possibleNames) {
      final coverPath = path.join(directory, name);
      if (File(coverPath).existsSync()) {
        return coverPath;
      }
    }
    
    return null;
  }
  
  // 获取封面图片路径
  String? get coverImagePath => coverPath;

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