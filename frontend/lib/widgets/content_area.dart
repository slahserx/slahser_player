import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/widgets/settings_panel.dart';
import 'package:slahser_player/widgets/playlist_view.dart';
import 'package:slahser_player/pages/artist_detail_page.dart';
import 'package:slahser_player/pages/album_detail_page.dart';
import 'dart:io';
import '../enums/playback_state.dart';
import 'dart:typed_data';
import 'package:slahser_player/utils/page_transitions.dart';
import '../enums/content_type.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'dart:convert';
import 'package:slahser_player/widgets/custom_snackbar.dart';

// 鼠标悬停检测组件
class HoverWidget extends StatefulWidget {
  final Widget Function(BuildContext, bool isHovered) builder;
  
  const HoverWidget({super.key, required this.builder});
  
  @override
  State<HoverWidget> createState() => _HoverWidgetState();
}

class _HoverWidgetState extends State<HoverWidget> {
  bool isHovered = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: widget.builder(context, isHovered),
    );
  }
}

// 定义一个自定义通知，用于告诉HomePage切换到特定歌单
class PlaylistSelectedNotification extends Notification {
  final String playlistId;
  
  PlaylistSelectedNotification(this.playlistId);
}

/// 应用程序的主要内容区域
class ContentArea extends StatefulWidget {
  /// 当前选择的内容类型
  final ContentType selectedContentType;
  
  /// 当前选择的播放列表ID（可选）
  final String? selectedPlaylistId;
  
  const ContentArea({
    super.key,
    required this.selectedContentType,
    this.selectedPlaylistId,
  });
  
