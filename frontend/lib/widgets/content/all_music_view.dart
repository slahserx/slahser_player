import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'dart:typed_data';
import 'package:slahser_player/widgets/content/hover_widget.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/widgets/content/music_context_menu.dart';
import '../../enums/playback_state.dart';

/// 所有音乐视图组件
class AllMusicView extends StatefulWidget {
  const AllMusicView({super.key});

  @override
  State<AllMusicView> createState() => _AllMusicViewState();
}

class _AllMusicViewState extends State<AllMusicView> {
  // 排序相关的状态
  String _sortField = 'title'; // 默认按标题排序
  bool _sortAscending = true; // 默认升序排序
  
  // 缓存封面图片数据
  final Map<String, Uint8List> _coverImageCache = {};
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCurrentSongCover();
  }
  
  // 预加载当前播放歌曲的封面
  void _precacheCurrentSongCover() {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final currentMusic = audioPlayer.currentMusic;
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    
    if (currentMusic != null && currentMusic.hasEmbeddedCover && !_coverImageCache.containsKey(currentMusic.id)) {
      // 异步预加载封面
      currentMusic.getCoverBytes().then((coverBytes) {
        if (coverBytes != null && coverBytes.isNotEmpty && mounted) {
          // 使用addPostFrameCallback确保在正确的时间更新UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _coverImageCache[currentMusic.id] = Uint8List.fromList(coverBytes);
              });
              
              // 预加载下一首和上一首歌曲的封面
              _preloadAdjacentSongs(currentMusic, musicLibrary.musicFiles);
            }
          });
        }
      }).catchError((error) {
        debugPrint('预加载封面图片出错: $error');
      });
    }
  }
  
  // 预加载相邻的歌曲封面
  void _preloadAdjacentSongs(MusicFile currentMusic, List<MusicFile> allSongs) {
    if (allSongs.isEmpty) return;
    
    // 找到当前歌曲在列表中的位置
    final currentIndex = allSongs.indexWhere((song) => song.id == currentMusic.id);
    if (currentIndex == -1) return;
    
    // 预加载前后各2首歌曲的封面
    for (int offset = -2; offset <= 2; offset++) {
      if (offset == 0) continue; // 跳过当前歌曲
      
      final targetIndex = currentIndex + offset;
      if (targetIndex >= 0 && targetIndex < allSongs.length) {
        final targetSong = allSongs[targetIndex];
        if (targetSong.hasEmbeddedCover && !_coverImageCache.containsKey(targetSong.id)) {
          // 使用延迟加载避免一次性加载过多导致卡顿
          Future.delayed(Duration(milliseconds: 100 * (offset.abs())), () {
            if (!mounted) return;
            
            targetSong.getCoverBytes().then((coverBytes) {
              if (coverBytes != null && coverBytes.isNotEmpty && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_coverImageCache.containsKey(targetSong.id)) {
                    setState(() {
                      _coverImageCache[targetSong.id] = Uint8List.fromList(coverBytes);
                    });
                  }
                });
              }
            }).catchError((error) {
              // 忽略预加载错误
              debugPrint('预加载相邻歌曲封面出错: $error');
            });
          });
        }
      }
    }
  }

  // 构建表头单元格
  Widget _buildHeaderCell(BuildContext context, String title, String field, {String? tooltip}) {
    final isActive = _sortField == field;
    
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortField == field) {
            // 如果已经按此字段排序，则切换排序方向
            _sortAscending = !_sortAscending;
          } else {
            // 否则，更改排序字段并默认升序
            _sortField = field;
            _sortAscending = true;
          }
        });
      },
      child: Tooltip(
        message: tooltip ?? '按$title排序',
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
  
  // 构建封面图片
  Widget _buildCoverImage(MusicFile music, bool isCurrentSong) {
    if (_coverImageCache.containsKey(music.id)) {
      // 使用缓存的图片数据
      return Image.memory(
        _coverImageCache[music.id]!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackCover(music, isCurrentSong);
        },
      );
    } else if (music.hasEmbeddedCover) {
      // 尝试加载封面
      return FutureBuilder<List<int>?>(
        future: music.getCoverBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && 
              snapshot.data != null && 
              snapshot.data!.isNotEmpty) {
            // 缓存封面数据
            if (!_coverImageCache.containsKey(music.id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _coverImageCache[music.id] = Uint8List.fromList(snapshot.data!);
                  });
                }
              });
            }
            
            return Image.memory(
              Uint8List.fromList(snapshot.data!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackCover(music, isCurrentSong);
              },
            );
          } else {
            return _buildFallbackCover(music, isCurrentSong);
          }
        },
      );
    } else {
      // 没有封面，使用占位图
      return _buildFallbackCover(music, isCurrentSong);
    }
  }
  
  // 构建备用封面
  Widget _buildFallbackCover(MusicFile music, bool isCurrentSong) {
    return Container(
      color: isCurrentSong 
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 24,
          color: isCurrentSong 
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
  
  // 播放歌曲
  void _playSong(MusicFile music) {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    
    // 在所有歌曲视图中，将所有歌曲添加到播放列表
    final allSongs = musicLibrary.musicFiles;
    // 找到点击歌曲在列表中的索引
    final index = allSongs.indexWhere((song) => song.id == music.id);
    if (index != -1) {
      audioPlayer.setPlaylist(allSongs, initialIndex: index);
      audioPlayer.playMusic(music);
    }
  }
  
  // 显示右键菜单
  void _showContextMenu(BuildContext context, MusicFile music, TapDownDetails details) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox itemBox = context.findRenderObject() as RenderBox;
    final Offset localOffset = details.localPosition;
    final Offset globalOffset = itemBox.localToGlobal(localOffset);
    
    // 如果菜单显示位置过于靠右，则向左移动
    final double screenWidth = MediaQuery.of(context).size.width;
    final double menuWidth = 280; // 菜单宽度
    final double xOffset = globalOffset.dx + menuWidth > screenWidth 
        ? screenWidth - menuWidth - 16 
        : globalOffset.dx;
    
    // 显示右键菜单
    MusicContextMenu.show(
      context,
      music,
      Offset(xOffset, globalOffset.dy),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final musicLibrary = Provider.of<MusicLibraryService>(context);
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    
    // 获取所有音乐文件列表
    List<MusicFile> musicFiles = List.from(musicLibrary.musicFiles);
    
    // 应用排序
    musicFiles.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      
      switch (_sortField) {
        case 'title':
          valueA = a.title.toLowerCase();
          valueB = b.title.toLowerCase();
          break;
        case 'artist':
          valueA = a.artist.toLowerCase();
          valueB = b.artist.toLowerCase();
          break;
        case 'album':
          valueA = a.album.toLowerCase();
          valueB = b.album.toLowerCase();
          break;
        case 'duration':
          valueA = a.duration.inSeconds;
          valueB = b.duration.inSeconds;
          break;
        default:
          valueA = a.title.toLowerCase();
          valueB = b.title.toLowerCase();
      }
      
      // 如果值相同，则按标题排序
      int result = Comparable.compare(valueA, valueB);
      if (result == 0 && _sortField != 'title') {
        result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      
      // 应用排序方向
      return _sortAscending ? result : -result;
    });
    
    if (musicFiles.isEmpty) {
      // 显示空状态
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '音乐库中没有歌曲',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击左侧"导入音乐"按钮添加歌曲',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      );
    }
    
    // 构建音乐列表视图
    return Column(
      children: [
        // 表头
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1
              )
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 30), // 给序号列留出空间
              const SizedBox(width: 8), // 与行内容的间距对齐
              const SizedBox(width: 40), // 给封面图片留出空间
              const SizedBox(width: 16), // 与行内容的间距对齐
              // 标题
              Expanded(
                flex: 3,
                child: _buildHeaderCell(
                  context, 
                  '标题', 
                  'title', 
                  tooltip: '按标题排序'
                ),
              ),
              // 艺术家
              Expanded(
                flex: 2,
                child: _buildHeaderCell(
                  context, 
                  '艺术家', 
                  'artist', 
                  tooltip: '按艺术家排序'
                ),
              ),
              // 专辑
              Expanded(
                flex: 2,
                child: _buildHeaderCell(
                  context, 
                  '专辑', 
                  'album',
                  tooltip: '按专辑排序'
                ),
              ),
              // 时长
              SizedBox(
                width: 60,
                child: _buildHeaderCell(
                  context, 
                  '时长', 
                  'duration',
                  tooltip: '按时长排序'
                ),
              ),
              const SizedBox(width: 16), // 右侧边距
            ],
          ),
        ),
        // 列表内容
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            itemCount: musicFiles.length,
            itemBuilder: (context, index) {
              final music = musicFiles[index];
              final isCurrentSong = audioPlayer.currentMusic?.id == music.id;
              final isPlaying = isCurrentSong && audioPlayer.playbackState == PlaybackState.playing;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: HoverWidget(
                  builder: (context, isHovered) {
                    return GestureDetector(
                      // 添加长按和右键点击支持
                      onSecondaryTapDown: (details) => _showContextMenu(context, music, details),
                      onLongPress: () {
                        // 在移动设备上使用长按触发上下文菜单
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final Offset position = box.localToGlobal(Offset.zero);
                        _showContextMenu(
                          context, 
                          music, 
                          TapDownDetails(
                            globalPosition: Offset(position.dx + 40, position.dy + box.size.height / 2),
                            localPosition: Offset(40, box.size.height / 2),
                            kind: PointerDeviceKind.touch,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrentSong
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : isHovered
                                ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                                : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _playSong(music);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  // 序号
                                  SizedBox(
                                    width: 30,
                                    child: Center(
                                      child: isPlaying
                                        ? Icon(
                                            Icons.volume_up,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.primary,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isCurrentSong
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 封面图片
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(5),
                                      boxShadow: isCurrentSong ? [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ] : null,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _buildCoverImage(music, isCurrentSong),
                                  ),
                                  const SizedBox(width: 16),
                                  // 标题
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      music.title,
                                      style: TextStyle(
                                        fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                                        color: isCurrentSong
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // 艺术家
                                  Expanded(
                                    flex: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        // 导航到艺术家详情页
                                        if (music.artist.isNotEmpty && music.artist != '未知艺术家') {
                                          ArtistSelectedNotification(music.artist).dispatch(context);
                                        }
                                      },
                                      child: Text(
                                        music.artist,
                                        style: TextStyle(
                                          color: music.artist.isNotEmpty && music.artist != '未知艺术家'
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 专辑
                                  Expanded(
                                    flex: 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        // 导航到专辑详情页
                                        if (music.album.isNotEmpty && music.album != '未知专辑') {
                                          AlbumSelectedNotification(music.album, music.artist).dispatch(context);
                                        }
                                      },
                                      child: Text(
                                        music.album,
                                        style: TextStyle(
                                          color: music.album.isNotEmpty && music.album != '未知专辑'
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // 时长
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      _formatDuration(music.duration),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  // 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
} 