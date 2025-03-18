import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/utils/page_transitions.dart';
import '../enums/playback_state.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:slahser_player/services/settings_service.dart';
import 'package:palette_generator/palette_generator.dart';

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

class LyricsPage extends StatefulWidget {
  // 可以接受一个初始音乐文件，但页面会自动跟踪当前播放的音乐
  final MusicFile? initialMusic;

  const LyricsPage({super.key, this.initialMusic});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> with AutomaticKeepAliveClientMixin {
  bool _showLyricsControls = false;
  Timer? _hideControlsTimer;
  double _fontSize = 16.0;
  String? _fontFamily;
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  int _currentLineIndex = 0;
  Duration _lastPosition = Duration.zero;
  Timer? _positionUpdateTimer;
  late SettingsService _settingsService;
  // 当前显示的音乐
  MusicFile? _currentDisplayedMusic;
  
  // 添加背景渐变色变量
  Color _primaryColor = Colors.blue.withOpacity(0.6);
  Color _secondaryColor = Colors.purple.withOpacity(0.6);
  bool _isLoadingColors = false;
  
  // 添加颜色缓存以减少重复提取
  final Map<String, List<Color>> _colorCache = {};
  
  @override
  bool get wantKeepAlive => true; // 保持页面状态，避免重建
  
  @override
  void initState() {
    super.initState();
    
    // 获取设置服务
    _settingsService = Provider.of<SettingsService>(context, listen: false);
    
    // 初始化字体设置
    _updateFontSettings();
    
    // 获取当前播放的音乐或使用初始传入的音乐
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    _currentDisplayedMusic = widget.initialMusic ?? audioPlayer.currentMusic;
    
    if (_currentDisplayedMusic != null) {
      _loadLyrics(_currentDisplayedMusic!);
      _extractColorsFromCover(_currentDisplayedMusic!);
    }
    
    // 启动定时器，定期更新当前行和检查歌曲变化
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      
      final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
      final position = audioPlayer.position;
      final currentMusic = audioPlayer.currentMusic;
      
      // 更严格地检查当前歌曲是否发生变化，并确保立即更新
      if (currentMusic != null) {
        if (_currentDisplayedMusic == null || 
            currentMusic.id != _currentDisplayedMusic!.id) {
          if (mounted) {
            setState(() {
              _currentDisplayedMusic = currentMusic;
              _lyrics = []; // 清空歌词以显示加载状态
              _currentLineIndex = 0;
            });
            _loadLyrics(currentMusic);
            _extractColorsFromCover(currentMusic);
            debugPrint('检测到歌曲切换，正在加载新的歌词: ${currentMusic.title}');
          }
        } else if (position != _lastPosition) {
          _lastPosition = position;
          _updateCurrentLine(position);
        }
      }
    });
    
