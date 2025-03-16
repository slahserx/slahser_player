import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import '../enums/playback_state.dart';

class PlaylistView extends StatefulWidget {
  final Playlist playlist;

  const PlaylistView({
    super.key,
    required this.playlist,
  });

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 歌单标题和封面区域
        _buildPlaylistHeader(),
        // 歌曲列表
        Expanded(
          child: _buildSongList(),
        ),
      ],
    );
  }

  // 构建歌单头部
  Widget _buildPlaylistHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歌单封面
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                image: widget.playlist.getCoverImage() != null
                    ? DecorationImage(
                        image: FileImage(File(widget.playlist.getCoverImage()!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.playlist.getCoverImage() == null
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
          const SizedBox(width: 24),
          // 歌单信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlist.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.playlist.songs.length}首歌',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 16),
                // 操作按钮区
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放全部'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        _playAll();
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('随机播放'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        _shufflePlay();
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        widget.playlist.isDefault
                            ? Icons.favorite
                            : Icons.edit,
                        color: widget.playlist.isDefault ? Colors.red : null,
                      ),
                      onPressed: () {
                        if (!widget.playlist.isDefault) {
                          _showEditPlaylistDialog();
                        }
                      },
                    ),
                    if (!widget.playlist.isDefault)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _showDeletePlaylistDialog();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    final songs = widget.playlist.songs;
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '歌单内暂无歌曲',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final music = songs[index];
        final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                         audioPlayer.playbackState == PlaybackState.playing;
        
        return Material(
          color: Colors.transparent,
          child: ListTile(
            hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: isPlaying 
                  ? Icon(
                      Icons.play_arrow,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            title: Text(
              music.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isPlaying ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text(
              '${music.artist} · ${music.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isPlaying 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.playlist.isDefault)
                  // 只有默认歌单（我喜欢的音乐）显示收藏按钮
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () {
                      _removeFromPlaylist(music);
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      _removeFromPlaylist(music);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showSongOptions(music);
                  },
                ),
              ],
            ),
            onTap: () {
              _playSong(index);
            },
          ),
        );
      },
    );
  }

  // 播放所有歌曲（按顺序）
  void _playAll() {
    final songs = widget.playlist.songs;
    if (songs.isEmpty) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs);
    audioPlayer.playMusic(songs.first);
  }

  // 随机播放
  void _shufflePlay() {
    final songs = widget.playlist.songs;
    if (songs.isEmpty) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs, shuffle: true);
    
    audioPlayer.playMusic(songs.first);
  }

  // 播放指定歌曲
  void _playSong(int index) {
    final songs = widget.playlist.songs;
    if (songs.isEmpty || index >= songs.length) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs, initialIndex: index);
    audioPlayer.playMusic(songs[index]);
  }

  // 从歌单中移除歌曲
  void _removeFromPlaylist(MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    if (widget.playlist.isDefault) {
      // 从我喜欢的音乐中移除
      playlistService.removeFromFavorites(music.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从我喜欢的音乐中移除')),
      );
    } else {
      // 从普通歌单中移除
      playlistService.removeSongFromPlaylist(widget.playlist.id, music.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已从歌单"${widget.playlist.name}"中移除')),
      );
    }
  }

  // 显示歌曲操作选项
  void _showSongOptions(MusicFile music) {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
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
              if (!widget.playlist.isDefault)
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('添加到其他歌单'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToPlaylistDialog(music);
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
              if (!widget.playlist.isDefault)
                ListTile(
                  leading: const Icon(Icons.remove_circle),
                  title: const Text('从歌单中移除'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeFromPlaylist(music);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // 显示添加到其他歌单的对话框
  void _showAddToPlaylistDialog(MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
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
                
                // 排除当前歌单
                if (playlist.id == widget.playlist.id) {
                  return const SizedBox.shrink();
                }
                
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
                _showCreatePlaylistWithSongDialog(music);
              },
              child: const Text('创建新歌单'),
            ),
          ],
        );
      },
    );
  }

  // 显示创建新歌单并添加歌曲的对话框
  void _showCreatePlaylistWithSongDialog(MusicFile music) {
    final TextEditingController controller = TextEditingController();
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
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

  // 显示编辑歌单对话框
  void _showEditPlaylistDialog() {
    final TextEditingController controller = TextEditingController(text: widget.playlist.name);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑歌单'),
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
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && name != widget.playlist.name) {
                  playlistService.renamePlaylist(widget.playlist.id, name);
                  Navigator.pop(context);
                  setState(() {});
                } else if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('歌单名称不能为空')),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 显示删除歌单确认对话框
  void _showDeletePlaylistDialog() {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确定要删除歌单"${widget.playlist.name}"吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                playlistService.deletePlaylist(widget.playlist.id);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
} 