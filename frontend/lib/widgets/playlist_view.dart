import 'dart:io';
import 'dart:typed_data';
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
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final songs = playlistService.getPlaylistSongs(widget.playlist.id);
    
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
                image: widget.playlist.getCoverImage(playlistService.allMusicFiles) != null
                    ? DecorationImage(
                        image: FileImage(File(widget.playlist.getCoverImage(playlistService.allMusicFiles)!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.playlist.getCoverImage(playlistService.allMusicFiles) == null
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
                if (widget.playlist.description.isNotEmpty) ...[
                  Text(
                    widget.playlist.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '包含 ${songs.length} 首歌曲',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                // 操作按钮
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放全部'),
                      onPressed: songs.isEmpty ? null : _playAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('随机播放'),
                      onPressed: songs.isEmpty ? null : _shufflePlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const Spacer(),
                    // 编辑和删除按钮
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑歌单',
                      onPressed: _showEditPlaylistDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: '删除歌单',
                      onPressed: _showDeletePlaylistDialog,
                      color: Theme.of(context).colorScheme.error,
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

  // 构建歌曲列表
  Widget _buildSongList() {
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    final playlistService = Provider.of<PlaylistService>(context);
    final songs = playlistService.getPlaylistSongs(widget.playlist.id);
    
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              '歌单暂无歌曲',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final music = songs[index];
        final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                         audioPlayer.playbackState == PlaybackState.playing;
        
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildCoverImage(music),
          ),
          title: Text(
            music.title.isNotEmpty ? music.title : '未知歌曲',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            music.artist.isNotEmpty ? music.artist : '未知艺术家',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.7) 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSongOptions(music),
          ),
          onTap: () => _playSong(index),
        );
      },
    );
  }
  
  // 构建封面图片
  Widget _buildCoverImage(MusicFile music) {
    if (music.coverPath != null && File(music.coverPath!).existsSync()) {
      return Hero(
        tag: 'cover-${music.id}',
        child: Image.file(
          File(music.coverPath!),
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildFallbackCover(music),
        ),
      );
    } else if (music.hasEmbeddedCover && music.embeddedCoverBytes != null) {
      return Hero(
        tag: 'embedded-cover-${music.id}',
        child: Image.memory(
          Uint8List.fromList(music.embeddedCoverBytes!),
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildFallbackCover(music),
        ),
      );
    } else {
      return _buildFallbackCover(music);
    }
  }
  
  // 构建默认封面
  Widget _buildFallbackCover(MusicFile music) {
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                     audioPlayer.playbackState == PlaybackState.playing;
    
    return Hero(
      tag: 'no-cover-${music.id}',
      child: Container(
        width: 40,
        height: 40,
        color: isPlaying 
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceVariant,
        child: Icon(
          Icons.music_note,
          size: 24,
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
    );
  }

  // 播放全部
  void _playAll() {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final songs = playlistService.getPlaylistSongs(widget.playlist.id);
    if (songs.isEmpty) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs);
    audioPlayer.playMusic(songs.first);
  }

  // 随机播放
  void _shufflePlay() {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final songs = playlistService.getPlaylistSongs(widget.playlist.id);
    if (songs.isEmpty) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs, shuffle: true);
    
    audioPlayer.playMusic(songs.first);
  }

  // 播放指定歌曲
  void _playSong(int index) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final songs = playlistService.getPlaylistSongs(widget.playlist.id);
    if (songs.isEmpty || index >= songs.length) return;

    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.setPlaylist(songs, initialIndex: index);
    audioPlayer.playMusic(songs[index]);
  }

  // 从歌单中移除歌曲
  void _removeFromPlaylist(MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    // 从歌单中移除
    playlistService.removeSongFromPlaylist(widget.playlist.id, music);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已从歌单"${widget.playlist.name}"中移除')),
    );
  }

  // 显示歌曲操作选项
  void _showSongOptions(MusicFile music) {
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
                title: const Text('添加到其他歌单'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(music);
                },
              ),
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
                      playlistService.addSongToPlaylist(playlist.id, music.copy());
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
                  await playlistService.addSongToPlaylist(playlist.id, music.copy());
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
    final nameController = TextEditingController(text: widget.playlist.name);
    final descriptionController = TextEditingController(text: widget.playlist.description);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑歌单'),
          content: SizedBox(
            width: 400,
            child: Column(
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
                  decoration: const InputDecoration(
                    labelText: '歌单描述',
                    hintText: '请输入歌单描述（可选）',
                  ),
                  maxLines: 3,
                ),
              ],
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
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('歌单名称不能为空')),
                  );
                  return;
                }
                
                // 检查是否有变化
                final nameChanged = name != widget.playlist.name;
                final descriptionChanged = description != widget.playlist.description;
                
                if (nameChanged || descriptionChanged) {
                  // 使用updatePlaylist方法更新歌单信息
                  playlistService.updatePlaylist(
                    widget.playlist.id, 
                    newName: nameChanged ? name : null,
                    newDescription: descriptionChanged ? description : null
                  );
                  
                  Navigator.pop(context);
                  setState(() {});
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