  @override
  State<ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<ContentArea> {
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
  
  @override
  Widget build(BuildContext context) {
    // 根据选择的内容类型显示不同的内容
    Widget content;
    
    switch (widget.selectedContentType) {
      case ContentType.allMusic:
        content = ContentAreaTransition(
          appearing: true,
          child: _buildAllMusicView(context),
        );
        break;
      case ContentType.artists:
        content = ContentAreaTransition(
          appearing: true,
          child: _buildArtistsView(context),
        );
        break;
      case ContentType.albums:
        content = ContentAreaTransition(
          appearing: true,
          child: _buildAlbumsView(context),
        );
        break;
      case ContentType.playlists:
        content = ContentAreaTransition(
          appearing: true,
          child: _buildPlaylistsView(context),
        );
        break;
      case ContentType.playlist:
        final playlistService = Provider.of<PlaylistService>(context);
        
        // 如果没有选择播放列表ID，显示错误信息
        if (widget.selectedPlaylistId == null) {
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
          final playlist = playlistService.getPlaylist(widget.selectedPlaylistId!);
          
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
      case ContentType.settings:
        content = ContentAreaTransition(
          appearing: true,
          child: const SettingsPanel(),
        );
        break;
      default:
        // 默认显示所有音乐
        content = ContentAreaTransition(
          appearing: true,
          child: _buildAllMusicView(context),
        );
    }
    
    // 添加背景颜色
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: content,
    );
  }

  Widget _buildAllMusicView(BuildContext context) {
    return Column(
      children: [
        // 搜索栏和导入按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 搜索栏
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索音乐',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // 导入音乐按钮
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () {
                  _importMusicFiles(context);
                },
                icon: const Icon(Icons.audio_file),
                tooltip: '导入音乐文件',
              ),
              // 导入文件夹按钮
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  _importMusicFolder(context);
                },
                icon: const Icon(Icons.folder),
                tooltip: '导入音乐文件夹',
              ),
            ],
          ),
        ),
        // 内容区域
        Expanded(
          child: Consumer<MusicLibraryService>(
            builder: (context, musicLibrary, child) {
              if (musicLibrary.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (musicLibrary.musicFiles.isEmpty) {
                return _buildEmptyState(context);
              }
              
              return _buildMusicList(context, musicLibrary.musicFiles);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 音乐图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.music_note,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          // 提示文字
          Text(
            '还没有音乐',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮导入音乐',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 24),
          // 导入按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  _importMusicFiles(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('导入音乐文件'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  _importMusicFolder(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('导入音乐文件夹'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMusicList(BuildContext context, List<MusicFile> musicFiles) {
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    final playlistService = Provider.of<PlaylistService>(context);
    
    // 根据当前排序字段和排序方向对音乐文件进行排序
    List<MusicFile> sortedMusicFiles = List.from(musicFiles);
    sortedMusicFiles.sort((a, b) {
      int result;
      switch (_sortField) {
        case 'title':
          result = a.title.compareTo(b.title);
          break;
        case 'artist':
          result = a.artist.compareTo(b.artist);
          break;
        case 'album':
          result = a.album.compareTo(b.album);
          break;
        case 'duration':
          result = a.duration.compareTo(b.duration);
          break;
        default:
          result = a.title.compareTo(b.title);
      }
      return _sortAscending ? result : -result;
    });
    
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
                width: 76,
                child: _buildHeaderCell(
                  context, 
                  '时长', 
                  'duration',
                  tooltip: '按时长排序',
                  textAlign: TextAlign.right
                ),
              ),
              const SizedBox(width: 40), // 给更多按钮留出空间
            ],
          ),
        ),
        // 音乐列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedMusicFiles.length,
            cacheExtent: 1000, // 增加缓存范围，减少重建
            addRepaintBoundaries: true, // 添加重绘边界
            itemBuilder: (context, index) {
              final music = sortedMusicFiles[index];
              // 使用Consumer包装，确保播放状态变化时UI能正确更新
              return RepaintBoundary(
                child: Consumer<AudioPlayerService>(
                  builder: (context, audioPlayer, child) {
                    final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                                    audioPlayer.playbackState == PlaybackState.playing;
                    final isPaused = audioPlayer.currentMusic?.id == music.id && 
                                    audioPlayer.playbackState == PlaybackState.paused;
                    final isCurrentSong = audioPlayer.currentMusic?.id == music.id;

                    // 调试信息，查看歌曲ID是否匹配以及播放状态
                    // 为每一行添加调试信息
                    if (isCurrentSong) {
                      // 只对当前歌曲打印详细状态
                      debugPrint('当前歌曲: ${music.title}, ID: ${music.id}');
                      debugPrint('播放状态: ${audioPlayer.playbackState}, isPlaying: $isPlaying, isPaused: $isPaused');
                      debugPrint('当前状态对象: ${audioPlayer.playbackState.toString()}');
                    }

                    return HoverWidget(
                      builder: (context, isHovered) {
                        return Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _playSong(music);
                                },
                                borderRadius: BorderRadius.circular(6),
                                hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: isCurrentSong
                                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6)
                                        : isHovered 
                                            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                                            : Colors.transparent,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: [
                                        // 序号列/播放状态
                                        Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isCurrentSong
                                                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                                : isHovered
                                                    ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8)
                                                    : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: isCurrentSong
                                              ? AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 300),
                                                  child: isPlaying
                                                      ? Icon(
                                                          Icons.graphic_eq,
                                                          key: const ValueKey('playing'),
                                                          size: 22,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        )
                                                      : Icon(
                                                          Icons.pause,
                                                          key: const ValueKey('paused'),
                                                          size: 18,
                                                          color: Theme.of(context).colorScheme.onPrimary,
                                                        ),
                                                )
                                              : isHovered
                                                  ? const Icon(
                                                      Icons.play_arrow,
                                                      size: 20,
                                                      color: Colors.white,
                                                    )
                                                  : Text(
                                                      '${index + 1}',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
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
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrentSong 
                                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                                  : Theme.of(context).colorScheme.onSurface,
                                              fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        // 艺术家
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            music.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrentSong 
                                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontWeight: isCurrentSong ? FontWeight.w500 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        // 专辑
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            music.album,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isCurrentSong 
                                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontWeight: isCurrentSong ? FontWeight.w500 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        // 时长
                                        SizedBox(
                                          width: 76,
                                          child: Text(
                                            _formatDuration(music.duration),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: isCurrentSong 
                                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                              fontWeight: isCurrentSong ? FontWeight.w500 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        // 更多按钮
                                        SizedBox(
                                          width: 40,
                                          child: IconButton(
                                            icon: const Icon(Icons.more_vert, size: 16),
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            onPressed: () {
                                              _showMusicOptions(context, music);
                                            },
                                            tooltip: '更多选项',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                        );
                      },
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
  
  // 表头单元格
  Widget _buildHeaderCell(
    BuildContext context, 
    String title, 
    String fieldName, {
    String? tooltip,
    TextAlign textAlign = TextAlign.left
  }) {
    final bool isActive = _sortField == fieldName;
    
    return HoverWidget(
      builder: (context, isHovered) {
        final Color textColor = isActive 
            ? Theme.of(context).colorScheme.primary 
            : isHovered
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.75);
                
        return GestureDetector(
          onTap: () {
            setState(() {
              if (_sortField == fieldName) {
                // 如果已经按照这个字段排序，则切换排序方向
                _sortAscending = !_sortAscending;
              } else {
                // 否则，切换排序字段并设置为升序
                _sortField = fieldName;
                _sortAscending = true;
              }
            });
          },
          child: Tooltip(
            message: tooltip ?? '排序',
            child: Container(
              padding: EdgeInsets.only(
                top: 6, 
                bottom: 6, 
                left: fieldName == 'title' ? 0 : 8, // 标题列不需要左内边距
                right: textAlign == TextAlign.right ? 0 : 8.0 // 时长列不需要右内边距
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isHovered
                    ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: textAlign == TextAlign.right 
                    ? MainAxisAlignment.end 
                    : MainAxisAlignment.start,
                children: [
                  if (isActive && textAlign != TextAlign.right)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: 0.3,
                      color: textColor,
                    ),
                    textAlign: textAlign,
                  ),
                  if (isActive && textAlign == TextAlign.right)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  void _importMusicFiles(BuildContext context) async {
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    final result = await musicLibrary.importMusicFiles();
    
    if (context.mounted) {
      if (result['success']) {
        // 如果有跳过的文件，使用信息提示，否则使用成功提示
        if (result['skipped'] > 0) {
          CustomSnackBar.showInfo(context, result['message']);
        } else {
          CustomSnackBar.showSuccess(context, result['message']);
        }
      } else {
        CustomSnackBar.showWarning(context, result['message']);
      }
    }
  }
  
  void _importMusicFolder(BuildContext context) async {
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    final result = await musicLibrary.importMusicFolder();
    
    if (context.mounted) {
      if (result['success']) {
        // 如果有跳过的文件，使用信息提示，否则使用成功提示
        if (result['skipped'] > 0) {
          CustomSnackBar.showInfo(context, result['message']);
        } else {
          CustomSnackBar.showSuccess(context, result['message']);
        }
      } else {
        CustomSnackBar.showWarning(context, result['message']);
      }
    }
  }
  
  void _playSong(MusicFile music) {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    
    // 获取当前内容类型
    final contentType = widget.selectedContentType;
    
    if (contentType == ContentType.allMusic) {
      // 在所有歌曲视图中，将所有歌曲添加到播放列表
      final allSongs = musicLibrary.musicFiles;
      // 找到点击歌曲在列表中的索引
      final index = allSongs.indexWhere((song) => song.id == music.id);
      if (index != -1) {
        audioPlayer.setPlaylist(allSongs, initialIndex: index);
        audioPlayer.playMusic(music);
      }
    } else {
      // 其他情况下只播放单曲
      audioPlayer.setPlaylist([music], initialIndex: 0);
      audioPlayer.playMusic(music);
    }
  }
  
  void _showMusicOptions(BuildContext context, MusicFile music) {
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('播放'),
                onTap: () {
                  Navigator.pop(context);
                  audioPlayer.playMusic(music);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('添加到歌单'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, music, playlistService);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('从音乐库中删除'),
                onTap: () {
                  Navigator.pop(context);
                  musicLibrary.removeMusicFile(music.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 显示添加到歌单的对话框
  void _showAddToPlaylistDialog(BuildContext context, MusicFile music, PlaylistService playlistService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加到歌单'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: ListView.builder(
              itemCount: playlistService.playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlistService.playlists[index];
                final songs = playlistService.getPlaylistSongs(playlist.id);
                final bool alreadyInPlaylist = songs.any((song) => song.id == music.id);
                
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text('${songs.length}首歌'),
                  trailing: alreadyInPlaylist 
                      ? const Icon(Icons.check, color: Colors.green) 
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!alreadyInPlaylist) {
                      playlistService.addSongToPlaylist(playlist.id, music);
                      CustomSnackBar.showSuccess(
                        context, 
                        '已添加到歌单"${playlist.name}"'
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // 创建新歌单并添加歌曲
                _showCreatePlaylistWithSongDialog(context, music, playlistService);
              },
              child: const Text('创建新歌单'),
            ),
          ],
        );
      },
    );
  }
  
  // 显示创建新歌单并添加歌曲的对话框
  void _showCreatePlaylistWithSongDialog(BuildContext context, MusicFile music, PlaylistService playlistService) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '歌单名称',
                  hintText: '请输入歌单名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '歌单描述',
                  hintText: '请输入歌单描述（可选）',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // 创建新歌单并添加歌曲
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                if (name.isNotEmpty) {
                  final playlist = await playlistService.createPlaylist(name, description: description);
                  await playlistService.addSongToPlaylist(playlist.id, music);
                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomSnackBar.showSuccess(
                      context, 
                      '已添加到新歌单"${playlist.name}"'
                    );
                  }
                }
              },
              child: const Text('创建并添加'),
            ),
          ],
        );
      },
    );
  }

  // 构建播放列表状态图标
  Widget _buildPlayingStatusIcon(BuildContext context, AudioPlayerService audioPlayer, MusicFile music) {
    return StreamBuilder<PlaybackState>(
      stream: audioPlayer.playbackState,
      initialData: PlaybackState.stopped,
      builder: (context, snapshot) {
        final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                         snapshot.data == PlaybackState.playing;
        
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPlaying 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: isPlaying
              ? Icon(
                  Icons.equalizer,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : Text(
                  '${music.trackNumber?.toString() ?? "-"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCoverImage(MusicFile music, bool isCurrentSong) {
    // 使用Key确保Widget在更新时保持状态
    final heroTag = music.coverPath != null 
        ? 'list-cover-${music.id}' 
        : music.hasEmbeddedCover 
            ? 'list-embedded-cover-${music.id}' 
            : 'list-no-cover-${music.id}';
            
    return RepaintBoundary(
      child: Hero(
        tag: heroTag,
        child: _buildCoverImageContent(music, isCurrentSong),
      ),
    );
  }
  
  Widget _buildCoverImageContent(MusicFile music, bool isCurrentSong) {
    if (music.coverPath != null) {
      return Image.file(
        File(music.coverPath!),
        fit: BoxFit.cover,
        width: 40,
        height: 40,
        gaplessPlayback: true,
        cacheWidth: 80,
        cacheHeight: 80,
        key: ValueKey('file-cover-${music.id}'),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return AnimatedOpacity(
            opacity: 0.0,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
      );
    } else if (music.hasEmbeddedCover) {
      // 检查是否已经缓存了图片数据
      if (_coverImageCache.containsKey(music.id)) {
        return Image.memory(
          _coverImageCache[music.id]!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: 40,
          height: 40,
          cacheWidth: 80,
          key: ValueKey('memory-cover-${music.id}'),
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackCover(isCurrentSong);
          },
        );
      }
      
      return FutureBuilder<List<int>?>(
        key: ValueKey('future-cover-${music.id}'),
        future: music.getCoverBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildFallbackCover(isCurrentSong);
          }
          
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            // 缓存图片数据
            final imageData = Uint8List.fromList(snapshot.data!);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_coverImageCache.containsKey(music.id)) {
                setState(() {
                  _coverImageCache[music.id] = imageData;
                });
              }
            });
            
            return Image.memory(
              imageData,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              width: 40,
              height: 40,
              cacheWidth: 80,
              key: ValueKey('dynamic-cover-${music.id}'),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackCover(isCurrentSong);
              },
            );
          } else {
            return _buildFallbackCover(isCurrentSong);
          }
        },
      );
    } else {
      return _buildFallbackCover(isCurrentSong);
    }
  }

  Widget _buildFallbackCover(bool isCurrentSong) {
    return Container(
      color: isCurrentSong 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
          : Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 20,
          color: isCurrentSong 
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }

  // 构建歌单列表内容
  Widget _buildPlaylistsView(BuildContext context) {
    return Consumer<PlaylistService>(
      builder: (context, playlistService, child) {
        final playlists = playlistService.playlists;
        
        return Column(
          children: [
            // 页面标题和操作按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '我的歌单',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('新建歌单'),
                    onPressed: () {
                      _showCreatePlaylistDialog(context, playlistService);
                    },
                  ),
                ],
              ),
            ),
            
            // 歌单列表
            Expanded(
              child: playlists.isEmpty
                  ? const Center(child: Text('暂无歌单，点击"新建歌单"创建一个吧！'))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return _buildPlaylistCard(context, playlist, playlistService);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  
  // 构建歌单卡片
  Widget _buildPlaylistCard(BuildContext context, Playlist playlist, PlaylistService playlistService) {
    return InkWell(
      onTap: () {
        // 发送通知，通知HomePage切换到特定歌单
        PlaylistSelectedNotification(playlist.id).dispatch(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 歌单封面
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  image: playlist.getCoverImage(playlistService.allMusicFiles) != null
                      ? DecorationImage(
                          image: FileImage(File(playlist.getCoverImage(playlistService.allMusicFiles)!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: playlist.getCoverImage(playlistService.allMusicFiles) == null
                    ? Center(
                        child: Icon(
                          Icons.music_note,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                      )
                    : null,
              ),
            ),
            // 歌单信息
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlistService.getPlaylistSongs(playlist.id).length}首歌',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 显示创建歌单对话框
  void _showCreatePlaylistDialog(BuildContext context, PlaylistService playlistService) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '歌单名称',
                  hintText: '请输入歌单名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '歌单描述',
                  hintText: '请输入歌单描述（可选）',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                if (name.isNotEmpty) {
                  await playlistService.createPlaylist(name, description: description);
                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomSnackBar.showSuccess(
                      context, 
                      '歌单"$name"创建成功'
                    );
                  }
                } else {
                  CustomSnackBar.showWarning(
                    context, 
                    '歌单名称不能为空'
                  );
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  // 添加歌手视图
  Widget _buildArtistsView(BuildContext context) {
    return Consumer<MusicLibraryService>(
      builder: (context, musicLibrary, child) {
        if (musicLibrary.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (musicLibrary.musicFiles.isEmpty) {
          return _buildEmptyState(context);
        }
        
        // 获取所有不重复的歌手
        final artists = musicLibrary.musicFiles
            .map((music) => music.artist)
            .where((artist) => artist.isNotEmpty)
            .toSet()
            .toList();
        
        // 按字母顺序排序
        artists.sort();
        
        if (artists.isEmpty) {
          return Center(
            child: Text(
              '没有找到歌手',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            
            // 获取该歌手的所有歌曲
            final artistSongs = musicLibrary.musicFiles
                .where((music) => music.artist == artist)
                .toList();
            
            return HoverWidget(
              builder: (context, isHovered) {
                return GestureDetector(
                  onTap: () {
                    // 显示歌手详情页面
                    _showArtistDetailPage(context, artist, artistSongs);
                  },
                  child: Column(
                    children: [
                      // 歌手头像
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isHovered 
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3) 
                                  : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                              width: isHovered ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isHovered 
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: isHovered
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          ),
                        ),
                      ),
                      // 歌手名称
                      Text(
                        artist,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                              color: isHovered 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 歌曲数量
                      Text(
                        '${artistSongs.length}首歌曲',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isHovered
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              height: 1.1,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  // 添加专辑视图
  Widget _buildAlbumsView(BuildContext context) {
    return Consumer<MusicLibraryService>(
      builder: (context, musicLibrary, child) {
        if (musicLibrary.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (musicLibrary.musicFiles.isEmpty) {
          return _buildEmptyState(context);
        }
        
        // 获取所有不重复的专辑
        final albums = musicLibrary.musicFiles
            .map((music) => music.album)
            .where((album) => album.isNotEmpty)
            .toSet()
            .toList();
        
        // 按字母顺序排序
        albums.sort();
        
        if (albums.isEmpty) {
          return Center(
            child: Text(
              '没有找到专辑',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            
            // 获取该专辑的所有歌曲
            final albumSongs = musicLibrary.musicFiles
                .where((music) => music.album == album)
                .toList();
            
            // 获取专辑的第一首歌曲，用于显示封面
            final firstSong = albumSongs.isNotEmpty ? albumSongs.first : null;
            
            // 获取专辑的艺术家
            final albumArtist = albumSongs.isNotEmpty ? albumSongs.first.artist : '未知艺术家';
            
            return HoverWidget(
              builder: (context, isHovered) {
                return GestureDetector(
                  onTap: () {
                    // 显示专辑详情页面
                    _showAlbumDetailPage(context, album, albumArtist, albumSongs);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 专辑封面
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 专辑封面背景
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: firstSong?.embeddedCoverBytes != null
                                    ? Hero(
                                        tag: 'album-cover-${firstSong!.album}',
                                        child: RepaintBoundary(
                                          child: Image.memory(
                                            _coverImageCache.containsKey(firstSong.id) 
                                                ? _coverImageCache[firstSong.id]!
                                                : Uint8List.fromList(firstSong.embeddedCoverBytes!),
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            key: ValueKey('album-cover-${firstSong.id}'),
                                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                              // 使用frameBuilder来防止闪烁
                                              if (wasSynchronouslyLoaded) {
                                                return child;
                                              }
                                              return AnimatedOpacity(
                                                opacity: frame == null ? 0 : 1,
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeOut,
                                                child: child,
                                              );
                                            },
                                            // 添加错误处理，在加载失败时使用默认图标
                                            errorBuilder: (context, error, stackTrace) {
                                              return _buildAlbumFallbackCover();
                                            },
                                          ),
                                        ),
                                      )
                                    : _buildAlbumFallbackCover(),
                              ),
                            ),
                            // 悬停时显示的播放按钮
                            if (isHovered)
                              GestureDetector(
                                onTap: () {
                                  // 播放专辑第一首歌曲
                                  if (albumSongs.isNotEmpty) {
                                    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                                    audioPlayer.setPlaylist(albumSongs);
                                    audioPlayer.playMusic(albumSongs.first);
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 专辑名称
                      Text(
                        album,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 艺术家名称
                      Text(
                        albumArtist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              height: 1.1,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 歌曲数量
                      Text(
                        '${albumSongs.length}首歌曲',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              height: 1.1,
                            ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 封面图片加载错误或没有封面时显示默认图标
  Widget _buildAlbumFallbackCover() {
    return Center(
      child: Icon(
        Icons.album,
        size: 80,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
      ),
    );
  }

  void _showArtistDetailPage(BuildContext context, String artist, List<MusicFile> artistSongs) {
    // 使用CustomPageTransition打开歌手详情页面
    Navigator.of(context).push(
      CustomPageTransition(
        page: ArtistDetailPage(
          artist: artist, 
          songs: artistSongs,
        ),
        type: PageTransitionType.scaleFade,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutQuart,
      ),
    );
  }

  void _showAlbumDetailPage(BuildContext context, String album, String albumArtist, List<MusicFile> albumSongs) {
    // 使用CustomPageTransition打开专辑详情页面
    Navigator.of(context).push(
      CustomPageTransition(
        page: AlbumDetailPage(
          album: album,
          artist: albumArtist,
          songs: albumSongs,
        ),
        type: PageTransitionType.scaleFade,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutQuart,
      ),
    );
  }
} 