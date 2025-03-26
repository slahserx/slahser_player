import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/widgets/content/hover_widget.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/widgets/custom_snackbar.dart';
import 'dart:math' as math;
import 'dart:io';

/// 播放列表视图组件
class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final PlaylistService _playlistService;

  @override
  void initState() {
    super.initState();
    _playlistService = Provider.of<PlaylistService>(context, listen: false);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  // 显示创建新播放列表对话框
  void _showCreatePlaylistDialog(BuildContext context) {
    _nameController.clear();
    _descriptionController.clear();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建新歌单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '歌单名称',
                  hintText: '请输入歌单名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
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
              onPressed: () {
                final name = _nameController.text.trim();
                final description = _descriptionController.text.trim();
                
                if (name.isNotEmpty) {
                  // 创建新播放列表
                  _playlistService.createPlaylist(name, description: description);
                  
                  // 关闭对话框
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
  
  // 生成随机颜色
  Color _getRandomColor(int index) {
    final colors = [
      Colors.red[400],
      Colors.blue[400],
      Colors.green[400],
      Colors.orange[400],
      Colors.purple[400],
      Colors.teal[400],
      Colors.pink[400],
      Colors.indigo[400],
    ];
    
    return colors[index % colors.length] ?? Colors.grey[400]!;
  }
  
  @override
  Widget build(BuildContext context) {
    final playlists = _playlistService.playlists;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 页面顶部标题和按钮区域
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '播放列表',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('新建歌单'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 分割线
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
        // 歌单列表区域
        Expanded(
          child: playlists.isEmpty
              ? _buildEmptyState(context)
              : _buildPlaylistGrid(context, playlists),
        ),
      ],
    );
  }

  // 构建空状态视图
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有播放列表',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击"新建歌单"按钮创建一个播放列表',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  // 构建播放列表网格
  Widget _buildPlaylistGrid(BuildContext context, List<Playlist> playlists) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 根据容器宽度动态计算每行显示的卡片数量
          double width = constraints.maxWidth;
          int crossAxisCount = width ~/ 250; // 每个卡片理想宽度约为250
          crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;
          
          // 计算卡片宽度，确保至少180宽度
          double cardWidth = (width / crossAxisCount) - 16;
          cardWidth = cardWidth < 180 ? 180 : cardWidth;
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: cardWidth / 200, // 调整卡片宽高比
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final color = _getRandomColor(index);
              
              return _buildPlaylistCard(context, playlist, color);
            },
          );
        },
      ),
    );
  }
  
  // 构建播放列表卡片
  Widget _buildPlaylistCard(BuildContext context, Playlist playlist, Color color) {
    return HoverWidget(
      builder: (context, isHovered) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onSecondaryTapUp: (details) {
              final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  details.globalPosition,
                  details.globalPosition,
                ),
                Offset.zero & overlay.size,
              );
              _showPlaylistContextMenu(context, playlist, position);
            },
            child: Card(
              elevation: isHovered ? 4 : 1,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  PlaylistSelectedNotification(playlist.id).dispatch(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 播放列表封面
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 添加封面图片
                            if (playlist.getCoverImage(_playlistService.allMusicFiles) != null)
                              Image.file(
                                File(playlist.getCoverImage(_playlistService.allMusicFiles)!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: color.withOpacity(0.3),
                                  child: Icon(
                                    Icons.music_note,
                                    size: 48,
                                    color: color,
                                  ),
                                ),
                              )
                            else
                              Container(
                                color: color.withOpacity(0.3),
                                child: Icon(
                                  Icons.music_note,
                                  size: 48,
                                  color: color,
                                ),
                              ),
                            // 悬停时显示的播放按钮
                            if (isHovered)
                              Container(
                                color: Colors.black26,
                                child: Center(
                                  child: IconButton(
                                    onPressed: () {
                                      final songs = _playlistService.getPlaylistSongs(playlist.id);
                                      if (songs.isEmpty) return;
                                      
                                      final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                                      audioPlayer.setPlaylist(songs);
                                      audioPlayer.playMusic(songs.first);
                                    },
                                    icon: Icon(
                                      Icons.play_circle_fill,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                    tooltip: '播放全部',
                                  ),
                                ),
                              ),
                            // 歌曲数量徽章
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${playlist.songPaths.length}首',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 播放列表信息
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 播放列表名称
                            Text(
                              playlist.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 播放列表描述
                            Expanded(
                              child: playlist.description.isNotEmpty
                                  ? Text(
                                      playlist.description,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      '无描述',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 显示歌单右键菜单
  void _showPlaylistContextMenu(BuildContext context, Playlist playlist, RelativeRect position) {
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
              Text('播放全部'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'shuffle',
          child: Row(
            children: const [
              Icon(Icons.shuffle),
              SizedBox(width: 8),
              Text('随机播放'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: const [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('编辑歌单'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete),
              SizedBox(width: 8),
              Text('删除歌单'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      
      switch (value) {
        case 'play':
          final songs = _playlistService.getPlaylistSongs(playlist.id);
          if (songs.isEmpty) return;
          final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
          audioPlayer.setPlaylist(songs);
          audioPlayer.playMusic(songs.first);
          break;
        
        case 'shuffle':
          final songs = _playlistService.getPlaylistSongs(playlist.id);
          if (songs.isEmpty) return;
          final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
          audioPlayer.setPlaylist(songs, shuffle: true);
          audioPlayer.playMusic(songs.first);
          break;
        
        case 'edit':
          _showEditPlaylistDialog(playlist);
          break;
        
        case 'delete':
          _showDeletePlaylistDialog(playlist);
          break;
      }
    });
  }

  // 显示编辑歌单对话框
  void _showEditPlaylistDialog(Playlist playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descriptionController = TextEditingController(text: playlist.description);
    
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                
                if (name.isEmpty) {
                  CustomSnackBar.showWarning(context, '歌单名称不能为空');
                  return;
                }
                
                // 检查是否有变化
                final nameChanged = name != playlist.name;
                final descriptionChanged = description != playlist.description;
                
                if (nameChanged || descriptionChanged) {
                  // 使用updatePlaylist方法更新歌单信息
                  _playlistService.updatePlaylist(
                    playlist.id, 
                    newName: nameChanged ? name : null,
                    newDescription: descriptionChanged ? description : null
                  );
                  
                  Navigator.of(context).pop();
                  setState(() {});
                } else {
                  Navigator.of(context).pop();
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
  void _showDeletePlaylistDialog(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确定要删除歌单"${playlist.name}"吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _playlistService.deletePlaylist(playlist.id);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }
} 