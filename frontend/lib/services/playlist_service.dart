import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:uuid/uuid.dart';

/// 歌单服务，用于管理所有歌单
class PlaylistService extends ChangeNotifier {
  static const String _playlistsFileName = 'playlists.json';
  
  /// 歌单列表
  final List<Playlist> _playlists = [];
  
  /// 音乐库服务
  late MusicLibraryService _musicLibraryService;
  
  /// 获取所有歌单
  List<Playlist> get playlists => _playlists;
  
  /// 获取收藏夹播放列表
  Playlist getFavoritesPlaylist() {
    // 查找默认的收藏夹播放列表
    final favorites = _playlists.firstWhere(
      (playlist) => playlist.isDefault,
      orElse: () {
        // 如果没有找到，创建一个新的收藏夹
        final newFavorites = _createDefaultFavoritesPlaylist();
        _playlists.add(newFavorites);
        _savePlaylists(); // 保存更改
        return newFavorites;
      },
    );
    
    return favorites;
  }
  
  /// 获取指定ID的歌单
  Playlist? getPlaylist(String id) {
    try {
      return _playlists.firstWhere((playlist) => playlist.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// 初始化
  Future<void> init(MusicLibraryService musicLibraryService) async {
    _musicLibraryService = musicLibraryService;
    
    // 监听音乐库变化，同步歌单
    _musicLibraryService.addListener(() {
      _syncPlaylistsWithLibrary();
    });
    
    // 加载歌单
    await _init();
  }
  
  /// 初始化
  Future<void> _init() async {
    // 加载歌单
    await _loadPlaylists();
    
    // 如果没有任何歌单，创建默认歌单
    if (_playlists.isEmpty) {
      _createDefaultPlaylist();
      await _savePlaylists();
    }
    
    // 同步歌单与音乐库
    _syncPlaylistsWithLibrary();
  }
  
  /// 创建默认的"我喜欢的音乐"歌单
  Playlist _createDefaultFavoritesPlaylist() {
    return Playlist(
      id: const Uuid().v4(),
      name: '我喜欢的音乐',
      songs: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDefault: true,
    );
  }
  
  /// 创建默认的"我喜欢的音乐"歌单
  void _createDefaultPlaylist() {
    final defaultPlaylist = Playlist(
      id: const Uuid().v4(),
      name: '我喜欢的音乐',
      isDefault: true,
      songs: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _playlists.add(defaultPlaylist);
  }
  
  /// 加载歌单
  Future<void> _loadPlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${_playlistsFileName}');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        
        _playlists.clear();
        for (var json in jsonList) {
          _playlists.add(Playlist.fromJson(json));
        }
      }
    } catch (e) {
      // 如果加载失败，创建默认歌单
      _playlists.clear();
      _createDefaultPlaylist();
    }
  }
  
  /// 保存歌单
  Future<void> _savePlaylists() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${_playlistsFileName}');
      
      final jsonList = _playlists.map((playlist) => playlist.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
    } catch (e) {
      // 保存失败
      debugPrint('保存歌单失败: $e');
    }
  }
  
  /// 同步歌单与音乐库
  void _syncPlaylistsWithLibrary() {
    final musicFiles = _musicLibraryService.musicFiles;
    final musicIds = musicFiles.map((music) => music.id).toSet();
    
    // 遍历所有歌单
    for (var playlist in _playlists) {
      // 过滤掉已经不在音乐库中的歌曲
      playlist.songs = playlist.songs.where((song) => musicIds.contains(song.id)).toList();
    }
    
    // 保存更新后的歌单
    _savePlaylists();
    notifyListeners();
  }
  
  /// 创建新歌单
  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      isDefault: false,
      songs: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _playlists.add(playlist);
    await _savePlaylists();
    notifyListeners();
    
    return playlist;
  }
  
  /// 删除歌单
  Future<void> deletePlaylist(String id) async {
    // 不能删除默认歌单
    final playlist = getPlaylist(id);
    if (playlist == null || playlist.isDefault) {
      return;
    }
    
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 重命名歌单
  Future<void> renamePlaylist(String id, String newName) async {
    // 不能重命名默认歌单
    final playlist = getPlaylist(id);
    if (playlist == null || playlist.isDefault) {
      return;
    }
    
    playlist.name = newName;
    playlist.updatedAt = DateTime.now();
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 添加歌曲到歌单
  Future<void> addSongToPlaylist(String playlistId, MusicFile song) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) {
      return;
    }
    
    // 检查歌曲是否已在歌单中
    if (playlist.songs.any((s) => s.id == song.id)) {
      return;
    }
    
    playlist.songs.add(song);
    playlist.updatedAt = DateTime.now();
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 从歌单中移除歌曲
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) {
      return;
    }
    
    playlist.songs.removeWhere((song) => song.id == songId);
    playlist.updatedAt = DateTime.now();
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 添加歌曲到收藏夹
  Future<void> addToFavorites(MusicFile song) async {
    final favorites = getFavoritesPlaylist();
    await addSongToPlaylist(favorites.id, song);
    notifyListeners();
  }
  
  /// 从收藏夹中移除歌曲
  Future<void> removeFromFavorites(String songId) async {
    final favorites = getFavoritesPlaylist();
    await removeSongFromPlaylist(favorites.id, songId);
    notifyListeners();
  }
  
  /// 检查歌曲是否在收藏夹中
  bool isSongInFavorites(String songId) {
    final favoritesPlaylist = getFavoritesPlaylist();
    return favoritesPlaylist.songs.any((song) => song.id == songId);
  }
} 