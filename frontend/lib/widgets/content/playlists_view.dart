import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/widgets/content/hover_widget.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'dart:math' as math;

/// 播放列表视图组件
class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
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
                  final playlistService = Provider.of<PlaylistService>(context, listen: false);
                  playlistService.createPlaylist(name, description: description);
                  
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
    final playlistService = Provider.of<PlaylistService>(context);
    final playlists = playlistService.playlists;
    
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
        return Card(
          elevation: isHovered ? 4 : 1,
          clipBehavior: Clip.antiAlias, // 防止内容溢出
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              // 发送通知，切换到播放列表详情视图
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
                      alignment: Alignment.center,
                      children: [
                        // 播放列表图标或播放按钮
                        isHovered 
                          ? IconButton(
                              onPressed: () {
                                // 播放整个列表
                                PlaylistSelectedNotification(playlist.id).dispatch(context);
                              },
                              icon: Icon(
                                Icons.play_circle_fill,
                                size: 48,
                                color: color,
                              ),
                            )
                          : Icon(
                              Icons.queue_music,
                              size: 48,
                              color: color,
                            ),
                        // 歌曲数量徽章
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${playlist.songPaths.length}首',
                              style: TextStyle(
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
        );
      },
    );
  }
} 