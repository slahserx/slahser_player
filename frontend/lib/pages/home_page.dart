import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/widgets/player_controls.dart';
import 'package:slahser_player/widgets/sidebar.dart';
import 'package:slahser_player/widgets/content_area.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/enums/content_type.dart';
import 'dart:io' show exit;

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
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: widget.builder(context, isHovered),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  // 存储当前选中的内容类型
  ContentType _selectedContentType = ContentType.allMusic;
  
  // 存储当前选中的歌单ID
  String? _selectedPlaylistId;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowManager();
    
    // 初始化服务
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final musicLibraryService = Provider.of<MusicLibraryService>(context, listen: false);
      
      // 加载音乐库
      await musicLibraryService.loadLibrary();
    });
  }
  
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
  
  // 初始化窗口管理器
  Future<void> _initWindowManager() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.center();
    await windowManager.show();
  }

  @override
  void onWindowClose() {
    // 使用exit(0)直接退出，不等待
    exit(0);
  }

  void _handleContentTypeSelected(ContentType contentType) {
    setState(() {
      _selectedContentType = contentType;
      // 如果切换到了非歌单详情页面，清空选中的歌单ID
      if (contentType != ContentType.playlist) {
        _selectedPlaylistId = null;
      }
    });
  }

  void _handlePlaylistSelected(String playlistId) {
    setState(() {
      _selectedContentType = ContentType.playlist;
      _selectedPlaylistId = playlistId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 主体区域
          Expanded(
            child: Row(
              children: [
                // 左侧导航栏
                Sidebar(
                  onContentTypeSelected: _handleContentTypeSelected,
                  onPlaylistSelected: _handlePlaylistSelected,
                  selectedContentType: _selectedContentType,
                  selectedPlaylistId: _selectedPlaylistId,
                ),
                // 右侧内容区域
                Expanded(
                  child: Column(
                    children: [
                      // 顶部栏 - 可拖动区域
                      GestureDetector(
                        onPanStart: (details) {
                          windowManager.startDragging();
                        },
                        child: Container(
                          height: 40,
                          color: Theme.of(context).colorScheme.surface,
                          child: Row(
                            children: [
                              // 窗口控制按钮
                              const Spacer(),
                              SizedBox(
                                width: 120,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildWindowButton(
                                      context,
                                      icon: Icons.minimize,
                                      onPressed: () async {
                                        await windowManager.minimize();
                                      },
                                    ),
                                    _buildWindowButton(
                                      context,
                                      icon: Icons.crop_square,
                                      onPressed: () async {
                                        if (await windowManager.isMaximized()) {
                                          await windowManager.restore();
                                        } else {
                                          await windowManager.maximize();
                                        }
                                      },
                                    ),
                                    _buildWindowButton(
                                      context,
                                      icon: Icons.close,
                                      onPressed: () async {
                                        exit(0);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 内容区域
                      Expanded(
                        child: NotificationListener<PlaylistSelectedNotification>(
                          onNotification: (notification) {
                            // 处理歌单选择通知
                            _handlePlaylistSelected(notification.playlistId);
                            return true; // 阻止通知继续冒泡
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: ContentArea(
                              key: ValueKey<ContentType>(_selectedContentType),
                              selectedContentType: _selectedContentType,
                              selectedPlaylistId: _selectedPlaylistId,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 播放控制栏
          const SizedBox(
            height: 90,
            child: PlayerControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: HoverWidget(
        builder: (context, isHovered) {
          final Color defaultColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.8);
          final Color hoverColor = icon == Icons.close 
              ? Colors.red 
              : Theme.of(context).colorScheme.primary;
          final Color bgHoverColor = icon == Icons.close 
              ? Colors.red.withOpacity(0.1) 
              : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3);
          
          return GestureDetector(
            onTap: () {
              // 直接调用destroy()而不是await close()，避免等待导致的卡顿
              if (icon == Icons.close) {
                exit(0);
              } else {
                onPressed();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isHovered ? bgHoverColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isHovered ? hoverColor : defaultColor,
              ),
            ),
          );
        },
      ),
    );
  }
} 