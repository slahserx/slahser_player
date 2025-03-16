import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:uuid/uuid.dart';

/// 歌单服务，用于管理所有歌单
class PlaylistService extends ChangeNotifier {
  static const String _playlistsFileName = 'playlists.json';
  static const String _appFolderName = 'SlahserPlayer';
  
  /// 歌单列表
  final List<Playlist> _playlists = [];
  
  /// 音乐库服务
  late MusicLibraryService _musicLibraryService;
  
  /// 获取应用专用文件夹路径
  Future<String> _getAppDirectoryPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(path.join(appDocDir.path, _appFolderName));
    
    // 确保目录存在
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
      debugPrint('**** 创建应用专用文件夹: ${appDir.path} ****');
    }
    
    return appDir.path;
  }
  
  /// 获取歌单文件路径
  Future<String> _getPlaylistsFilePath() async {
    final appDirPath = await _getAppDirectoryPath();
    return path.join(appDirPath, _playlistsFileName).replaceAll('\\', '/');
  }
  
  /// 获取所有歌单
  List<Playlist> get playlists => _playlists;
  
  /// 获取音乐库中的所有音乐文件
  List<MusicFile> get allMusicFiles => _musicLibraryService.musicFiles;
  
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
    
    // 加载歌单
    await _loadPlaylists();
    
    // 如果没有任何歌单，创建默认歌单
    if (_playlists.isEmpty) {
      debugPrint('**** 没有找到歌单，创建默认歌单 ****');
      _createDefaultPlaylist();
      await _savePlaylists();
    } else {
      debugPrint('**** 成功读取${_playlists.length}个歌单，不需要创建默认歌单 ****');
    }
    
    // 清理不存在的歌曲路径
    _cleanupNonExistingPaths();
  }
  
  /// 清理不存在的歌曲路径
  void _cleanupNonExistingPaths() {
    bool hasChanges = false;
    
    for (var playlist in _playlists) {
      final originalCount = playlist.songPaths.length;
      playlist.songPaths = playlist.songPaths.where((path) => File(path).existsSync()).toList();
      
      if (originalCount != playlist.songPaths.length) {
        hasChanges = true;
        debugPrint('**** 清理歌单"${playlist.name}"中不存在的歌曲，从${originalCount}首减少到${playlist.songPaths.length}首 ****');
      }
    }
    
    if (hasChanges) {
      _savePlaylists();
      notifyListeners();
    }
  }
  
  /// 创建默认的"我喜欢的音乐"歌单
  Playlist _createDefaultFavoritesPlaylist() {
    return Playlist(
      id: const Uuid().v4(),
      name: '我喜欢的音乐',
      songPaths: [],
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
      songPaths: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _playlists.add(defaultPlaylist);
  }
  
  /// 加载歌单
  Future<void> _loadPlaylists() async {
    try {
      final filePath = await _getPlaylistsFilePath();
      debugPrint('**** 尝试从以下路径加载歌单: $filePath ****');
      
      final file = File(filePath);
      if (await file.exists()) {
        debugPrint('**** 歌单文件存在，开始读取 ****');
        final jsonString = await file.readAsString();
        
        if (jsonString.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(jsonString);
          debugPrint('**** 成功解析JSON，找到${jsonList.length}个歌单 ****');
          
          _playlists.clear();
          for (var json in jsonList) {
            try {
              final playlist = Playlist.fromJson(json);
              _playlists.add(playlist);
              debugPrint('**** 加载歌单: ${playlist.name}, 包含${playlist.songPaths.length}首歌曲路径 ****');
            } catch (e) {
              debugPrint('**** 解析歌单失败: $e ****');
            }
          }
          debugPrint('**** 所有歌单加载完成，共${_playlists.length}个歌单 ****');
        } else {
          debugPrint('**** 歌单文件内容为空 ****');
          _playlists.clear();
          _createDefaultPlaylist();
        }
      } else {
        debugPrint('**** 歌单文件不存在，将创建默认歌单 ****');
        _playlists.clear();
        _createDefaultPlaylist();
      }
    } catch (e) {
      // 如果加载失败，创建默认歌单
      debugPrint('**** 加载歌单失败: $e ****');
      _playlists.clear();
      _createDefaultPlaylist();
    }
  }
  
  /// 保存歌单
  Future<void> _savePlaylists() async {
    try {
      final filePath = await _getPlaylistsFilePath();
      debugPrint('**** 准备保存${_playlists.length}个歌单到: $filePath ****');
      
      final file = File(filePath);
      
      final jsonList = _playlists.map((playlist) => playlist.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
      debugPrint('**** 歌单保存成功: ${file.path} ****');
    } catch (e) {
      debugPrint('**** 保存歌单失败: $e ****');
    }
  }
  
  /// 创建新歌单
  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      isDefault: false,
      songPaths: [],
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
      debugPrint('**** 添加歌曲失败: 找不到歌单ID=$playlistId ****');
      return;
    }
    
    // 检查歌曲是否已在歌单中
    if (playlist.songPaths.contains(song.filePath)) {
      debugPrint('**** 歌曲"${song.title}"已在歌单"${playlist.name}"中 ****');
      return;
    }
    
    playlist.addSong(song);
    debugPrint('**** 歌曲"${song.title}"已添加到歌单"${playlist.name}" ****');
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 从歌单中移除歌曲
  Future<void> removeSongFromPlaylist(String playlistId, MusicFile song) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) {
      return;
    }
    
    playlist.removeSong(song);
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 通过路径从歌单中移除歌曲
  Future<void> removeSongPathFromPlaylist(String playlistId, String path) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) {
      return;
    }
    
    playlist.removeSongByPath(path);
    
    await _savePlaylists();
    notifyListeners();
  }
  
  /// 添加歌曲到收藏夹
  Future<void> addToFavorites(MusicFile song) async {
    final favorites = getFavoritesPlaylist();
    await addSongToPlaylist(favorites.id, song);
  }
  
  /// 从收藏夹中移除歌曲
  Future<void> removeFromFavorites(MusicFile song) async {
    final favorites = getFavoritesPlaylist();
    await removeSongFromPlaylist(favorites.id, song);
  }
  
  /// 检查歌曲是否在收藏夹中
  bool isSongInFavorites(MusicFile song) {
    final favoritesPlaylist = getFavoritesPlaylist();
    return favoritesPlaylist.songPaths.contains(song.filePath);
  }
  
  /// 获取歌单中的所有歌曲
  List<MusicFile> getPlaylistSongs(String playlistId) {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) {
      return [];
    }
    
    return playlist.getSongs(_musicLibraryService.musicFiles);
  }
} 