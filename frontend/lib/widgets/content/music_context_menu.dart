import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/widgets/custom_snackbar.dart';
import 'package:slahser_player/widgets/content/notifications.dart';

/// 音乐右键菜单组件
class MusicContextMenu extends StatelessWidget {
  /// 音乐文件
  final MusicFile music;
  
  /// 显示位置
  final Offset position;
  
  /// 菜单关闭回调
  final VoidCallback onClose;
  
  /// 构造函数
  const MusicContextMenu({
    super.key,
    required this.music,
    required this.position,
    required this.onClose,
  });
  
  /// 显示右键菜单
  static void show(BuildContext context, MusicFile music, Offset position) {
    // 首先关闭已经打开的菜单
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => MusicContextMenu(
        music: music,
        position: position,
        onClose: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    final playlistService = Provider.of<PlaylistService>(context);
    
    return Stack(
      children: [
        // 透明覆盖层，用于捕获点击事件关闭菜单
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // 菜单内容
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
            child: IntrinsicWidth(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 280,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 菜单标题
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            music.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (music.artist.isNotEmpty) 
                            Text(
                              music.artist,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    
                    const Divider(),
                    
                    // 菜单选项
                    _buildMenuItem(
                      context,
                      icon: Icons.play_arrow,
                      label: '播放',
                      onTap: () {
                        onClose();
                        audioPlayer.playMusic(music);
                      },
                    ),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.playlist_add,
                      label: '添加到播放列表',
                      onTap: () {
                        onClose();
                        _showAddToPlaylistDialog(context, music);
                      },
                    ),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.playlist_play,
                      label: '添加到播放队列',
                      onTap: () {
                        onClose();
                        audioPlayer.addToQueue(music);
                        CustomSnackBar.showSuccess(context, '已添加到播放队列');
                      },
                    ),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.queue_music,
                      label: '下一首播放',
                      onTap: () {
                        onClose();
                        audioPlayer.playNext(music);
                        CustomSnackBar.showSuccess(context, '已设置为下一首播放');
                      },
                    ),
                    
                    const Divider(),
                    
                    if (music.artist.isNotEmpty && music.artist != '未知艺术家')
                      _buildMenuItem(
                        context,
                        icon: Icons.person,
                        label: '查看艺术家: ${music.artist}',
                        onTap: () {
                          onClose();
                          _navigateToArtist(context, music.artist);
                        },
                      ),
                    
                    if (music.album.isNotEmpty && music.album != '未知专辑')
                      _buildMenuItem(
                        context,
                        icon: Icons.album,
                        label: '查看专辑: ${music.album}',
                        onTap: () {
                          onClose();
                          _navigateToAlbum(context, music.album, music.artist);
                        },
                      ),
                    
                    const Divider(),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.info_outline,
                      label: '查看详情',
                      onTap: () {
                        onClose();
                        _showMusicInfoDialog(context, music);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建菜单项
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 显示添加到播放列表对话框
  void _showAddToPlaylistDialog(BuildContext context, MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加到歌单'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: playlistService.playlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无歌单',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                            playlistService.addSongToPlaylist(playlist.id, music.copy());
                            CustomSnackBar.showSuccess(context, '已添加到歌单"${playlist.name}"');
                          } else {
                            CustomSnackBar.showInfo(context, '歌曲已在歌单"${playlist.name}"中');
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
              onPressed: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, music);
              },
              child: const Text('创建新歌单'),
            ),
          ],
        );
      },
    );
  }
  
  // 显示创建新歌单对话框
  void _showCreatePlaylistDialog(BuildContext context, MusicFile music) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
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
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  final playlist = await playlistService.createPlaylist(name, description: description);
                  await playlistService.addSongToPlaylist(playlist.id, music.copy());
                  
                  if (context.mounted) {
                    CustomSnackBar.showSuccess(context, '已创建歌单并添加歌曲');
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
  
  // 显示音乐详情对话框
  void _showMusicInfoDialog(BuildContext context, MusicFile music) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('歌曲信息'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoItem('标题', music.title),
                _buildInfoItem('艺术家', music.artist),
                _buildInfoItem('专辑', music.album),
                _buildInfoItem('时长', _formatDuration(music.duration)),
                _buildInfoItem('文件路径', music.filePath),
                if (music.fileSize != null)
                  _buildInfoItem('文件大小', _formatFileSize(music.fileSize!)),
                if (music.year != null && music.year!.isNotEmpty)
                  _buildInfoItem('年份', music.year!),
                if (music.genre != null && music.genre!.isNotEmpty)
                  _buildInfoItem('流派', music.genre!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
  
  // 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
          const Divider(),
        ],
      ),
    );
  }
  
  // 导航到艺术家页面
  void _navigateToArtist(BuildContext context, String artist) {
    // 发送导航到艺术家的通知
    ArtistSelectedNotification(artist).dispatch(context);
  }
  
  // 导航到专辑页面
  void _navigateToAlbum(BuildContext context, String album, String artist) {
    // 发送导航到专辑的通知
    AlbumSelectedNotification(album, artist).dispatch(context);
  }
  
  // 格式化时长
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    
    return '$minutes:$seconds';
  }
  
  // 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
} 