import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slahser_player/models/subsonic_models.dart';

/// Subsonic API 服务类，用于与Subsonic兼容的服务器进行通信
class SubsonicService extends ChangeNotifier {
  // Subsonic API 版本
  static const String _apiVersion = '1.16.1';
  // 客户端名称
  static const String _clientName = 'SlahserPlayer';
  
  // 服务器设置
  String _serverUrl = '';
  String get serverUrl => _serverUrl;
  
  String _username = '';
  String get username => _username;
  
  String _password = '';
  // 不提供password的getter，保护安全性
  
  bool _isLegacyAuth = false;
  bool get isLegacyAuth => _isLegacyAuth;
  
  // 连接状态
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  
  // 构造函数，从缓存加载设置
  SubsonicService() {
    _loadSettings();
  }
  
  // 保存设置
  Future<void> saveSettings({
    required String serverUrl,
    required String username,
    required String password,
    required bool isLegacyAuth,
  }) async {
    // 验证URL格式
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      throw Exception('服务器URL必须以http://或https://开头');
    }
    
    // 移除URL末尾的斜杠
    String normalizedUrl = serverUrl;
    while (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    _serverUrl = normalizedUrl;
    _username = username;
    _password = password;
    _isLegacyAuth = isLegacyAuth;
    
    // 保存设置到缓存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subsonic_server_url', _serverUrl);
    await prefs.setString('subsonic_username', _username);
    await prefs.setString('subsonic_password', _password);
    await prefs.setBool('subsonic_legacy_auth', _isLegacyAuth);
    
    // 尝试连接测试
    await testConnection();
    
    notifyListeners();
  }
  
  // 从缓存加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('subsonic_server_url') ?? '';
    _username = prefs.getString('subsonic_username') ?? '';
    _password = prefs.getString('subsonic_password') ?? '';
    _isLegacyAuth = prefs.getBool('subsonic_legacy_auth') ?? false;
    
