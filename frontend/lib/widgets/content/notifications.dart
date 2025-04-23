import 'package:flutter/material.dart';
import 'package:slahser_player/enums/content_type.dart';

/// 歌单选择通知
class PlaylistSelectedNotification extends Notification {
  /// 要选择的播放列表ID
  final String playlistId;
  
  PlaylistSelectedNotification(this.playlistId);
}

/// 艺术家选择通知
class ArtistSelectedNotification extends Notification {
  /// 要查看的艺术家名称
  final String artistName;
  
  ArtistSelectedNotification(this.artistName);
}

/// 专辑选择通知
class AlbumSelectedNotification extends Notification {
  /// 要查看的专辑名称
  final String albumName;
  /// 专辑的艺术家名称
  final String artistName;
  
  AlbumSelectedNotification(this.albumName, this.artistName);
}

/// 内容类型改变通知
class ContentTypeChangedNotification extends Notification {
  /// 要切换到的内容类型
  final ContentType contentType;
  
  ContentTypeChangedNotification(this.contentType);
}

/// 云音乐艺术家选择通知
class CloudArtistSelectedNotification extends Notification {
  final String artistName;
  final String artistId;
  final bool isCloudContent = true;
  
  CloudArtistSelectedNotification(this.artistName, this.artistId);
}

/// 云音乐专辑选择通知
class CloudAlbumSelectedNotification extends Notification {
  final String albumName;
  final String artistName;
  final String albumId;
  final bool isCloudContent = true;
  
  CloudAlbumSelectedNotification(this.albumName, this.artistName, this.albumId);
} 