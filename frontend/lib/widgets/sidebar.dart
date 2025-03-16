import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/playlist.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/enums/content_type.dart';

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
  // 是否展开歌单列表
  bool _isPlaylistExpanded = false;
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
            icon: Icons.person,
            title: '歌手',
            contentType: ContentType.artists,
          ),
          _buildMenuItem(
            context,
            icon: Icons.album,
            title: '专辑',
            contentType: ContentType.albums,
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
    
    return HoverWidget(
      builder: (context, isHovered) {
        final Color bgColor = isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : isHovered 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : Colors.transparent;
                
        final Color iconColor = isSelected || isHovered
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
        
        final Color textColor = isSelected || isHovered
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface;
        
        return GestureDetector(
          onTap: () {
            // 如果点击的是歌单按钮，切换歌单列表的展开状态
            if (contentType == ContentType.playlists) {
              setState(() {
                _isPlaylistExpanded = !_isPlaylistExpanded;
              });
            }
            widget.onContentTypeSelected(contentType);
          },
          child: Container(
            height: 44,
            margin: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 4 : 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: bgColor,
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
                    color: iconColor,
                    size: 20,
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    if (showExpand && contentType == ContentType.playlists)
                      Icon(
                        _isPlaylistExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: iconColor,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    // 使用固定颜色，不随悬停状态改变
    final Color iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggleCollapsed,
        child: Container(
          height: 40,
          width: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            // 使用透明背景，不随悬停状态改变
            color: Colors.transparent,
          ),
          child: Icon(
            _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(BuildContext context) {
    // 如果歌单列表未展开，则不显示
    if (!_isPlaylistExpanded) {
      return const SizedBox.shrink();
    }
    
    return Consumer<PlaylistService>(
      builder: (context, playlistService, child) {
        List<Playlist> playlists = playlistService.playlists;
        
        if (playlists.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          children: playlists.map((playlist) {
            final isSelected = widget.selectedContentType == ContentType.playlist && 
                              widget.selectedPlaylistId == playlist.id;
            
            return HoverWidget(
              builder: (context, isHovered) {
                final Color bgColor = isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                    : isHovered 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                        : Colors.transparent;
                        
                final Color iconColor = isSelected || isHovered
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
                
                final Color textColor = isSelected || isHovered
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface;
                    
                final FontWeight fontWeight = isSelected || isHovered
                    ? FontWeight.bold 
                    : FontWeight.normal;
                
                return GestureDetector(
                  onTap: () {
                    widget.onPlaylistSelected(playlist.id);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCollapsed ? 8 : 16,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(left: 16),
                    width: _isCollapsed ? 40 : 170,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgColor,
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
                            color: iconColor,
                          ),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              playlist.name,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: fontWeight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

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