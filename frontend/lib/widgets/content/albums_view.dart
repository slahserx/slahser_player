import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/widgets/content/hover_widget.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'dart:collection';
import 'dart:typed_data';

/// 专辑视图组件
class AlbumsView extends StatefulWidget {
  const AlbumsView({super.key});

  @override
  State<AlbumsView> createState() => _AlbumsViewState();
}

class _AlbumsViewState extends State<AlbumsView> {
  // 缓存专辑封面图片
  final Map<String, Uint8List> _albumCoverCache = {};
  
  @override
  Widget build(BuildContext context) {
    final musicLibrary = Provider.of<MusicLibraryService>(context);
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    
    // 从音乐库中提取所有专辑
    final musicFiles = musicLibrary.musicFiles;
    
    // 使用LinkedHashMap保持排序顺序
    // 键为"专辑名-艺术家名"，值为包含专辑信息和歌曲列表的Map
    final albumsMap = LinkedHashMap<String, Map<String, dynamic>>();
    
    // 统计每个专辑信息和包含的歌曲
    for (final music in musicFiles) {
      if (music.album.isNotEmpty && music.album != '未知专辑') {
        final key = '${music.album}_${music.artist}';
        
        if (!albumsMap.containsKey(key)) {
          albumsMap[key] = {
            'title': music.album,
            'artist': music.artist,
            'songs': <MusicFile>[],
            'representativeSong': music,
          };
        }
        
        // 将歌曲添加到这个专辑下
        albumsMap[key]!['songs'].add(music);
      }
    }
    
    // 转换为列表并按专辑名称排序
    final albums = albumsMap.values.toList()
      ..sort((a, b) => a['title'].toString().toLowerCase().compareTo(b['title'].toString().toLowerCase()));
    
    if (albums.isEmpty) {
      // 显示空状态
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.album_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '没有专辑信息',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '导入带有专辑标签的音乐文件',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }
    
    // 构建专辑网格视图
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              '专辑',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.9,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final albumTitle = album['title'] as String;
                final artistName = album['artist'] as String;
                final songsList = album['songs'] as List<MusicFile>;
                final representativeSong = album['representativeSong'] as MusicFile;
                
                return HoverWidget(
                  builder: (context, isHovered) {
                    return InkWell(
                      onTap: () {
                        // 发送通知，切换到专辑详情视图
                        AlbumSelectedNotification(albumTitle, artistName).dispatch(context);
                      },
                      child: Card(
                        elevation: isHovered ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // 专辑封面
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: _buildAlbumCover(representativeSong),
                              ),
                            ),
                            // 专辑信息
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    albumTitle,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    artistName,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${songsList.length} 首歌曲',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建专辑封面
  Widget _buildAlbumCover(MusicFile representativeSong) {
    final albumKey = '${representativeSong.album}_${representativeSong.artist}';
    
    if (_albumCoverCache.containsKey(albumKey)) {
      // 使用缓存的封面
      return Image.memory(
        _albumCoverCache[albumKey]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackCover();
        },
      );
    } else if (representativeSong.hasEmbeddedCover) {
      // 尝试加载封面
      return FutureBuilder<List<int>?>(
        future: representativeSong.getCoverBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && 
              snapshot.data != null && 
              snapshot.data!.isNotEmpty) {
            
            // 缓存专辑封面
            if (!_albumCoverCache.containsKey(albumKey)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _albumCoverCache[albumKey] = Uint8List.fromList(snapshot.data!);
                  });
                }
              });
            }
            
            return Image.memory(
              Uint8List.fromList(snapshot.data!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackCover();
              },
            );
          } else {
            return _buildFallbackCover();
          }
        },
      );
    } else {
      // 没有封面，使用默认图片
      return _buildFallbackCover();
    }
  }
  
  // 构建默认专辑封面
  Widget _buildFallbackCover() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.7),
            Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.album,
          size: 64,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
} 