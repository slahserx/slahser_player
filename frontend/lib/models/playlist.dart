import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:slahser_player/models/music_file.dart';

/// 简化的歌单模型
class Playlist {
  /// 歌单ID
  String id;
  
  /// 歌单名称
  String name;
  
  /// 是否为默认歌单（收藏夹）
  bool isDefault;
  
  /// 创建时间
  DateTime createdAt;
  
  /// 更新时间
  DateTime updatedAt;
  
  /// 歌曲路径列表（不再保存整个MusicFile对象）
  List<String> songPaths = [];
  
  /// 歌单封面路径
  String? coverPath;
  
  Playlist({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.coverPath,
    List<String>? songPaths,
  }) {
    this.songPaths = songPaths ?? [];
  }
  
  /// 获取歌单中的所有歌曲对象
  List<MusicFile> getSongs(List<MusicFile> allMusicFiles) {
    final Map<String, MusicFile> musicFilesByPath = {};
    
    // 创建路径到歌曲对象的映射
    for (var music in allMusicFiles) {
      musicFilesByPath[music.filePath.toLowerCase()] = music;
    }
    
    // 根据路径获取歌曲对象
    final songs = <MusicFile>[];
    for (var path in songPaths) {
      final normalizedPath = path.toLowerCase();
      if (musicFilesByPath.containsKey(normalizedPath)) {
        songs.add(musicFilesByPath[normalizedPath]!);
      }
    }
    
    return songs;
  }
  
  /// 添加歌曲到歌单
  void addSong(MusicFile song) {
    if (!songPaths.contains(song.filePath)) {
      songPaths.add(song.filePath);
      updatedAt = DateTime.now();
    }
  }
  
  /// 从歌单中移除歌曲
  void removeSong(MusicFile song) {
    songPaths.remove(song.filePath);
    updatedAt = DateTime.now();
  }
  
  /// 从歌单中移除特定路径的歌曲
  void removeSongByPath(String path) {
    songPaths.remove(path);
    updatedAt = DateTime.now();
  }
  
  /// 获取歌单封面图像（从第一首歌获取）
  String? getCoverImage(List<MusicFile> allMusicFiles) {
    // 如果有自定义封面，直接返回
    if (coverPath != null && File(coverPath!).existsSync()) {
      return coverPath;
    }
    
    // 否则使用第一首歌的封面
    final songs = getSongs(allMusicFiles);
    if (songs.isNotEmpty) {
      return songs.first.coverPath;
    }
    
    return null;
  }
  
  /// 从JSON创建歌单
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      isDefault: json['isDefault'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      coverPath: json['coverPath'] as String?,
      songPaths: (json['songPaths'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
  
  /// 转换歌单为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coverPath': coverPath,
      'songPaths': songPaths,
    };
  }
} 