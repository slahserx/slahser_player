import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:slahser_player/models/music_file.dart';

/// 歌单模型
class Playlist {
  /// 歌单ID
  final String id;
  
  /// 歌单名称
  String name;
  
  /// 封面图片路径（可选）
  String? coverImagePath;
  
  /// 歌曲列表
  List<MusicFile> songs;
  
  /// 创建时间
  DateTime createdAt;
  
  /// 更新时间
  DateTime updatedAt;
  
  /// 是否为默认歌单
  final bool isDefault;
  
  /// 创建歌单
  Playlist({
    required this.id,
    required this.name,
    this.coverImagePath,
    required this.songs,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });
  
  /// 添加歌曲
  void addSong(MusicFile song) {
    // 避免重复添加
    if (!songs.any((s) => s.id == song.id)) {
      songs.add(song);
      updatedAt = DateTime.now();
    }
  }
  
  /// 移除歌曲
  void removeSong(String songId) {
    songs.removeWhere((s) => s.id == songId);
    updatedAt = DateTime.now();
  }
  
  /// 获取封面图片
  String? getCoverImage() {
    // 如果有指定封面，返回指定封面
    if (coverImagePath != null && File(coverImagePath!).existsSync()) {
      return coverImagePath;
    }
    
    // 否则返回第一首歌曲的专辑封面
    if (songs.isNotEmpty) {
      for (var song in songs) {
        if (song.coverImagePath != null && File(song.coverImagePath!).existsSync()) {
          return song.coverImagePath;
        }
      }
    }
    
    // 都没有则返回null
    return null;
  }
  
  /// 从JSON反序列化
  factory Playlist.fromJson(Map<String, dynamic> json) {
    final songs = (json['songs'] as List<dynamic>)
        .map((songJson) => MusicFile.fromJson(songJson))
        .toList();
    
    return Playlist(
      id: json['id'] ?? const Uuid().v4(),
      name: json['name'] ?? '未命名歌单',
      coverImagePath: json['coverImagePath'],
      songs: songs,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isDefault: json['isDefault'] ?? false,
    );
  }
  
  /// 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverImagePath': coverImagePath,
      'songs': songs.map((song) => song.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }
} 