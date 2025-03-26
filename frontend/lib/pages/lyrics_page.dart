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
import 'package:slahser_player/services/online_lyrics_service.dart';

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
  double _fontSize = 18.0;
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
  
  // 添加封面图片缓存
  final Map<String, Uint8List> _coverImageCache = {};
  
  // 添加封面图片组件缓存，避免重复构建带来的闪烁
  final Map<String?, Widget> _coverWidgetCache = {};
  
  // 添加歌词来源状态
  bool _isUsingOnlineLyrics = false;
  bool _isLoadingOnlineLyrics = false;
  String? _onlineLyrics;
  bool _isWhiteColor = true;
  
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
      // 延迟颜色加载到didChangeDependencies中
    }
    
    // 引入防抖动变量
    bool isUpdating = false;
    
    // 启动定时器，定期更新当前行和检查歌曲变化，添加防抖动机制
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || isUpdating) return;
      
      isUpdating = true;
      
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
            _usePreloadedColorsOrExtract(currentMusic);
            debugPrint('检测到歌曲切换，正在加载新的歌词: ${currentMusic.title}');
          }
        } else if (position != _lastPosition) {
          _lastPosition = position;
          _updateCurrentLine(position);
        }
      }
      
      isUpdating = false;
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
              _usePreloadedColorsOrExtract(newMusic);
              debugPrint('通过流监听检测到歌曲切换，正在加载新的歌词: ${newMusic.title}');
            }
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 初始化页面颜色为主题色
    _primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
    _secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
    
    // 如果有当前显示的音乐，加载颜色
    if (_currentDisplayedMusic != null) {
      _usePreloadedColorsOrExtract(_currentDisplayedMusic!);
    }
    
    // 监听设置变化
    final settingsService = Provider.of<SettingsService>(context);
    if (settingsService != _settingsService) {
      _settingsService = settingsService;
      _updateFontSettings();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _scrollController.dispose();
    _coverImageCache.clear();
    _colorCache.clear();
    _coverWidgetCache.clear();
    super.dispose();
  }

  Future<void> _loadLyrics(MusicFile music) async {
    // 确保我们总是尝试加载新歌曲的歌词
    if (_currentDisplayedMusic?.id != music.id) {
      setState(() {
        _lyrics = [];
        _currentLineIndex = 0;
        _onlineLyrics = null;
        _isUsingOnlineLyrics = false;
      });
    } else if (_lyrics.isNotEmpty && _lyrics.first.text != '暂无歌词' && _lyrics.first.text != '读取歌词失败') {
      // 如果已经加载了当前歌曲的正确歌词，则不需要重新加载
      return;
    }
    
    debugPrint('开始加载歌词: ${music.title}, ID: ${music.id}');
    
    try {
      if (_isUsingOnlineLyrics) {
        await _loadOnlineLyrics(music);
        return;
      }

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

      // 所有本地方法都失败，尝试加载在线歌词
      await _loadOnlineLyrics(music);
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

  Future<void> _loadOnlineLyrics(MusicFile music) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingOnlineLyrics = true;
      _lyrics = [LyricLine(time: Duration.zero, text: '正在搜索在线歌词...')];
    });
    
    try {
      final lyrics = await OnlineLyricsService.searchAndGetLyrics(music.title, music.artist);
      
      if (lyrics != null) {
        final lines = lyrics.split('\n');
        final parsedLyrics = <LyricLine>[];
        final translationMap = <String, String>{};
        final processedTimes = <String>{};
        
        // 第一遍：收集所有翻译
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          final timeTagMatch = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
          if (timeTagMatch != null) {
            final minutes = timeTagMatch.group(1)!;
            final seconds = timeTagMatch.group(2)!;
            final millis = timeTagMatch.group(3)!;
            final timeTag = '$minutes:$seconds.$millis';
            final content = timeTagMatch.group(4)!.trim();
            
            // 检查下一行是否为翻译
            if (i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim();
              final nextTimeTagMatch = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(nextLine);
              if (nextTimeTagMatch != null) {
                final nextTimeTag = '${nextTimeTagMatch.group(1)}:${nextTimeTagMatch.group(2)}.${nextTimeTagMatch.group(3)}';
                
                if (timeTag == nextTimeTag) {
                  final translation = nextTimeTagMatch.group(4)!.trim();
                  if (translation.isNotEmpty && translation != content) {
                    translationMap[timeTag] = translation;
                    i++; // 跳过下一行，因为它是翻译
                  }
                }
              }
            }
          }
        }
        
        // 第二遍：解析原文并添加翻译，同时避免重复处理相同时间标签的行
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          final timeTagMatch = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$').firstMatch(line);
          if (timeTagMatch != null) {
            final minutes = int.parse(timeTagMatch.group(1)!);
            final seconds = int.parse(timeTagMatch.group(2)!);
            final millisStr = timeTagMatch.group(3)!;
            final milliseconds = int.parse(millisStr.padRight(3, '0').substring(0, 3));
            final timeTag = '${timeTagMatch.group(1)}:${timeTagMatch.group(2)}.${timeTagMatch.group(3)}';
            
            // 如果这个时间标签已经处理过，跳过
            if (processedTimes.contains(timeTag)) continue;
            processedTimes.add(timeTag);
            
            final content = timeTagMatch.group(4)!.trim();
            if (content.isNotEmpty) {
              final translation = translationMap[timeTag];
              final lyricLine = LyricLine(
                time: Duration(
                  minutes: minutes,
                  seconds: seconds,
                  milliseconds: milliseconds,
                ),
                text: content,
                translation: translation,
              );
              
              parsedLyrics.add(lyricLine);
            }
          }
        }
        
        if (parsedLyrics.isNotEmpty) {
          parsedLyrics.sort((a, b) => a.time.compareTo(b.time));
          
          if (mounted) {
            setState(() {
              _lyrics = parsedLyrics;
              _currentLineIndex = 0;
              _onlineLyrics = lyrics;
              _isUsingOnlineLyrics = true;
              _isLoadingOnlineLyrics = false;
            });
          }
          return;
        }
      }
      
      if (mounted) {
        setState(() {
          _lyrics = [LyricLine(time: Duration.zero, text: '未找到在线歌词')];
          _isLoadingOnlineLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lyrics = [LyricLine(time: Duration.zero, text: '加载在线歌词失败: $e')];
          _isLoadingOnlineLyrics = false;
        });
      }
      debugPrint('加载在线歌词失败: ${music.title}, 错误: $e');
    }
  }

  void _toggleLyricsSource() async {
    if (_currentDisplayedMusic == null) return;
    
    setState(() {
      _isUsingOnlineLyrics = !_isUsingOnlineLyrics;
      _lyrics = []; // 清空当前歌词
    });
    
    await _loadLyrics(_currentDisplayedMusic!);
  }

  LyricLine? _parseLyricLine(String line) {
    if (line.trim().isEmpty) return null;

    // 匹配时间标签 [mm:ss.xx] 或 [mm:ss.xxx]
    final RegExp timeTagRegex = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');
    final match = timeTagRegex.firstMatch(line);
    
    if (match == null) return null;
    
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final millisStr = match.group(3)!;
    final milliseconds = int.parse(millisStr.padRight(3, '0').substring(0, 3));
    
    final time = Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
    
    final content = match.group(4)!.trim();
    if (content.isEmpty) return null;

    // 检查是否包含翻译（使用多种分隔符）
    String text = content;
    String? translation;
    
    // 如果内容中包含分隔符，说明这是一个带翻译的行
    if (content.contains('//') || content.contains('【') || content.contains('|')) {
      // 优先处理 // 分隔符
      if (content.contains('//')) {
        final parts = content.split('//');
        if (parts.length >= 2) {
          text = parts[0].trim();
          translation = parts[1].trim();
        }
      }
      // 其次处理 【】 分隔符
      else if (content.contains('【')) {
        final parts = content.split('【');
        if (parts.length >= 2) {
          text = parts[0].trim();
          translation = parts[1].replaceAll('】', '').trim();
        }
      }
      // 最后处理 | 分隔符
      else if (content.contains('|')) {
        final parts = content.split('|');
        if (parts.length >= 2) {
          text = parts[0].trim();
          translation = parts[1].trim();
        }
      }
    }
    
    // 如果翻译为空或与原文相同，则不设置翻译
    if (translation != null && (translation.isEmpty || translation == text)) {
      translation = null;
    }
    
    return LyricLine(
      time: time,
      text: text,
      translation: translation,
    );
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
    
    // 只有当歌词行发生变化时才更新状态，减少不必要的重绘
    if (index != _currentLineIndex) {
      setState(() {
        _currentLineIndex = index;
      });
      
      // 滚动到当前行
      _scrollToCurrentLine(animate: true);
    }
  }

  void _scrollToCurrentLine({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    try {
      // 获取ListView的渲染对象
      final RenderBox? renderBox = _scrollController.position.context.storageContext.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      // 获取ListView的可视区域高度
      final viewportHeight = renderBox.size.height;
      
      // 计算每行的基础高度
      final baseItemHeight = 60.0;
      
      // 计算当前行之前所有行的总高度（包括padding）
      final verticalPadding = (viewportHeight - baseItemHeight) / 2;
      double totalOffset = verticalPadding;
      
      for (int i = 0; i < _currentLineIndex; i++) {
        double lineHeight = baseItemHeight;
        // 如果有翻译，增加额外高度
        if (_lyrics[i].translation != null && _lyrics[i].translation!.isNotEmpty) {
          lineHeight += 20.0;
        }
        totalOffset += lineHeight;
      }

      // 执行滚动
      if (animate) {
        _scrollController.animateTo(
          totalOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(totalOffset);
      }
    } catch (e) {
      debugPrint('滚动到当前行时出错: $e');
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
    // 设置当前行索引
    setState(() {
      _currentLineIndex = index;
    });
    // 跳转到对应时间
    audioPlayer.seekTo(_lyrics[index].time);
    // 确保歌词滚动到中间
    _scrollToCurrentLine(animate: true);
  }

  // 使用预先加载的颜色或异步提取
  void _usePreloadedColorsOrExtract(MusicFile music) {
    if (music.id == null || _isLoadingColors) return;
    
    // 无封面情况，直接使用主题色
    if (!music.hasEmbeddedCover && music.coverPath == null) {
      setState(() {
        _primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
        _secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
      });
      debugPrint('无封面，使用主题颜色: ${music.title}');
      return;
    }
    
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    final cachedColors = audioPlayer.getCachedColors(music.id);
    
    if (cachedColors != null) {
      // 使用已缓存的颜色
      setState(() {
        _primaryColor = cachedColors[0];
        _secondaryColor = cachedColors[1];
      });
      debugPrint('使用预先缓存的颜色: ${music.title}');
      return;
    } else if (_colorCache.containsKey(music.id)) {
      // 使用本地缓存的颜色
      setState(() {
        _primaryColor = _colorCache[music.id]![0];
        _secondaryColor = _colorCache[music.id]![1];
      });
      debugPrint('使用本地缓存的颜色: ${music.title}');
      return;
    }
    
    // 有封面，异步提取颜色
    _extractColorsFromCover(music);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 需要调用父类的build方法
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false); // 修改为 listen: false 减少不必要的重建
    
    return StreamBuilder<PlaybackState>(
      stream: audioPlayer.playbackState,
      initialData: PlaybackState.stopped,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlaybackState.playing;
        final currentMusic = audioPlayer.currentMusic;
        
        // 使用当前应该显示的音乐，避免闪烁
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
        
        // 检查是否需要更新当前显示的音乐 - 使用postFrameCallback确保不在构建过程中更新状态
        if (currentMusic != null && (_currentDisplayedMusic == null || currentMusic.id != _currentDisplayedMusic!.id)) {
          // 安排一个微任务在构建后更新状态
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleMusicChange(currentMusic);
          });
        }
        
        return Scaffold(
          // 使用专辑封面提取的颜色作为渐变背景色，注意使用ValueKey确保背景不会频繁重建
          body: KeyedSubtree(
            key: ValueKey('background-${displayMusic.id}'),
            child: Container(
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
                  
                  // 在这里不监听音乐变化，通过StreamBuilder已经处理了
                  
                  return Stack(
                    children: [
                      // 主内容 - 使用固定key防止重建，并使用非动画区域展示内容
                      Row(
                        key: displayMusic != null ? ValueKey('row-${displayMusic.id}') : null,
                        children: [
                          // 左侧：歌曲信息
                          SizedBox(
                            width: 400,
                            // 封装音乐信息部分，避免因进度条更新导致封面图片重建
                            child: RepaintBoundary(
                              child: _buildMusicInfo(
                                context, 
                                displayMusic, 
                                audioPlayer, 
                                position, 
                                duration,
                                key: displayMusic != null ? ValueKey('info-${displayMusic.id}') : null,
                              ),
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
                                key: displayMusic != null ? ValueKey('lyrics-${displayMusic.id}') : null,
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
                      
                      // 添加加载指示器
                      if (_isLoadingOnlineLyrics)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  );
                },
              ),
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
    final textColor = _isWhiteColor ? Colors.white : Colors.black;

    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 10),
                  
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
                    child: _buildCover(music),
                  ),
                  
                  Container(
                    height: 120,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            music.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          music.artist,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: textColor.withOpacity(0.9),
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          music.album,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: textColor.withOpacity(0.7),
                              ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    height: 120,
                    padding: EdgeInsets.zero,
                    key: ValueKey('controls-${music.id}'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                              color: textColor,
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
                                  color: textColor,
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
                              color: textColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 320,
                          child: Row(
                            children: [
                              Text(
                                AudioPlayerService.formatDuration(position),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textColor.withOpacity(0.7),
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
                                    activeTrackColor: textColor.withOpacity(0.8),
                                    inactiveTrackColor: textColor.withOpacity(0.3),
                                    thumbColor: textColor,
                                    overlayColor: textColor.withOpacity(0.2),
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
                                      color: textColor.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(MusicFile music) {
    // 使用缓存的封面组件如果存在的话
    if (_coverWidgetCache.containsKey(music.id)) {
      return _coverWidgetCache[music.id]!;
    }
    
    // 否则构建新的封面组件
    Widget coverWidget;
    
    if (music.coverPath != null) {
      // 使用文件路径加载图片
      coverWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Hero(
          tag: 'file-cover-${music.id}',
          child: Image.file(
            File(music.coverPath!),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
    } else if (music.hasEmbeddedCover && music.id != null) {
      // 使用缓存中的图片数据或异步加载
      if (_coverImageCache.containsKey(music.id!)) {
        final cachedBytes = _coverImageCache[music.id!];
        coverWidget = _buildCoverWidgetFromBytes(music, cachedBytes);
      } else {
        // 使用FutureBuilder加载图片数据
        coverWidget = FutureBuilder<List<int>?>(
          future: music.getCoverBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingWidget();
            }
            
            if (snapshot.hasData && snapshot.data != null) {
              final coverBytes = Uint8List.fromList(snapshot.data!);
              // 缓存图片数据
              _coverImageCache[music.id!] = coverBytes;
              return _buildCoverWidgetFromBytes(music, coverBytes);
            } else {
              return _buildNoCoverImage(music, context);
            }
          }
        );
      }
    } else {
      coverWidget = _buildNoCoverImage(music, context);
    }
    
    _coverWidgetCache[music.id] = coverWidget;
    return coverWidget;
  }

  Widget _buildCoverWidgetFromBytes(MusicFile music, List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return _buildNoCoverImage(music, context);
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Hero(
        tag: 'embedded-cover-${music.id}',
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 600,
          cacheHeight: 600,
          key: ValueKey('cover-memory-${music.id}'),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white.withOpacity(0.6),
                  strokeWidth: 2.0,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // 添加错误处理
            return _buildNoCoverImage(music, context);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white.withOpacity(0.6),
          strokeWidth: 2.0,
        ),
      ),
    );
  }

  Widget _buildLyricLine(LyricLine lyric, bool isCurrentLine, bool isHovered) {
    final textColor = _isWhiteColor ? Colors.white : Colors.black;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isHovered ? (_isWhiteColor ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 原文歌词
          Text(
            lyric.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrentLine ? _fontSize + 2 : _fontSize,
              fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
              color: isCurrentLine 
                  ? textColor
                  : textColor.withOpacity(0.4), // 降低未播放歌词的透明度
              letterSpacing: isCurrentLine ? 0.5 : 0,
              fontFamily: _fontFamily,
            ),
          ),
          // 翻译歌词
          if (lyric.translation != null && lyric.translation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                lyric.translation!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCurrentLine ? _fontSize - 2 : _fontSize - 4,
                  color: isCurrentLine 
                      ? textColor.withOpacity(0.8)
                      : textColor.withOpacity(0.3), // 降低未播放翻译的透明度
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLyrics(BuildContext context, AudioPlayerService audioPlayer, {Key? key}) {
    if (_lyrics.isEmpty) {
      return Center(
        key: key,
        child: CircularProgressIndicator(
          color: _isWhiteColor ? Colors.white : Colors.black,
        ),
      );
    }

    // 计算固定位置
    final screenHeight = MediaQuery.of(context).size.height;
    final itemHeight = 60.0; // 基础行高
    final visibleItemCount = (screenHeight * 0.7) ~/ itemHeight;
    final centerIndex = visibleItemCount ~/ 2;

    return Stack(
      key: key,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          margin: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lyrics.length,
                padding: EdgeInsets.symmetric(
                  vertical: (screenHeight * 0.7 - itemHeight) / 2,
                ),
                itemBuilder: (context, index) {
                  final isCurrentLine = index == _currentLineIndex;
                  final lyric = _lyrics[index];
                  
                  return HoverWidget(
                    builder: (context, isHovered) {
                      return GestureDetector(
                        onTap: () => _seekToLyricLine(index),
                        child: _buildLyricLine(lyric, isCurrentLine, isHovered),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        
        // 修改控制按钮布局
        Positioned(
          right: 30,
          bottom: 30,
          child: AnimatedOpacity(
            opacity: _showLyricsControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 歌词来源切换按钮
                IconButton(
                  icon: Icon(
                    _isUsingOnlineLyrics ? Icons.cloud : Icons.storage,
                    color: _isWhiteColor ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  tooltip: _isUsingOnlineLyrics ? '切换到本地歌词' : '切换到在线歌词',
                  onPressed: _toggleLyricsSource,
                ),
                const SizedBox(width: 16),
                // 颜色切换按钮
                IconButton(
                  icon: Icon(
                    _isWhiteColor ? Icons.brightness_7 : Icons.brightness_2,
                    color: _isWhiteColor ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  tooltip: '切换歌词颜色',
                  onPressed: () {
                    setState(() {
                      _isWhiteColor = !_isWhiteColor;
                    });
                  },
                ),
                const SizedBox(width: 16),
                // 字体大小调整按钮
                PopupMenuButton<double>(
                  tooltip: '调整字体大小',
                  icon: Icon(
                    Icons.text_fields,
                    color: _isWhiteColor ? Colors.white : Colors.black,
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
                      _fontSize = (_fontSize + value).clamp(14.0, 34.0);
                    });
                  },
                ),
              ],
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
    required Color color,
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
            hoverColor: color.withOpacity(0.1),
            child: Icon(
              icon,
              size: size,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // 更新字体设置
  void _updateFontSettings() {
    setState(() {
      _fontSize = _settingsService.settings.fontFamily == 'System Default' ? 18.0 : 18.0; // 修改默认字体大小
      _fontFamily = _settingsService.settings.fontFamily == 'System Default' ? null : _settingsService.settings.fontFamily;
    });
  }

  // 从封面提取颜色 - 优化性能
  Future<void> _extractColorsFromCover(MusicFile music) async {
    if (_isLoadingColors || music.id == null) return;
    
    // 再次检查，如果是无封面的情况，直接使用主题色
    if (!music.hasEmbeddedCover && music.coverPath == null) {
      setState(() {
        _primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
        _secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
        _isLoadingColors = false;
      });
      debugPrint('无封面，直接使用主题颜色: ${music.title}');
      return;
    }
    
    // 检查缓存
    if (_colorCache.containsKey(music.id)) {
      setState(() {
        _primaryColor = _colorCache[music.id]![0];
        _secondaryColor = _colorCache[music.id]![1];
        _isLoadingColors = false;
      });
      debugPrint('使用本地缓存的颜色: ${music.title}');
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
        
        // 尝试从AudioPlayerService获取预加载的颜色
        final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
        final cachedColors = audioPlayer.getCachedColors(music.id);
        
        if (cachedColors != null) {
          primaryColor = cachedColors[0];
          secondaryColor = cachedColors[1];
          
          // 缓存并立即使用这些颜色
          _colorCache[music.id] = [primaryColor, secondaryColor];
          
          if (mounted) {
            setState(() {
              _primaryColor = primaryColor;
              _secondaryColor = secondaryColor;
              _isLoadingColors = false;
            });
          }
          return;
        } else if (music.coverPath != null) {
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
          
        } else if (music.hasEmbeddedCover) {
          // 从内存数据加载图片
          final coverBytes = await music.getCoverBytes();
          if (coverBytes != null && coverBytes.isNotEmpty) {
            final imageProvider = MemoryImage(Uint8List.fromList(coverBytes));
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
            // 无法获取封面数据，使用默认颜色
            primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
            secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
          }
        } else {
          // 默认渐变色 - 使用主题色
          primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
          secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
        }
        
        // 缓存提取的颜色，即使组件已卸载也保存缓存
        _colorCache[music.id] = [primaryColor, secondaryColor];
        
        // 设置渐变色，只在组件仍挂载时
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

  // 修改歌曲变化检测和颜色加载
  void _handleMusicChange(MusicFile newMusic) async {
    if (_currentDisplayedMusic == null || newMusic.id != _currentDisplayedMusic!.id) {
      if (mounted) {
        // 缓存内嵌封面数据
        if (newMusic.hasEmbeddedCover && newMusic.id != null && !_coverImageCache.containsKey(newMusic.id)) {
          try {
            final coverBytes = await newMusic.getCoverBytes();
            if (coverBytes != null && coverBytes.isNotEmpty) {
              _coverImageCache[newMusic.id!] = Uint8List.fromList(coverBytes);
            }
          } catch (e) {
            debugPrint('加载封面数据错误: $e');
          }
        }
        
        // 清理封面组件缓存，只保留当前歌曲的缓存，防止内存占用过大
        if (newMusic.id != null) {
          final keysToKeep = [newMusic.id];
          _coverWidgetCache.removeWhere((key, _) => !keysToKeep.contains(key));
        }
        
        setState(() {
          _currentDisplayedMusic = newMusic;
          _lyrics = []; // 清空歌词以显示加载状态
          _currentLineIndex = 0;
          
          // 在这里直接处理无封面情况的颜色设置
          if (!newMusic.hasEmbeddedCover && newMusic.coverPath == null) {
            _primaryColor = Theme.of(context).colorScheme.primary.withOpacity(0.6);
            _secondaryColor = Theme.of(context).colorScheme.secondary.withOpacity(0.6);
            debugPrint('歌曲切换时设置无封面背景色: ${newMusic.title}');
          }
        });
        _loadLyrics(newMusic);
        _usePreloadedColorsOrExtract(newMusic);
        debugPrint('检测到歌曲切换，正在加载新内容: ${newMusic.title}');
      }
    }
  }

  // 添加没有封面时的默认图片构建方法
  Widget _buildNoCoverImage(MusicFile music, BuildContext context) {
    return RepaintBoundary(
      child: Hero(
        tag: 'no-cover-${music.id}',
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.7),
                Theme.of(context).colorScheme.secondary.withOpacity(0.7),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note,
              size: 120,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class LyricLine {
  final Duration time;
  final String text;
  final String? translation;
  
  const LyricLine({
    required this.time, 
    required this.text, 
    this.translation,
  });

  @override
  String toString() {
    return 'LyricLine(time: $time, text: $text, translation: $translation)';
  }
} 