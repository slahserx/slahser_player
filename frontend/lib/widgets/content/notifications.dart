import 'package:flutter/material.dart';
import 'package:slahser_player/enums/content_type.dart';

/// 定义一个自定义通知，用于告诉HomePage切换到特定歌单
class PlaylistSelectedNotification extends Notification {
  /// 要选择的播放列表ID
  final String playlistId;
  
  PlaylistSelectedNotification(this.playlistId);
}

/// 定义一个自定义通知，用于告诉HomePage切换到特定艺术家页面
class ArtistSelectedNotification extends Notification {
  /// 要查看的艺术家名称
  final String artistName;
  
  ArtistSelectedNotification(this.artistName);
}

/// 定义一个自定义通知，用于告诉HomePage切换到特定专辑页面
class AlbumSelectedNotification extends Notification {
  /// 要查看的专辑名称
  final String albumName;
  /// 专辑的艺术家名称
  final String artistName;
  
  AlbumSelectedNotification(this.albumName, this.artistName);
}

/// 定义一个自定义通知，用于告诉HomePage切换内容类型
class ContentTypeChangedNotification extends Notification {
  /// 要切换到的内容类型
  final ContentType contentType;
  
  ContentTypeChangedNotification(this.contentType);
} 