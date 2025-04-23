import 'package:flutter/material.dart';

/// 云音乐专辑数据，用于在视图间共享
class CloudAlbumData {
  final String id;
  final String name;
  final String artist;

  CloudAlbumData({
    required this.id,
    required this.name,
    required this.artist,
  });
}

/// 云音乐艺术家数据，用于在视图间共享
class CloudArtistData {
  final String id;
  final String name;

  CloudArtistData({
    required this.id,
    required this.name,
  });
}

/// 云音乐专辑列表数据，用于全部专辑页面
class CloudAlbumListData {
  final String type; // 列表类型: newest, random, frequent
  final String title; // 显示标题
  
  CloudAlbumListData({
    required this.type,
    required this.title,
  });
}

/// 云音乐搜索结果数据
class CloudSearchData {
  final String query; // 搜索关键词
  
  CloudSearchData({
    required this.query,
  });
}

/// 应用程序状态管理，用于在不同组件间共享状态
class AppState with ChangeNotifier {
  // 当前选择的云音乐专辑
  CloudAlbumData? _cloudAlbumData;
  CloudAlbumData? get cloudAlbumData => _cloudAlbumData;

  // 当前选择的云音乐艺术家
  CloudArtistData? _cloudArtistData;
  CloudArtistData? get cloudArtistData => _cloudArtistData;
  
  // 当前选择的云音乐专辑列表
  CloudAlbumListData? _cloudAlbumListData;
  CloudAlbumListData? get cloudAlbumListData => _cloudAlbumListData;
  
  // 当前的云音乐搜索数据
  CloudSearchData? _cloudSearchData;
  CloudSearchData? get cloudSearchData => _cloudSearchData;

  // 设置当前选择的云音乐专辑
  void setCloudAlbumData(String id, String name, String artist) {
    _cloudAlbumData = CloudAlbumData(
      id: id,
      name: name,
      artist: artist,
    );
    notifyListeners();
  }

  // 清除云音乐专辑数据
  void clearCloudAlbumData() {
    _cloudAlbumData = null;
    notifyListeners();
  }

  // 设置云音乐艺术家数据
  void setCloudArtist(String id, String name) {
    _cloudArtistData = CloudArtistData(
      id: id,
      name: name,
    );
    notifyListeners();
  }

  // 设置云音乐专辑
  void setCloudAlbum(String id, String name, String artist) {
    setCloudAlbumData(id, name, artist);
  }
  
  // 设置云音乐专辑列表
  void setCloudAlbumList(String type, String title) {
    _cloudAlbumListData = CloudAlbumListData(
      type: type,
      title: title,
    );
    notifyListeners();
  }
  
  // 设置云音乐搜索数据
  void setCloudSearchData(String query) {
    _cloudSearchData = CloudSearchData(
      query: query,
    );
    notifyListeners();
  }
} 