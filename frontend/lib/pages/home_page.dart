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

// 全局键，用于访问ContentArea的状态
final GlobalKey<ContentAreaState> contentAreaKey = GlobalKey<ContentAreaState>();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  ContentType _selectedContentType = ContentType.allMusic;
  String? _selectedPlaylistId;
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    
    // 初始化服务
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final musicLibraryService = Provider.of<MusicLibraryService>(context, listen: false);
      
      // 加载音乐库
      musicLibraryService.loadLibrary();
    });
  }
  
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
  
  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.destroy();
    }
  }

  void _handleContentTypeSelected(ContentType contentType) {
    setState(() {
      _selectedContentType = contentType;
      // 如果切换到了非歌单详情页面，清空选中的歌单ID
      if (contentType != ContentType.playlistDetail) {
        _selectedPlaylistId = null;
      }
    });
    contentAreaKey.currentState?.showContent(contentType);
  }

  void _handlePlaylistSelected(ContentType contentType, {String? playlistId}) {
    setState(() {
      _selectedContentType = contentType;
      _selectedPlaylistId = playlistId;
    });
    contentAreaKey.currentState?.showContent(contentType, playlistId: playlistId);
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
                                        await windowManager.close();
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
                        child: ContentArea(
                          key: contentAreaKey,
                          contentType: _selectedContentType,
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
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
} 