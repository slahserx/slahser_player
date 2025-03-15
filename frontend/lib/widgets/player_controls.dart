import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/pages/lyrics_page.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/widgets/equalizer_dialog.dart';
import 'dart:io';
import 'dart:math' as math;

// 音量滑块组件 - 无状态实现，完全依赖AudioPlayerService
class VolumeSlider extends StatelessWidget {
  final AudioPlayerService audioPlayer;
  
  const VolumeSlider({
    super.key,
    required this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    // 直接从AudioPlayerService获取当前音量
    final volume = audioPlayer.volume;
    final isMuted = audioPlayer.isMuted;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surfaceVariant;
    
    // 实际绘制使用的音量值 - 静音时显示为0
    final displayVolume = isMuted ? 0.0 : volume;
    
    return SizedBox(
      width: 100,
      height: 36,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final position = renderBox.globalToLocal(details.globalPosition);
          final percent = (position.dx / renderBox.size.width).clamp(0.0, 1.0);
          audioPlayer.setVolume(percent);
        },
        onTapDown: (details) {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final position = renderBox.globalToLocal(details.globalPosition);
          final percent = (position.dx / renderBox.size.width).clamp(0.0, 1.0);
          audioPlayer.setVolume(percent);
        },
        child: CustomPaint(
          painter: _VolumeSliderPainter(
            value: displayVolume,
            activeColor: primaryColor,
            inactiveColor: surfaceColor,
          ),
        ),
      ),
    );
  }
}

// 自定义绘制音量滑块
class _VolumeSliderPainter extends CustomPainter {
  final double value;
  final Color activeColor;
  final Color inactiveColor;
  
  _VolumeSliderPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 2.0;
    final thumbRadius = 4.0;
    
    // 计算滑块位置（但不应低于0或超过宽度）
    final thumbX = (value.clamp(0.0, 1.0) * size.width).clamp(0.0, size.width);
    final centerY = size.height / 2;
    
    // 绘制轨道
    final trackPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round; // 添加圆角
    
    final activeTrackPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round; // 添加圆角
    
    // 绘制非活动轨道
    canvas.drawLine(
      Offset(thumbRadius, centerY),
      Offset(size.width - thumbRadius, centerY),
      trackPaint,
    );
    
    // 只有当滑块位置大于0时才绘制活动轨道
    if (thumbX > thumbRadius) {
      canvas.drawLine(
        Offset(thumbRadius, centerY),
        Offset(thumbX, centerY),
        activeTrackPaint,
      );
    }
    
    // 绘制滑块
    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5); // 添加轻微模糊效果
    
    canvas.drawCircle(
      Offset(thumbX, centerY),
      thumbRadius,
      thumbPaint,
    );
  }
  
  @override
  bool shouldRepaint(_VolumeSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioPlayerService>(
      builder: (context, audioPlayer, child) {
        final currentMusic = audioPlayer.currentMusic;
        final isPlaying = audioPlayer.playbackState == PlaybackState.playing;
        final position = audioPlayer.position;
        final duration = audioPlayer.duration;
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          ),
          child: Column(
            children: [
              // 控制区域
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // 左侧：歌曲信息
                      SizedBox(
                        width: 300,
                        child: Row(
                          children: [
                            // 封面 - 可点击进入歌词页面
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  if (currentMusic != null) {
                                    _navigateToLyricsPage(context, currentMusic);
                                  }
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: currentMusic?.coverPath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.file(
                                            File(currentMusic!.coverPath!),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(
                                          Icons.music_note,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 歌曲信息 - 不可点击
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentMusic?.title ?? '未播放',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    currentMusic?.artist ?? '未知艺术家',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 中间：播放控制
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 控制按钮
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildControlButton(
                                  context,
                                  icon: _getPlaybackModeIcon(audioPlayer.playbackMode),
                                  tooltip: _getPlaybackModeTooltip(audioPlayer.playbackMode),
                                  isActive: audioPlayer.playbackMode != PlaybackMode.sequential,
                                  onPressed: () {
                                    audioPlayer.togglePlaybackMode();
                                  },
                                ),
                                _buildControlButton(
                                  context,
                                  icon: Icons.skip_previous,
                                  tooltip: '上一曲',
                                  onPressed: () {
                                    audioPlayer.previous();
                                  },
                                ),
                                _buildPlayButton(
                                  context,
                                  isPlaying: isPlaying,
                                  onPressed: () {
                                    audioPlayer.playOrPause();
                                  },
                                ),
                                _buildControlButton(
                                  context,
                                  icon: Icons.skip_next,
                                  tooltip: '下一曲',
                                  onPressed: () {
                                    audioPlayer.next();
                                  },
                                ),
                                _buildControlButton(
                                  context,
                                  icon: Icons.equalizer,
                                  tooltip: '均衡器',
                                  isActive: audioPlayer.isEqualizerEnabled,
                                  onPressed: () {
                                    _showEqualizerDialog(context);
                                  },
                                ),
                              ],
                            ),
                            // 进度条和时间显示
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
                                      value: math.max(0, math.min(position.inMilliseconds.toDouble(), 
                                              duration.inMilliseconds.toDouble())),
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
                      ),
                      // 右侧：音量控制
                      SizedBox(
                        width: 300,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildControlButton(
                              context,
                              icon: Icons.lyrics_outlined,
                              tooltip: '歌词',
                              onPressed: () {
                                if (currentMusic != null) {
                                  _navigateToLyricsPage(context, currentMusic);
                                }
                              },
                            ),
                            _buildControlButton(
                              context,
                              icon: Icons.queue_music_outlined,
                              tooltip: '播放队列',
                              onPressed: () {
                                _showPlaylist(context, audioPlayer);
                              },
                            ),
                            _buildControlButton(
                              context,
                              icon: audioPlayer.isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                              tooltip: audioPlayer.isMuted ? '取消静音' : '静音',
                              onPressed: () {
                                audioPlayer.toggleMute();
                              },
                            ),
                            VolumeSlider(audioPlayer: audioPlayer),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _navigateToLyricsPage(BuildContext context, MusicFile music) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LyricsPage(music: music),
      ),
    );
  }
  
  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    bool isActive = false,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlayButton(
    BuildContext context, {
    required bool isPlaying,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: isPlaying ? '暂停' : '播放',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.transparent,
            hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getPlaybackModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return Icons.repeat;
      case PlaybackMode.shuffle:
        return Icons.shuffle;
      case PlaybackMode.repeatOne:
        return Icons.repeat_one;
    }
  }
  
  String _getPlaybackModeTooltip(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.sequential:
        return '顺序播放';
      case PlaybackMode.shuffle:
        return '随机播放';
      case PlaybackMode.repeatOne:
        return '单曲循环';
    }
  }
  
  void _showPlaylist(BuildContext context, AudioPlayerService audioPlayer) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '播放队列',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: audioPlayer.playlist.length,
                  itemBuilder: (context, index) {
                    final music = audioPlayer.playlist[index];
                    final isCurrentMusic = audioPlayer.currentMusic?.id == music.id;
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: 20,
                          color: isCurrentMusic
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      title: Text(
                        music.title,
                        style: TextStyle(
                          color: isCurrentMusic ? Theme.of(context).colorScheme.primary : null,
                          fontWeight: isCurrentMusic ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text(
                        music.artist,
                        style: TextStyle(
                          color: isCurrentMusic
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        audioPlayer.playMusic(music);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showEqualizerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EqualizerDialog(),
    );
  }
} 