    // 如果有保存的设置，尝试连接
    if (_serverUrl.isNotEmpty && _username.isNotEmpty && _password.isNotEmpty) {
      await testConnection();
    }
  }
  
  // 生成认证参数
  Map<String, String> _getAuthParams() {
    final Map<String, String> params = {
      'u': _username,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
    
    // 随机生成的salt
    final String salt = DateTime.now().millisecondsSinceEpoch.toString();
    
    if (_isLegacyAuth) {
      // 旧版认证: 直接使用密码
      params['p'] = _password;
    } else {
      // 新版认证: 使用salt和MD5哈希
      final String token = md5.convert(utf8.encode(_password + salt)).toString();
      params['s'] = salt;
      params['t'] = token;
    }
    
    return params;
  }
  
  // 测试连接
  Future<bool> testConnection() async {
    if (_serverUrl.isEmpty || _username.isEmpty || _password.isEmpty) {
      _errorMessage = '请先设置服务器信息';
      _isConnected = false;
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final response = await _makeApiRequest('ping');
      
      if (response['status'] == 'ok') {
        _isConnected = true;
        _errorMessage = '';
      } else {
        _isConnected = false;
        _errorMessage = response['error']?['message'] ?? '未知错误';
      }
    } catch (e) {
      _isConnected = false;
      _errorMessage = '连接失败: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return _isConnected;
  }
  
  // 发送API请求
  Future<Map<String, dynamic>> _makeApiRequest(
    String endpoint, {
    Map<String, String>? extraParams,
  }) async {
    if (_serverUrl.isEmpty) {
      throw Exception('未设置服务器地址');
    }
    
    final Map<String, String> params = _getAuthParams();
    if (extraParams != null) {
      params.addAll(extraParams);
    }
    
    final Uri uri = Uri.parse('$_serverUrl/rest/$endpoint')
        .replace(queryParameters: params);
    
    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('请求超时，请检查网络或服务器地址');
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
      
      final Map<String, dynamic> data = jsonDecode(response.body);
      final Map<String, dynamic> subsonicResponse = data['subsonic-response'];
      
      if (subsonicResponse['status'] != 'ok') {
        debugPrint('Subsonic API错误: ${subsonicResponse['error']?['message']}');
      }
      
      return subsonicResponse;
    } catch (e) {
      debugPrint('API请求错误: $e');
      rethrow;
    }
  }
  
  // 获取音乐库
  Future<List<MusicFolder>> getMusicFolders() async {
    final response = await _makeApiRequest('getMusicFolders');
    
    if (response['status'] == 'ok' && response['musicFolders'] != null) {
      final List<dynamic> folders = response['musicFolders']['musicFolder'] ?? [];
      return folders.map((folder) => MusicFolder.fromJson(folder)).toList();
    }
    
    return [];
  }
  
  // 获取索引（艺术家列表）
  Future<List<Index>> getIndexes({String? musicFolderId}) async {
    Map<String, String>? extraParams;
    if (musicFolderId != null) {
      extraParams = {'musicFolderId': musicFolderId};
    }
    
    final response = await _makeApiRequest('getIndexes', extraParams: extraParams);
    
    if (response['status'] == 'ok' && response['indexes'] != null) {
      final List<dynamic> indexes = response['indexes']['index'] ?? [];
      return indexes.map((index) => Index.fromJson(index)).toList();
    }
    
    return [];
  }
  
  // 获取艺术家详情
  Future<Artist> getArtist(String id) async {
    final response = await _makeApiRequest('getArtist', extraParams: {'id': id});
    
    if (response['status'] == 'ok' && response['artist'] != null) {
      return Artist.fromJson(response['artist']);
    }
    
    throw Exception('获取艺术家信息失败');
  }
  
  // 获取专辑
  Future<Album> getAlbum(String id) async {
    final response = await _makeApiRequest('getAlbum', extraParams: {'id': id});
    
    if (response['status'] == 'ok' && response['album'] != null) {
      return Album.fromJson(response['album']);
    }
    
    throw Exception('获取专辑信息失败');
  }
  
  // 获取歌曲详情
  Future<Song> getSong(String id) async {
    final response = await _makeApiRequest('getSong', extraParams: {'id': id});
    
    if (response['status'] == 'ok' && response['song'] != null) {
      return Song.fromJson(response['song']);
    }
    
    throw Exception('获取歌曲信息失败');
  }
  
  // 搜索音乐
  Future<SearchResult> search(String query) async {
    final response = await _makeApiRequest('search3', extraParams: {
      'query': query,
      'artistCount': '20',
      'albumCount': '20',
      'songCount': '50',
    });
    
    if (response['status'] == 'ok' && response['searchResult3'] != null) {
      return SearchResult.fromJson(response['searchResult3']);
    }
    
    return SearchResult(artists: [], albums: [], songs: []);
  }
  
  // 获取专辑列表
  Future<List<Album>> getAlbumList({required String type, int? size, int? offset}) async {
    Map<String, String> params = {'type': type};
    
    if (size != null) {
      params['size'] = size.toString();
    }
    
    if (offset != null) {
      params['offset'] = offset.toString();
    }
    
    final response = await _makeApiRequest('getAlbumList2', extraParams: params);
    
    if (response['status'] == 'ok' && response['albumList2'] != null) {
      final List<dynamic> albums = response['albumList2']['album'] ?? [];
      return albums.map((album) => Album.fromJson(album)).toList();
    }
    
    return [];
  }
  
  // 获取随机歌曲
  Future<List<Song>> getRandomSongs({int size = 10, String? genre, String? fromYear, String? toYear}) async {
    Map<String, String> params = {'size': size.toString()};
    
    if (genre != null) {
      params['genre'] = genre;
    }
    
    if (fromYear != null) {
      params['fromYear'] = fromYear;
    }
    
    if (toYear != null) {
      params['toYear'] = toYear;
    }
    
    final response = await _makeApiRequest('getRandomSongs', extraParams: params);
    
    if (response['status'] == 'ok' && response['randomSongs'] != null) {
      final List<dynamic> songs = response['randomSongs']['song'] ?? [];
      return songs.map((song) => Song.fromJson(song)).toList();
    }
    
    return [];
  }
  
  // 获取播放列表
  Future<List<Playlist>> getPlaylists() async {
    final response = await _makeApiRequest('getPlaylists');
    
    if (response['status'] == 'ok' && response['playlists'] != null) {
      final List<dynamic> playlists = response['playlists']['playlist'] ?? [];
      return playlists.map((playlist) => Playlist.fromJson(playlist)).toList();
    }
    
    return [];
  }
  
  // 获取播放列表详情
  Future<Playlist> getPlaylist(String id) async {
    final response = await _makeApiRequest('getPlaylist', extraParams: {'id': id});
    
    if (response['status'] == 'ok' && response['playlist'] != null) {
      return Playlist.fromJson(response['playlist']);
    }
    
    throw Exception('获取播放列表详情失败');
  }
  
  // 获取流媒体URL
  String getStreamUrl(String id, {String? format, int? maxBitRate, bool? estimateContentLength}) {
    Map<String, String> params = _getAuthParams();
    params['id'] = id;
    
    if (format != null) {
      params['format'] = format;
    }
    
    if (maxBitRate != null) {
      params['maxBitRate'] = maxBitRate.toString();
    }
    
    if (estimateContentLength != null) {
      params['estimateContentLength'] = estimateContentLength.toString();
    }
    
    final Uri uri = Uri.parse('$_serverUrl/rest/stream')
        .replace(queryParameters: params);
    
    return uri.toString();
  }
  
  // 获取封面URL
  String getCoverArtUrl(String id, {int? size}) {
    Map<String, String> params = _getAuthParams();
    params['id'] = id;
    
    if (size != null) {
      params['size'] = size.toString();
    }
    
    final Uri uri = Uri.parse('$_serverUrl/rest/getCoverArt')
        .replace(queryParameters: params);
    
    return uri.toString();
  }
  
  // 获取歌词
  Future<String?> getLyrics(String artist, String title) async {
    final response = await _makeApiRequest('getLyrics', extraParams: {
      'artist': artist,
      'title': title,
    });
    
    if (response['status'] == 'ok' && response['lyrics'] != null) {
      return response['lyrics']['content'];
    }
    
    return null;
  }
} 