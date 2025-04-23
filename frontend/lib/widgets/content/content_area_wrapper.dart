import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/widgets/content/all_music_view.dart';
import 'package:slahser_player/widgets/settings_panel.dart';
import 'package:slahser_player/widgets/playlist_view.dart';
import 'package:slahser_player/widgets/content/albums_view.dart';
import 'package:slahser_player/widgets/content/artists_view.dart';
import 'package:slahser_player/widgets/content/playlists_view.dart';
import 'package:slahser_player/widgets/content/artist_detail_view.dart';
import 'package:slahser_player/widgets/content/album_detail_view.dart';
import 'package:slahser_player/widgets/content/cloud_music_view.dart';
import 'package:slahser_player/widgets/content/cloud_search_view.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/utils/page_transitions.dart';
import '../../enums/content_type.dart';
import 'package:slahser_player/widgets/content/cloud_album_detail_view.dart';
import 'package:slahser_player/widgets/content/cloud_album_list_view.dart';
import 'package:slahser_player/providers/app_state.dart';

/// 应用程序的主要内容区域包装器
class ContentAreaWrapper extends StatelessWidget {
  /// 当前选择的内容类型
  final ContentType selectedContentType;
  
  /// 当前选择的播放列表ID（可选）
  final String? selectedPlaylistId;
  
  /// 当前选择的艺术家名称
  final String? selectedArtistName;
  
  /// 当前选择的专辑名称
  final String? selectedAlbumName;
  
  /// 当前选择的专辑艺术家
  final String? selectedAlbumArtist;
  
  /// 是否是云音乐（用于区分本地和远程内容）
  final bool isCloudContent;
  
  /// 选中的云音乐ID
  final String? selectedCloudId;
  
  const ContentAreaWrapper({
    super.key,
    required this.selectedContentType,
    this.selectedPlaylistId,
    this.selectedArtistName,
    this.selectedAlbumName,
    this.selectedAlbumArtist,
    this.isCloudContent = false,
    this.selectedCloudId,
  });
  
  @override
  Widget build(BuildContext context) {
    // 根据选择的内容类型显示不同的内容
    Widget content;
    
    switch (selectedContentType) {
      case ContentType.allMusic:
        content = ContentAreaTransition(
          appearing: true,
          child: const AllMusicView(),
        );
        break;
      case ContentType.artists:
        content = ContentAreaTransition(
          appearing: true,
          child: const ArtistsView(),
        );
        break;
      case ContentType.albums:
        content = ContentAreaTransition(
          appearing: true,
          child: const AlbumsView(),
        );
        break;
      case ContentType.playlists:
        content = ContentAreaTransition(
          appearing: true,
          child: const PlaylistsView(),
        );
        break;
      case ContentType.playlist:
        final playlistService = Provider.of<PlaylistService>(context);
        
        // 如果没有选择播放列表ID，显示错误信息
        if (selectedPlaylistId == null) {
          content = Center(
            child: Text(
              '未选择歌单',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        } else {
          // 获取选择的播放列表
          final playlist = playlistService.getPlaylist(selectedPlaylistId!);
          
          if (playlist != null) {
            content = ContentAreaTransition(
              appearing: true,
              child: PlaylistView(playlist: playlist),
            );
          } else {
            // 播放列表不存在，显示错误消息
            content = Center(
              child: Text(
                '未找到播放列表',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
        }
        break;
      case ContentType.artistDetail:
        if (selectedArtistName == null) {
          content = Center(
            child: Text(
              '未选择艺术家',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        } else {
          final musicFiles = Provider.of<MusicLibraryService>(context)
              .musicFiles
              .where((music) => music.artist == selectedArtistName)
              .toList();
              
          content = ContentAreaTransition(
            appearing: true,
            child: ArtistDetailView(
              artist: selectedArtistName!,
              songs: musicFiles,
              onBackPressed: () {
                // 发送通知，切换回艺术家列表
                ContentTypeChangedNotification(ContentType.artists).dispatch(context);
              },
            ),
          );
        }
        break;
      case ContentType.albumDetail:
        if (selectedAlbumName == null || selectedAlbumArtist == null) {
          content = Center(
            child: Text(
              '未选择专辑',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        } else {
          final musicFiles = Provider.of<MusicLibraryService>(context)
              .musicFiles
              .where((music) => 
                  music.album == selectedAlbumName &&
                  music.artist == selectedAlbumArtist)
              .toList();
              
          content = ContentAreaTransition(
            appearing: true,
            child: AlbumDetailView(
              album: selectedAlbumName!,
              artist: selectedAlbumArtist!,
              songs: musicFiles,
              onBackPressed: () {
                // 发送通知，切换回专辑列表
                ContentTypeChangedNotification(ContentType.albums).dispatch(context);
              },
            ),
          );
        }
        break;
      case ContentType.settings:
        content = ContentAreaTransition(
          appearing: true,
          child: const SettingsPanel(),
        );
        break;
      case ContentType.cloudMusic:
        content = ContentAreaTransition(
          appearing: true,
          child: const CloudMusicView(),
        );
        break;
      case ContentType.cloudMusicSettings:
        // 已将云音乐设置整合到设置面板中
        content = ContentAreaTransition(
          appearing: true,
          child: const SettingsPanel(),
        );
        break;
      case ContentType.cloudArtists:
        // 这里会添加云音乐艺术家视图
        content = const Center(child: Text('云音乐艺术家视图'));
        break;
      case ContentType.cloudAlbums:
        // 这里会添加云音乐专辑视图
        content = const Center(child: Text('云音乐专辑视图'));
        break;
      case ContentType.cloudArtistDetail:
        // 这里会添加云音乐艺术家详情视图
        content = const Center(child: Text('云音乐艺术家详情'));
        break;
      case ContentType.cloudAlbumDetail:
        // 获取专辑ID、名称和艺术家
        final albumData = Provider.of<AppState>(context, listen: false).cloudAlbumData;
        if (albumData != null) {
          content = CloudAlbumDetailView(
            albumId: albumData.id,
            albumName: albumData.name,
            artist: albumData.artist,
          );
        } else {
          content = const Center(child: Text('未找到专辑信息'));
        }
        break;
      case ContentType.cloudAlbumList:
        // 显示云音乐专辑列表视图
        content = const CloudAlbumListView();
        break;
      case ContentType.cloudSearchResult:
        content = ContentAreaTransition(
          appearing: true,
          child: const CloudSearchView(),
        );
        break;
      default:
        // 默认显示所有音乐
        content = ContentAreaTransition(
          appearing: true,
          child: const AllMusicView(),
        );
    }
    
    // 添加背景颜色
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: content,
    );
  }
} 