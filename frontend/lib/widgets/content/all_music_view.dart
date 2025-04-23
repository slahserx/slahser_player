import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'dart:typed_data';
import 'package:slahser_player/widgets/content/hover_widget.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import '../../enums/playback_state.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/widgets/custom_snackbar.dart';

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
  
  // 显示歌曲右键菜单
  void _showSongContextMenu(BuildContext context, MusicFile music, RelativeRect position) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'play',
          child: Row(
            children: const [
              Icon(Icons.play_arrow),
              SizedBox(width: 8),
              Text('播放'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Row(
            children: const [
              Icon(Icons.playlist_add),
              SizedBox(width: 8),
              Text('添加到歌单'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'open_location',
          child: Row(
            children: const [
              Icon(Icons.folder_open),
              SizedBox(width: 8),
              Text('查看文件所在位置'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'view_artist',
          child: Row(
            children: const [
              Icon(Icons.person),
              SizedBox(width: 8),
              Text('查看艺术家'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'view_album',
          child: Row(
            children: const [
              Icon(Icons.album),
              SizedBox(width: 8),
              Text('查看专辑'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      
      switch (value) {
        case 'play':
          _playSong(music);
          break;
        
        case 'add_to_playlist':
          _showAddToPlaylistDialog(music);
          break;
        
        case 'open_location':
          _openFileLocation(music);
          break;
        
        case 'view_artist':
          if (music.artist.isNotEmpty && music.artist != '未知艺术家') {
            ArtistSelectedNotification(music.artist).dispatch(context);
          }
          break;
        
        case 'view_album':
          if (music.album.isNotEmpty && music.album != '未知专辑') {
            AlbumSelectedNotification(music.album, music.artist).dispatch(context);
          }
          break;
      }
    });
  }

  // 显示添加到歌单对话框
  void _showAddToPlaylistDialog(MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final playlists = playlistService.playlists;
    
    if (playlists.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('添加到歌单'),
          content: const Text('还没有创建任何歌单'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showCreatePlaylistDialog(context, initialSongs: [music]);
              },
              child: const Text('新建歌单'),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到歌单'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(playlist.name),
                subtitle: Text('${playlist.songPaths.length}首'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await playlistService.addSongToPlaylist(playlist.id, music);
                  if (context.mounted) {
                    CustomSnackBar.showSuccess(context, '已添加到歌单"${playlist.name}"');
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showCreatePlaylistDialog(context, initialSongs: [music]);
            },
            child: const Text('新建歌单'),
          ),
        ],
      ),
    );
  }

  // 显示创建新播放列表对话框
  void _showCreatePlaylistDialog(BuildContext context, {List<MusicFile>? initialSongs}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                
                if (name.isNotEmpty) {
                  final playlistService = Provider.of<PlaylistService>(context, listen: false);
                  final playlist = await playlistService.createPlaylist(name, description: description);
                  
                  if (initialSongs != null && initialSongs.isNotEmpty) {
                    for (final song in initialSongs) {
                      await playlistService.addSongToPlaylist(playlist.id, song);
                    }
                    CustomSnackBar.showSuccess(context, '已创建歌单并添加选中歌曲');
                  }
                  
                  Navigator.of(context).pop();
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
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
              '点击下方按钮添加歌曲',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _importMusicFiles(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('导入音乐文件'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _importMusicFolder(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('导入音乐文件夹'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    // 构建音乐列表视图
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
                onPressed: () => _importMusicFiles(context),
                icon: const Icon(Icons.audio_file),
                tooltip: '导入音乐文件',
              ),
              // 导入文件夹按钮
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _importMusicFolder(context),
                icon: const Icon(Icons.folder),
                tooltip: '导入音乐文件夹',
              ),
            ],
          ),
        ),
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
                    return Container(
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
                          onTap: () => _playSong(music),
                          onSecondaryTapUp: (details) {
                            final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                            final RelativeRect position = RelativeRect.fromRect(
                              Rect.fromPoints(
                                details.globalPosition,
                                details.globalPosition,
                              ),
                              Offset.zero & overlay.size,
                            );
                            _showSongContextMenu(context, music, position);
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

  // 导入音乐文件
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
  
  // 导入音乐文件夹
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

  // 打开文件所在位置
  Future<void> _openFileLocation(MusicFile music) async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    final success = await audioPlayerService.openFileLocation(music);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开文件所在位置'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
} 