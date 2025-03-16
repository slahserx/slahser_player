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

class LyricsPage extends StatefulWidget {
  final MusicFile music;

  const LyricsPage({super.key, required this.music});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  bool _showLyricsControls = false;
  Timer? _hideControlsTimer;
  double _fontSize = 16.0;
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  int _currentLineIndex = 0;
  Duration _lastPosition = Duration.zero;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    
    // 启动定时器，定期更新当前行
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
      final position = audioPlayer.position;
      
      if (position != _lastPosition) {
        _lastPosition = position;
        _updateCurrentLine(position);
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

  Future<void> _loadLyrics() async {
    if (widget.music.lyricsPath == null) {
      setState(() {
        _lyrics = [LyricLine(time: Duration.zero, text: '暂无歌词')];
      });
      return;
    }

    try {
      final file = File(widget.music.lyricsPath!);
      if (!await file.exists()) {
        setState(() {
          _lyrics = [LyricLine(time: Duration.zero, text: '歌词文件不存在')];
        });
        return;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');
      final parsedLyrics = <LyricLine>[];

      for (final line in lines) {
        final lyricLine = _parseLyricLine(line);
        if (lyricLine != null) {
          parsedLyrics.add(lyricLine);
        }
      }

      if (parsedLyrics.isEmpty) {
        parsedLyrics.add(LyricLine(time: Duration.zero, text: '无法解析歌词'));
      }

      // 按时间排序
      parsedLyrics.sort((a, b) => a.time.compareTo(b.time));

      setState(() {
        _lyrics = parsedLyrics;
      });
    } catch (e) {
      setState(() {
        _lyrics = [LyricLine(time: Duration.zero, text: '读取歌词失败: $e')];
      });
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
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    
    return StreamBuilder<PlaybackState>(
      stream: audioPlayer.playbackState,
      initialData: PlaybackState.stopped,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlaybackState.playing;
        
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          body: Consumer<AudioPlayerService>(
            builder: (context, audioPlayer, child) {
              final position = audioPlayer.position;
              final duration = audioPlayer.duration;
              
              return Stack(
                children: [
                  // 主内容
                  Row(
                    children: [
                      // 左侧：歌曲信息
                      SizedBox(
                        width: 400,
                        child: _buildMusicInfo(context, widget.music, audioPlayer, position, duration),
                      ),
                      // 右侧：歌词
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => _showLyricsControlsTemporarily(),
                          onHover: (_) => _showLyricsControlsTemporarily(),
                          child: _buildLyrics(context, audioPlayer),
                        ),
                      ),
                    ],
                  ),
                  
                  // 顶部返回按钮 - 始终显示
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
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 右上角字体调整按钮 - 仅当鼠标在歌词区域时显示
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _showLyricsControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Material(
                                color: Colors.transparent,
                                child: Tooltip(
                                  message: '减小字体',
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _fontSize = (_fontSize - 2).clamp(12.0, 32.0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.text_decrease),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Material(
                                color: Colors.transparent,
                                child: Tooltip(
                                  message: '增大字体',
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _fontSize = (_fontSize + 2).clamp(12.0, 32.0);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.text_increase),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMusicInfo(BuildContext context, MusicFile music, AudioPlayerService audioPlayer, Duration position, Duration duration) {
    final isPlaying = audioPlayer.playbackState == PlaybackState.playing;
    
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 封面
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: music.coverPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Hero(
                      tag: 'cover-${music.id}',
                      child: Image.file(
                        File(music.coverPath!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth: 600,
                        cacheHeight: 600,
                        key: ValueKey(music.coverPath), // 使用路径作为key，防止重建
                      ),
                    ),
                  )
                : music.hasEmbeddedCover
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Hero(
                          tag: 'embedded-cover-${music.id}',
                          child: Image.memory(
                            Uint8List.fromList(music.getCoverBytes()!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            cacheWidth: 600,
                            cacheHeight: 600,
                            key: ValueKey(music.id), // 使用ID作为key，防止重建
                          ),
                        ),
                      )
                    : Hero(
                        tag: 'no-cover-${music.id}',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.music_note,
                            size: 80,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 40),
          // 歌曲信息
          Text(
            music.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            music.artist,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            music.album,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 40),
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
                  // 如果切换了歌曲，需要关闭当前页面并打开新歌曲的歌词页面
                  if (audioPlayer.currentMusic?.id != widget.music.id) {
                    Navigator.pop(context);
                    if (audioPlayer.currentMusic != null) {
                      Navigator.push(
                        context,
                        LyricsPageTransition(
                          page: LyricsPage(music: audioPlayer.currentMusic!),
                        ),
                      );
                    }
                  }
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
                  // 如果切换了歌曲，需要关闭当前页面并打开新歌曲的歌词页面
                  if (audioPlayer.currentMusic?.id != widget.music.id) {
                    Navigator.pop(context);
                    if (audioPlayer.currentMusic != null) {
                      Navigator.push(
                        context,
                        LyricsPageTransition(
                          page: LyricsPage(music: audioPlayer.currentMusic!),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 进度条
          Row(
            children: [
              Text(
                AudioPlayerService.formatDuration(position),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyrics(BuildContext context, AudioPlayerService audioPlayer) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _lyrics.length,
        itemBuilder: (context, index) {
          final isCurrentLine = index == _currentLineIndex;
          
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _seekToLyricLine(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentLine 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lyrics[index].text,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: isCurrentLine ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentLine 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
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
            hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            child: Container(
              width: size + 8,
              height: size + 8,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: size,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
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
  
  LyricLine({required this.time, required this.text});
} 