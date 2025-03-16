import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/widgets/settings_panel.dart';
import 'package:slahser_player/widgets/playlist_view.dart';
import 'dart:io';
import '../enums/playback_state.dart';
import 'dart:typed_data';

// 内容类型枚举
enum ContentType {
  allMusic,     // 所有音乐
  favoriteMusic, // 我喜欢的音乐
  playlists,    // 歌单列表
  playlistDetail, // 歌单详情
  settings,     // 设置
}

class ContentArea extends StatefulWidget {
  final ContentType contentType;

  const ContentArea({super.key, required this.contentType});

  @override
  State<ContentArea> createState() => ContentAreaState();
}

class ContentAreaState extends State<ContentArea> {
  late ContentType _contentType;
  String? _selectedPlaylistId; // 当前选中的歌单ID
  
  // 排序相关的状态
  String _sortField = 'title'; // 默认按标题排序
  bool _sortAscending = true; // 默认升序排序

  @override
  void initState() {
    super.initState();
    _contentType = widget.contentType;
  }

  void showContent(ContentType contentType, {String? playlistId}) {
    setState(() {
      _contentType = contentType;
      if (playlistId != null) {
        _selectedPlaylistId = playlistId;
      } else if (contentType != ContentType.playlistDetail) {
        _selectedPlaylistId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_contentType) {
      case ContentType.settings:
        return const SettingsPanel();
        
      case ContentType.favoriteMusic:
        return Consumer<PlaylistService>(
          builder: (context, playlistService, child) {
            final favoritePlaylist = playlistService.getFavoritesPlaylist();
            return PlaylistView(playlist: favoritePlaylist);
          },
        );
        
      case ContentType.playlists:
        return _buildPlaylistsContent();
        
      case ContentType.playlistDetail:
        if (_selectedPlaylistId != null) {
          return Consumer<PlaylistService>(
            builder: (context, playlistService, child) {
              final playlist = playlistService.getPlaylist(_selectedPlaylistId!);
              if (playlist == null) {
                return const Center(child: Text('歌单不存在'));
              }
              return PlaylistView(playlist: playlist);
            },
          );
        }
        return const Center(child: Text('未选中歌单'));
        
      case ContentType.allMusic:
      default:
        return _buildMusicContent();
    }
  }

  // 构建歌单列表内容
  Widget _buildPlaylistsContent() {
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
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return _buildPlaylistCard(context, playlist);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // 构建歌单卡片
  Widget _buildPlaylistCard(BuildContext context, Playlist playlist) {
    return InkWell(
      onTap: () {
        showContent(ContentType.playlistDetail, playlistId: playlist.id);
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
                  image: playlist.getCoverImage() != null
                      ? DecorationImage(
                          image: FileImage(File(playlist.getCoverImage()!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: playlist.getCoverImage() == null
                    ? Center(
                        child: Icon(
                          Icons.music_note,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
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
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songs.length}首歌',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '歌单名称',
              hintText: '请输入歌单名称',
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final playlist = await playlistService.createPlaylist(name);
                  if (context.mounted) {
                    Navigator.pop(context);
                    // 创建后直接显示歌单详情
                    showContent(ContentType.playlistDetail, playlistId: playlist.id);
                  }
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicContent() {
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
              size: 32,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.08),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                width: 1
              )
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 56), // 给左侧图标留出空间
              const SizedBox(width: 30), // 给序号列留出空间
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
              Expanded(
                child: _buildHeaderCell(
                  context, 
                  '时长', 
                  'duration',
                  tooltip: '按时长排序',
                  textAlign: TextAlign.right
                ),
              ),
              const SizedBox(width: 100), // 留出右侧操作按钮的空间
            ],
          ),
        ),
        // 音乐列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(0), // 移除默认内边距
            itemCount: sortedMusicFiles.length,
            itemBuilder: (context, index) {
              final music = sortedMusicFiles[index];
              final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                              audioPlayer.playbackState == PlaybackState.playing;
              final isFavorite = playlistService.isSongInFavorites(music.id);
              
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _playSong(music);
                      },
                      hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // 序号列
                            SizedBox(
                              width: 30,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isPlaying 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: isPlaying ? FontWeight.bold : null,
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: _buildCoverImage(music, isPlaying),
                              ),
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
                                  color: isPlaying ? Theme.of(context).colorScheme.primary : null,
                                  fontWeight: isPlaying ? FontWeight.bold : null,
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isPlaying 
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isPlaying 
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                            ),
                            // 时长
                            Expanded(
                              child: Container(
                                alignment: Alignment.centerRight, // 确保内容右对齐
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  _formatDuration(music.duration),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: isPlaying
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            // 操作按钮区域
                            const SizedBox(width: 8),
                            // 收藏按钮
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : null,
                                size: 20,
                              ),
                              onPressed: () {
                                if (isFavorite) {
                                  playlistService.removeFromFavorites(music.id);
                                } else {
                                  playlistService.addToFavorites(music);
                                }
                              },
                            ),
                            // 更多选项按钮
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () {
                                _showMusicOptions(context, music);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 分隔线
                  if (index < sortedMusicFiles.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 72,
                      endIndent: 16,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                ],
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
    
    return InkWell(
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
        child: Padding(
          padding: EdgeInsets.only(
            top: 8, 
            bottom: 8, 
            left: 4, 
            right: textAlign == TextAlign.right ? 8.0 : 4.0 // 时长列增加右侧内边距
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: textAlign == TextAlign.right 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: textAlign == TextAlign.right 
                      ? MainAxisAlignment.end 
                      : MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: textAlign,
                    ),
                    if (isActive)
                      Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  void _importMusicFiles(BuildContext context) {
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    musicLibrary.importMusicFiles();
  }
  
  void _importMusicFolder(BuildContext context) {
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    musicLibrary.importMusicFolder();
  }
  
  void _playSong(MusicFile music) {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final musicLibrary = Provider.of<MusicLibraryService>(context, listen: false);
    
    // 获取当前内容类型
    final contentType = widget.contentType;
    
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
                leading: Icon(
                  playlistService.isSongInFavorites(music.id) 
                      ? Icons.favorite 
                      : Icons.favorite_border,
                ),
                title: Text(
                  playlistService.isSongInFavorites(music.id) 
                      ? '取消收藏' 
                      : '收藏到我喜欢的音乐',
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (playlistService.isSongInFavorites(music.id)) {
                    playlistService.removeFromFavorites(music.id);
                  } else {
                    playlistService.addToFavorites(music);
                  }
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
                final bool alreadyInPlaylist = playlist.songs.any((song) => song.id == music.id);
                
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songs.length}首歌'),
                  trailing: alreadyInPlaylist 
                      ? const Icon(Icons.check, color: Colors.green) 
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!alreadyInPlaylist) {
                      playlistService.addSongToPlaylist(playlist.id, music);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已添加到歌单"${playlist.name}"')),
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
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新歌单'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '歌单名称',
              hintText: '请输入歌单名称',
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final playlist = await playlistService.createPlaylist(name);
                  await playlistService.addSongToPlaylist(playlist.id, music);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已添加到新歌单"${playlist.name}"')),
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
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isPlaying 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: isPlaying
              ? Icon(
                  Icons.play_arrow,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                )
              : Text(
                  '${music.trackNumber?.toString() ?? "-"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
        );
      }
    );
  }

  Widget _buildCoverImage(MusicFile music, bool isPlaying) {
    if (music.coverPath != null) {
      return Hero(
        tag: 'cover-${music.id}',
        child: Image.file(
          File(music.coverPath!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackCover(isPlaying);
          },
        ),
      );
    } else if (music.hasEmbeddedCover()) {
      return Hero(
        tag: 'embedded-cover-${music.id}',
        child: Image.memory(
          Uint8List.fromList(music.getCoverBytes()!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackCover(isPlaying);
          },
        ),
      );
    } else {
      return Hero(
        tag: 'no-cover-${music.id}',
        child: _buildFallbackCover(isPlaying),
      );
    }
  }

  Widget _buildFallbackCover(bool isPlaying) {
    return Container(
      color: isPlaying 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
          : Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 20,
          color: isPlaying 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }
} 