    // 订阅音频播放器的播放状态变化，确保在歌曲切换时更新歌词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
        audioPlayer.currentMusicStream.listen((newMusic) {
          if (newMusic != null && (_currentDisplayedMusic == null || newMusic.id != _currentDisplayedMusic!.id)) {
            if (mounted) {
              setState(() {
                _currentDisplayedMusic = newMusic;
                _lyrics = []; // 清空歌词以显示加载状态
                _currentLineIndex = 0;
              });
              _loadLyrics(newMusic);
              _extractColorsFromCover(newMusic);
              debugPrint('通过流监听检测到歌曲切换，正在加载新的歌词: ${newMusic.title}');
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics(MusicFile music) async {
    // 确保我们总是尝试加载新歌曲的歌词
    if (_currentDisplayedMusic?.id != music.id) {
      setState(() {
        _lyrics = [];
        _currentLineIndex = 0;
      });
    } else if (_lyrics.isNotEmpty && _lyrics.first.text != '暂无歌词' && _lyrics.first.text != '读取歌词失败') {
      // 如果已经加载了当前歌曲的正确歌词，则不需要重新加载
      return;
    }
    
    debugPrint('开始加载歌词: ${music.title}, ID: ${music.id}');
    
    try {
      // 首先尝试加载外部歌词文件
      if (music.lyricsPath != null) {
        final file = File(music.lyricsPath!);
        if (await file.exists()) {
          final content = await file.readAsString();
          final lines = content.split('\n');
          final parsedLyrics = <LyricLine>[];

          for (final line in lines) {
            final lyricLine = _parseLyricLine(line);
            if (lyricLine != null) {
              parsedLyrics.add(lyricLine);
            }
          }

          if (parsedLyrics.isNotEmpty) {
            // 按时间排序
            parsedLyrics.sort((a, b) => a.time.compareTo(b.time));

            if (mounted) {
              setState(() {
                _lyrics = parsedLyrics;
                _currentLineIndex = 0;
              });
            }
            debugPrint('成功从外部歌词文件加载歌词: ${music.title}');
            return;
          }
        }
      }

      // 尝试使用内嵌歌词
      if (music.hasEmbeddedLyrics && music.embeddedLyrics != null) {
        final lines = music.embeddedLyrics!;
        final parsedLyrics = <LyricLine>[];

        for (final line in lines) {
          final lyricLine = _parseLyricLine(line);
          if (lyricLine != null) {
            parsedLyrics.add(lyricLine);
          }
        }

        if (parsedLyrics.isNotEmpty) {
          // 按时间排序
          parsedLyrics.sort((a, b) => a.time.compareTo(b.time));

          if (mounted) {
            setState(() {
              _lyrics = parsedLyrics;
              _currentLineIndex = 0;
            });
          }
          debugPrint('成功从内嵌歌词加载歌词: ${music.title}');
          return;
        }
      }

      // 如果没有找到时间标签的歌词，尝试使用纯文本歌词
      List<String>? rawLyrics = await music.getLyrics();
      if (rawLyrics != null && rawLyrics.isNotEmpty) {
        final parsedLyrics = <LyricLine>[];
        int index = 0;
        
        // 过滤空行
        final filteredLines = rawLyrics.where((line) => line.trim().isNotEmpty).toList();
        
        // 如果是纯文本格式，为每行分配平均时间
        double totalDuration = music.duration.inMilliseconds.toDouble();
        double timePerLine = totalDuration / filteredLines.length;
        
        for (final line in filteredLines) {
          // 检查行是否已有时间标签
          if (!line.startsWith('[')) {
            double timeMs = index * timePerLine;
            Duration time = Duration(milliseconds: timeMs.round());
            parsedLyrics.add(LyricLine(time: time, text: line.trim()));
            index++;
          }
        }
        
        if (parsedLyrics.isNotEmpty) {
          if (mounted) {
            setState(() {
              _lyrics = parsedLyrics;
              _currentLineIndex = 0;
            });
          }
          debugPrint('成功加载纯文本格式歌词: ${music.title}');
          return;
        }
      }

      // 所有方法都失败，显示无歌词信息
      if (mounted) {
        setState(() {
          _lyrics = [LyricLine(time: Duration.zero, text: '暂无歌词')];
          _currentLineIndex = 0;
        });
      }
      debugPrint('未找到歌词: ${music.title}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _lyrics = [LyricLine(time: Duration.zero, text: '读取歌词失败: $e')];
          _currentLineIndex = 0;
        });
      }
      debugPrint('读取歌词失败: ${music.title}, 错误: $e');
    }
  }

  LyricLine? _parseLyricLine(String line) {
    // LRC格式: [mm:ss.xx]歌词内容
    final RegExp timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\]');
    final match = timeTagRegex.firstMatch(line);
    
    if (match == null) return null;
    
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final milliseconds = int.parse(match.group(3)!) * 10; // 转换为毫秒
    
    final time = Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
    
    // 提取歌词内容
    final text = line.substring(match.end).trim();
    if (text.isEmpty) return null;
    
    return LyricLine(time: time, text: text);
  }

  void _updateCurrentLine(Duration position) {
    if (_lyrics.isEmpty) return;
    
    int index = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      if (i == _lyrics.length - 1 || position < _lyrics[i + 1].time) {
        index = i;
        break;
      }
    }
    
    if (index != _currentLineIndex) {
      setState(() {
        _currentLineIndex = index;
      });
      
      // 滚动到当前行
      if (_scrollController.hasClients) {
        final itemHeight = 40.0 + (_fontSize - 16.0); // 估计每行高度
        final offset = itemHeight * _currentLineIndex;
        _scrollController.animateTo(
          offset - 100, // 居中显示
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showLyricsControlsTemporarily() {
    setState(() {
      _showLyricsControls = true;
    });
    
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLyricsControls = false;
        });
      }
    });
  }

  void _seekToLyricLine(int index) {
    if (index < 0 || index >= _lyrics.length) return;
    
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayer.seekTo(_lyrics[index].time);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 需要调用父类的build方法
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: true); // 修改为 listen: true 确保能接收到更新
    
    return StreamBuilder<PlaybackState>(
      stream: audioPlayer.playbackState,
      initialData: PlaybackState.stopped,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlaybackState.playing;
        final currentMusic = audioPlayer.currentMusic;
        
        // 检查是否需要更新当前显示的音乐
        if (currentMusic != null && (_currentDisplayedMusic == null || currentMusic.id != _currentDisplayedMusic!.id)) {
          // 在构建过程中检测到歌曲变化，安排一个微任务在构建后更新状态
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentDisplayedMusic = currentMusic;
              });
              _loadLyrics(currentMusic);
              _extractColorsFromCover(currentMusic);
              debugPrint('在构建过程中检测到歌曲变化，加载新歌词: ${currentMusic.title}');
            }
          });
        }
        
        // 使用当前应该显示的音乐
        final displayMusic = _currentDisplayedMusic ?? currentMusic;
        
        // 如果没有正在播放的音乐，显示占位符
        if (displayMusic == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: Center(
              child: Text(
                '无正在播放的音乐',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          );
        }
        
        return Scaffold(
          // 使用专辑封面提取的颜色作为渐变背景色
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryColor,
                  _secondaryColor,
                ],
              ),
            ),
            child: Consumer<AudioPlayerService>(
              builder: (context, audioPlayer, child) {
                final position = audioPlayer.position;
                final duration = audioPlayer.duration;
                
                // 再次检查当前音乐是否变化
                final currentMusic = audioPlayer.currentMusic;
                if (currentMusic != null && (_currentDisplayedMusic == null || currentMusic.id != _currentDisplayedMusic!.id)) {
                  // 在Consumer中检测到歌曲变化，安排一个微任务在构建后更新状态
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _currentDisplayedMusic = currentMusic;
                      });
                      _loadLyrics(currentMusic);
                      _extractColorsFromCover(currentMusic);
                      debugPrint('在Consumer中检测到歌曲变化，加载新歌词: ${currentMusic.title}');
                    }
                  });
                }
                
                return Stack(
                  children: [
                    // 主内容
                    Row(
                      children: [
                        // 左侧：歌曲信息 - 减少动画效果
                        SizedBox(
                          width: 400,
                          child: _buildMusicInfo(
                            context, 
                            displayMusic, 
                            audioPlayer, 
                            position, 
                            duration,
                            key: ValueKey('info-${displayMusic.id}'),
                          ),
                        ),
                        // 右侧：歌词
                        Expanded(
                          child: MouseRegion(
                            onEnter: (_) => _showLyricsControlsTemporarily(),
                            onHover: (_) => _showLyricsControlsTemporarily(),
                            child: _buildLyrics(
                              context, 
                              audioPlayer,
                              key: ValueKey('lyrics-${displayMusic.id}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // 顶部返回按钮 - 始终显示，去掉背景
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Material(
                            color: Colors.transparent,
                            child: Tooltip(
                              message: '返回',
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: const Icon(
                                  Icons.arrow_back,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMusicInfo(
    BuildContext context, 
    MusicFile music, 
    AudioPlayerService audioPlayer, 
    Duration position, 
    Duration duration,
    {Key? key}
  ) {
    final isPlaying = audioPlayer.playbackState == PlaybackState.playing;

    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity, // 填满整个高度
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height, // 确保内容至少和屏幕一样高
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 在空间中均匀分布元素
                children: [
                  // 上部留白
                  const SizedBox(height: 10),
                  
                  // 封面
                  Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _buildCoverImage(context, music),
                  ),
                  
                  // 歌曲信息
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          music.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          music.artist,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          music.album,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // 控制部分 (播放控制和进度条)
                  Column(
                    children: [
                      // 播放控制
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                            context,
                            icon: Icons.skip_previous,
                            size: 32,
                            tooltip: '上一曲',
                            onPressed: () {
                              audioPlayer.previous();
                            },
                          ),
                          const SizedBox(width: 16),
                          StreamBuilder<PlaybackState>(
                            stream: audioPlayer.playbackState,
                            initialData: PlaybackState.stopped,
                            builder: (context, snapshot) {
                              final isPlaying = snapshot.data == PlaybackState.playing;
                              return _buildControlButton(
                                context,
                                icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                size: 48,
                                tooltip: isPlaying ? '暂停' : '播放',
                                onPressed: () {
                                  audioPlayer.playOrPause();
                                },
                              );
                            }
                          ),
                          const SizedBox(width: 16),
                          _buildControlButton(
                            context,
                            icon: Icons.skip_next,
                            size: 32,
                            tooltip: '下一曲',
                            onPressed: () {
                              audioPlayer.next();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 进度条
                      SizedBox(
                        width: 320,
                        child: Row(
                          children: [
                            Text(
                              AudioPlayerService.formatDuration(position),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4.0,
                                    disabledThumbRadius: 4.0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 8.0,
                                  ),
                                  activeTrackColor: Colors.white.withOpacity(0.8),
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                                  thumbColor: Colors.white,
                                  overlayColor: Colors.white.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: math.min(position.inMilliseconds.toDouble(), 
                                          math.max(duration.inMilliseconds.toDouble(), 1.0)),
                                  max: math.max(duration.inMilliseconds.toDouble(), 1.0),
                                  onChanged: (value) {
                                    audioPlayer.seekTo(Duration(milliseconds: value.toInt()));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AudioPlayerService.formatDuration(duration),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // 底部留白
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, MusicFile music) {
    if (music.coverPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Hero(
          tag: 'cover-${music.id}',
          child: Image.file(
            File(music.coverPath!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 600,
            cacheHeight: 600,
            key: ValueKey(music.coverPath),
          ),
        ),
      );
    } else if (music.hasEmbeddedCover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Hero(
          tag: 'embedded-cover-${music.id}',
          child: Image.memory(
            Uint8List.fromList(music.getCoverBytes()!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 600,
            cacheHeight: 600,
            key: ValueKey(music.id),
          ),
        ),
      );
    } else {
      return Hero(
        tag: 'no-cover-${music.id}',
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              size: 160,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildLyrics(
    BuildContext context, 
    AudioPlayerService audioPlayer,
    {Key? key}
  ) {
    if (_lyrics.isEmpty) {
      return Center(
        key: key,
        child: const CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }
    
    return Stack(
      key: key,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          margin: const EdgeInsets.all(16),
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _lyrics.length,
            itemBuilder: (context, index) {
              final isCurrentLine = index == _currentLineIndex;
              
              return HoverWidget(
                builder: (context, isHovered) {
                  return GestureDetector(
                    onTap: () => _seekToLyricLine(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentLine 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _lyrics[index].text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCurrentLine ? _fontSize + 2 : _fontSize,
                          fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentLine 
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          letterSpacing: isCurrentLine ? 0.5 : 0,
                          fontFamily: _fontFamily,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // 添加右下角的字体大小调整按钮
        Positioned(
          right: 30,
          bottom: 30,
          child: AnimatedOpacity(
            opacity: _showLyricsControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: PopupMenuButton<double>(
              tooltip: '调整字体大小',
              icon: const Icon(
                Icons.text_fields,
                color: Colors.white,
                size: 24,
              ),
              offset: const Offset(0, -200),
              color: Colors.black.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: -2.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.text_decrease, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('减小字体', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.text_increase, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('增大字体', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                setState(() {
                  _fontSize = (_fontSize + value).clamp(12.0, 32.0);
                });
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required double size,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            splashColor: Colors.transparent,
            hoverColor: Colors.white.withOpacity(0.1),
            child: Icon(
              icon,
              size: size,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // 更新字体设置
  void _updateFontSettings() {
    final settings = _settingsService.settings;
    setState(() {
      _fontSize = 16.0; // 可以根据需要从设置中获取字体大小
      _fontFamily = settings.fontFamily == 'System Default' ? null : settings.fontFamily;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听设置变化
    final settingsService = Provider.of<SettingsService>(context);
    if (settingsService != _settingsService) {
      _settingsService = settingsService;
      _updateFontSettings();
    }
  }

  // 从封面提取颜色 - 优化性能
  Future<void> _extractColorsFromCover(MusicFile music) async {
    if (_isLoadingColors) return;
    
    // 检查缓存
    if (_colorCache.containsKey(music.id)) {
      setState(() {
        _primaryColor = _colorCache[music.id]![0];
        _secondaryColor = _colorCache[music.id]![1];
      });
      return;
    }
    
    setState(() {
      _isLoadingColors = true;
    });
    
    // 使用compute在后台线程执行颜色提取
    Future.microtask(() async {
      try {
        Color primaryColor;
        Color secondaryColor;
        
        if (music.coverPath != null) {
          // 从文件加载图片 - 缩小尺寸以提高性能
          final imageProvider = FileImage(File(music.coverPath!));
          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            imageProvider,
            size: const Size(100, 100), // 进一步缩小尺寸
            maximumColorCount: 10, // 限制颜色数量
          );
          
          // 获取主色调和次要色调
          primaryColor = (paletteGenerator.dominantColor?.color ?? 
                        paletteGenerator.vibrantColor?.color ?? 
                        Colors.blue).withOpacity(0.6);
          
          secondaryColor = (paletteGenerator.mutedColor?.color ?? 
                          paletteGenerator.darkVibrantColor?.color ?? 
                          Colors.purple).withOpacity(0.6);
          
        } else if (music.hasEmbeddedCover && music.getCoverBytes() != null) {
          // 从内存数据加载图片
          final imageProvider = MemoryImage(Uint8List.fromList(music.getCoverBytes()!));
          final paletteGenerator = await PaletteGenerator.fromImageProvider(
            imageProvider,
            size: const Size(100, 100),
            maximumColorCount: 10,
          );
          
          primaryColor = (paletteGenerator.dominantColor?.color ?? 
                        paletteGenerator.vibrantColor?.color ?? 
                        Colors.blue).withOpacity(0.6);
          
          secondaryColor = (paletteGenerator.mutedColor?.color ?? 
                          paletteGenerator.darkVibrantColor?.color ?? 
                          Colors.purple).withOpacity(0.6);
        } else {
          // 默认渐变色
          primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
          secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
        }
        
        // 缓存提取的颜色
        _colorCache[music.id] = [primaryColor, secondaryColor];
        
        // 设置渐变色
        if (mounted) {
          setState(() {
            _primaryColor = primaryColor;
            _secondaryColor = secondaryColor;
            _isLoadingColors = false;
          });
        }
      } catch (e) {
        debugPrint('提取封面颜色错误: $e');
        // 出错时使用默认颜色
        if (mounted) {
          setState(() {
            _primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
            _secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
            _isLoadingColors = false;
          });
        }
      }
    });
  }
}

class LyricLine {
  final Duration time;
  final String text;
  
  LyricLine({required this.time, required this.text});
} 