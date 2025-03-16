import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/enums/content_type.dart';

// 检查是否是需要隐藏的系统歌单
bool isSystemPlaylistHidden(Playlist playlist) {
  // 这里可以添加自定义的过滤逻辑
  // 例如，可以判断特定的歌单名称或ID
  // 当前只过滤掉默认歌单，因为它已经在固定菜单中
  return playlist.isDefault;
}

class Sidebar extends StatefulWidget {
  final Function(ContentType) onContentTypeSelected;
  final Function(String) onPlaylistSelected;
  final ContentType selectedContentType;
  final String? selectedPlaylistId;

  const Sidebar({
    super.key,
    required this.onContentTypeSelected,
    required this.onPlaylistSelected,
    required this.selectedContentType,
    this.selectedPlaylistId,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  // 是否折叠侧边栏
  bool _isCollapsed = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleCollapsed() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = _isCollapsed ? 60 : 220;
    
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 应用标题
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 24, 
              horizontal: _isCollapsed ? 8 : 16
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed 
                  ? MainAxisAlignment.center 
                  : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Slahser Player',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 核心导航项
          _buildMenuItem(
            context,
            icon: Icons.music_note,
            title: '所有音乐',
            contentType: ContentType.allMusic,
          ),
          _buildMenuItem(
            context,
            icon: Icons.favorite,
            title: '我喜欢的音乐',
            contentType: ContentType.favoriteMusic,
          ),
          _buildMenuItem(
            context,
            icon: Icons.playlist_play,
            title: '歌单',
            contentType: ContentType.playlists,
            showExpand: !_isCollapsed,
          ),
          
          // 歌单列表
          if (!_isCollapsed) _buildPlaylistsList(context),
          
          const Spacer(),
          
          // 底部菜单 - 设置和折叠按钮放在同一行
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    title: '设置',
                    contentType: ContentType.settings,
                  ),
                ),
                _buildCollapseButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required ContentType contentType,
    bool showExpand = false,
  }) {
    final isSelected = widget.selectedContentType == contentType ||
        (contentType == ContentType.playlists && 
         widget.selectedContentType == ContentType.playlist);
    
    return InkWell(
      onTap: () {
        widget.onContentTypeSelected(contentType);
      },
      hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        margin: EdgeInsets.symmetric(
          horizontal: _isCollapsed ? 4 : 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8 : 16),
          child: Row(
            mainAxisAlignment: _isCollapsed 
                ? MainAxisAlignment.center 
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 20,
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (showExpand && contentType == ContentType.playlists)
                  Icon(
                    (widget.selectedContentType == ContentType.playlists)
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    return InkWell(
      onTap: _toggleCollapsed,
      hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        width: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(BuildContext context) {
    return Consumer<PlaylistService>(
      builder: (context, playlistService, child) {
        List<Playlist> playlists = playlistService.playlists;
        
        // 如果不是在歌单列表页面或歌单详情页面，就不显示歌单
        if (widget.selectedContentType != ContentType.playlists && 
           widget.selectedContentType != ContentType.playlist) {
          return const SizedBox.shrink();
        }
        
        // 过滤掉需要隐藏的系统歌单
        List<Playlist> filteredPlaylists = playlists.where((playlist) {
          return !isSystemPlaylistHidden(playlist);
        }).toList();
        
        if (filteredPlaylists.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          children: filteredPlaylists.map((playlist) {
            final isSelected = widget.selectedContentType == ContentType.playlist && 
                              widget.selectedPlaylistId == playlist.id;
            
            return InkWell(
              onTap: () {
                widget.onPlaylistSelected(playlist.id);
              },
              hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isCollapsed ? 8 : 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.queue_music,
                        size: 16,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (!_isCollapsed) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playlist.name,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
} 