import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:rxdart/rxdart.dart';
import '../enums/playback_state.dart';
import 'dart:ui' as ui;
import 'package:palette_generator/palette_generator.dart';
import 'dart:io';

enum RepeatMode {
  off,
  all,
  one,
}

enum PlaybackMode {
  sequential, // 顺序播放
  shuffle,    // 随机播放
  repeatOne   // 单曲循环
}

class AudioPlayerService extends ChangeNotifier {
  // 播放器实例
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 设置服务引用
  SettingsService? _settingsService;
  
  // 播放列表服务引用
  PlaylistService? _playlistService;
  
  // 当前播放列表
  List<MusicFile> _playlist = [];
  List<MusicFile> get playlist => _playlist;
  
  // 当前播放的音乐
  MusicFile? _currentMusic;
  MusicFile? get currentMusic => _currentMusic;
  
  // 当前音乐变化的流
  final _currentMusicSubject = BehaviorSubject<MusicFile?>.seeded(null);
  Stream<MusicFile?> get currentMusicStream => _currentMusicSubject.stream;
  
  // 是否正在切换歌曲（用于避免滑块动画）
  bool _isChangingTrack = false;
  bool get isChangingTrack => _isChangingTrack;
  
  // 当前播放状态
  final _playbackState = BehaviorSubject<PlaybackState>.seeded(PlaybackState.stopped);
  Stream<PlaybackState> get playbackState => _playbackState.stream;
  
  // 当前播放进度
  Duration _position = Duration.zero;
  Duration get position => _position;
  
  // 当前音乐总时长
  Duration _duration = Duration.zero;
  Duration get duration => _duration;
  
  // 当前音量
  double _volume = 1.0;
  double get volume => _volume;
  
  // 是否静音
  bool _isMuted = false;
  bool get isMuted => _isMuted;
  
  // 循环模式
  RepeatMode _loopMode = RepeatMode.off;
  RepeatMode get loopMode => _loopMode;
  
  // 播放模式
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  PlaybackMode get playbackMode => _playbackMode;
  
  // 是否随机播放
  bool get isShuffled => _playbackMode == PlaybackMode.shuffle;
  
  // 均衡器设置
  bool _isEqualizerEnabled = false;
  bool get isEqualizerEnabled => _isEqualizerEnabled;
  
  List<double> _equalizerValues = List.filled(10, 0.0);
  List<double> get equalizerValues => _equalizerValues;
  
  // 原始播放列表（未打乱顺序）
  List<MusicFile> _originalPlaylist = [];
  
  // 定时器，用于更新播放进度
  Timer? _positionTimer;
  
  // 淡入淡出设置
  bool _enableFadeEffect = true;
  int _fadeInDuration = 500;
  int _fadeOutDuration = 500;
  
  // 添加图片预加载和颜色提取缓存
  final Map<String, ui.Image?> _imageCache = {};
  final Map<String, List<Color>> _colorCache = {};
  bool _isPreloadingImage = false;
  
  AudioPlayerService() {
    // 初始化音频会话
    AudioSession.instance.then((session) {
      session.configure(const AudioSessionConfiguration.music());
    });

    // 设置播放器状态监听
    _audioPlayer.playerStateStream
      .handleError((error, stackTrace) {
        // 忽略BufferingProgress错误
        if (error.toString().contains('BufferingProgress')) {
          debugPrint('忽略BufferingProgress错误: $error');
          return;
        } else {
          debugPrint('播放器错误: $error');
          // 对于其他类型的错误，传递
          Error.throwWithStackTrace(error, stackTrace);
        }
      })
      .listen((state) {
        debugPrint('播放器状态变化: ${state.playing ? "播放中" : "已暂停"}, ${state.processingState}');
        // 当前是否有音乐加载
        final bool hasCurrent = _currentMusic != null;
        
        if (state.playing) {
          _playbackState.add(PlaybackState.playing);
          debugPrint('状态更新为: 播放中');
        } else {
          switch (state.processingState) {
            case ProcessingState.idle:
            case ProcessingState.completed:
              _playbackState.add(hasCurrent ? PlaybackState.completed : PlaybackState.stopped);
              debugPrint('状态更新为: ${hasCurrent ? "完成" : "停止"}');
              break;
            case ProcessingState.loading:
            case ProcessingState.buffering:
              _playbackState.add(PlaybackState.loading);
              debugPrint('状态更新为: 加载中');
              break;
            case ProcessingState.ready:
              if (hasCurrent) {
                _playbackState.add(PlaybackState.paused);
                debugPrint('状态更新为: 暂停');
              } else {
                _playbackState.add(PlaybackState.stopped);
                debugPrint('状态更新为: 停止（无当前音乐）');
              }
              break;
          }
        }
      });
      
    // 初始化
    init();
  }
  
  // 初始化方法
  Future<void> init() async {
    // 初始化音频播放器事件监听
    _audioPlayer.playbackEventStream
      .handleError((error, stackTrace) {
        // 忽略BufferingProgress错误
        if (error.toString().contains('BufferingProgress')) {
          debugPrint('事件流忽略BufferingProgress错误: $error');
          return;
        } else {
          debugPrint('播放事件错误: $error');
          Error.throwWithStackTrace(error, stackTrace);
        }
      })
      .listen((event) {
        if (event.processingState == ProcessingState.completed) {
          _handlePlaybackCompletion();
        }
      });
    
    // 添加音频位置监听器
    _audioPlayer.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });
    
    // 添加音频时长监听器
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _duration = duration;
        notifyListeners();
      }
    });
    
    // 配置初始设置
    _audioPlayer.setVolume(_volume);
  }
  
  // 添加currentPlaylist getter
  List<MusicFile> get currentPlaylist => _playlist;
  
  // 设置设置服务
  Future<void> setSettingsService(SettingsService service) async {
    _settingsService = service;
    
    try {
      // 立即从设置加载音量和静音状态
      final settings = await service.loadSettings();
      if (settings != null) {
        // 设置内部状态
        _volume = settings.volume;
        _isMuted = settings.isMuted;
        
        // 立即应用到播放器
        final actualVolume = _isMuted ? 0.0 : _volume;
        await _audioPlayer.setVolume(actualVolume);
        
        debugPrint('从设置加载音量: $_volume, 静音: $_isMuted');
        notifyListeners(); // 通知UI更新
      }
    } catch (e) {
      debugPrint('加载音量设置失败: $e');
    }
  }
  
  // 设置播放列表服务
  void setPlaylistService(PlaylistService playlistService) {
    _playlistService = playlistService;
  }
  
  // 更新播放模式
  Future<void> _updatePlaybackMode() async {
    switch (_playbackMode) {
      case PlaybackMode.sequential:
        await _audioPlayer.setShuffleModeEnabled(false);
        await _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case PlaybackMode.shuffle:
        await _audioPlayer.setShuffleModeEnabled(true);
        await _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case PlaybackMode.repeatOne:
        await _audioPlayer.setShuffleModeEnabled(false);
        await _audioPlayer.setLoopMode(LoopMode.one);
        break;
    }
  }
  
  // 更新淡入淡出设置
  void updateFadeSettings(bool enable, int fadeIn, int fadeOut) {
    _enableFadeEffect = enable;
    _fadeInDuration = fadeIn;
    _fadeOutDuration = fadeOut;
  }
  
  // 设置播放列表
  Future<void> setPlaylist(List<MusicFile> musicList, {int initialIndex = 0, bool autoPlay = true, bool shuffle = false}) async {
    if (musicList.isEmpty) {
      debugPrint('播放列表为空');
      return;
    }
    
    _playlist = List.from(musicList);
    _originalPlaylist = List.from(musicList);
    
    // 如果启用随机播放或传入shuffle参数为true，则打乱播放顺序
    if (_playbackMode == PlaybackMode.shuffle || shuffle) {
      _shufflePlaylist();
    }
    
    debugPrint('设置播放列表，${musicList.length}首歌曲，初始索引：$initialIndex');
    
    // 如果需要自动播放，播放指定索引的歌曲
    if (autoPlay && initialIndex >= 0 && initialIndex < _playlist.length) {
      await playMusic(_playlist[initialIndex]);
    } else {
      // 否则只设置当前音乐，不播放
      _currentMusic = initialIndex >= 0 && initialIndex < _playlist.length ? _playlist[initialIndex] : null;
      // 通知音乐变化监听器
      _currentMusicSubject.add(_currentMusic);
      notifyListeners();
    }
  }
  
  // 打乱播放列表顺序
  void _shufflePlaylist() {
    if (_playlist.isEmpty) return;
    
    // 保存当前播放的音乐
    final currentMusic = _currentMusic;
    
    // 打乱列表
    _playlist.shuffle();
    
    // 如果有当前播放的音乐，将其移到最前面
    if (currentMusic != null && _playlist.contains(currentMusic)) {
      _playlist.remove(currentMusic);
      _playlist.insert(0, currentMusic);
    }
    
    debugPrint('打乱播放列表完成，${_playlist.length}首歌曲');
  }
  
  // 播放音乐
  Future<void> playMusic(MusicFile music) async {
    try {
      _isChangingTrack = true;
      notifyListeners();
      
      // 停止之前的播放
      await _audioPlayer.stop();
      
      debugPrint('准备播放音乐: ${music.title}, ID: ${music.id}');
      
      // 如果是新的音乐，设置当前音乐和音频源
      _currentMusic = music;
      // 通知音乐变化监听器
      _currentMusicSubject.add(music);
      
      // 预加载下一首歌曲的图片和颜色
      _preloadImageAndExtractColors(music);
      
      // 更新音频源
      debugPrint('设置音频源: ${music.filePath}');
      
      // 使用文件Uri加载
      final fileUri = Uri.file(music.filePath);
      
      try {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(fileUri),
          preload: true,
        );
        debugPrint('音频源设置成功');
      } catch (e) {
        debugPrint('设置音频源失败: $e');
        // 尝试再次设置
        try {
          await _audioPlayer.setUrl(music.filePath);
          debugPrint('使用备用方法设置音频源成功');
        } catch (e) {
          debugPrint('备用方法设置音频源也失败: $e');
          _isChangingTrack = false;
          notifyListeners();
          rethrow;
        }
      }
      
      // 强制延迟一小段时间，确保音频源准备好
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 开始播放
      try {
        debugPrint('尝试播放: ${music.title}, ID: ${music.id}');
        await _audioPlayer.play().catchError((error) {
          // 忽略BufferingProgress错误
          if (error.toString().contains('BufferingProgress')) {
            debugPrint('播放时忽略BufferingProgress错误: $error');
            return null;
          }
          throw error;
        });
          
        // 成功播放后，明确设置为播放状态
        debugPrint('开始播放: ${music.title}, ID: ${music.id}');
        _playbackState.add(PlaybackState.playing);
      } catch (e) {
        if (e.toString().contains('BufferingProgress')) {
          debugPrint('忽略播放时的BufferingProgress错误');
          _playbackState.add(PlaybackState.playing);
        } else {
          debugPrint('开始播放失败: $e');
          _playbackState.add(PlaybackState.error);
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('播放音乐失败: $e');
      _playbackState.add(PlaybackState.error);
      rethrow;
    }
  }
  
  // 预加载图片和提取颜色
  Future<void> _preloadImageAndExtractColors(MusicFile music) async {
    if (_isPreloadingImage || music.id == null) return;
    
    _isPreloadingImage = true;
    
    Future.microtask(() async {
      try {
        // 检查封面路径
        if (music.coverPath != null) {
          final file = File(music.coverPath!);
          if (await file.exists()) {
            try {
              // 尝试读取文件到内存以预热缓存
              await file.readAsBytes();
              debugPrint('预缓存了图片文件: ${music.title}');
            } catch (e) {
              debugPrint('预缓存图片失败: $e');
            }
          }
        }
        // 确保嵌入式封面可用
        else if (music.hasEmbeddedCover) {
          try {
            final coverBytes = await music.getCoverBytes();
            if (coverBytes != null && coverBytes.isNotEmpty) {
              debugPrint('内嵌图片已在内存中: ${music.title}，大小: ${coverBytes.length} 字节');
            } else {
              debugPrint('⚠️ 内嵌图片标记为存在但获取失败: ${music.title}');
            }
          } catch (e) {
            debugPrint('⚠️ 获取内嵌图片时出错: $e');
          }
        }
        
        // 如果颜色已经提取过，则不需要再次提取
        if (_colorCache.containsKey(music.id!)) {
          _isPreloadingImage = false;
          return;
        }
        
        List<Color> colors = [
          Colors.blue.withOpacity(0.6),
          Colors.purple.withOpacity(0.6)
        ];
        
        bool extractedColors = false;
        
        // 从封面图片中提取颜色
        if (music.coverPath != null) {
          final file = File(music.coverPath!);
          if (await file.exists()) {
            try {
              // 使用较小的图片尺寸以提高性能
              final paletteGenerator = await PaletteGenerator.fromImageProvider(
                FileImage(file),
                size: const Size(100, 100),
                maximumColorCount: 10,
              );
              
              colors[0] = (paletteGenerator.dominantColor?.color ?? 
                        paletteGenerator.vibrantColor?.color ?? 
                        Colors.blue).withOpacity(0.6);
              
              colors[1] = (paletteGenerator.mutedColor?.color ?? 
                          paletteGenerator.darkVibrantColor?.color ?? 
                          Colors.purple).withOpacity(0.6);
              
              extractedColors = true;
              debugPrint('✅ 从文件提取了颜色: ${music.title}');
            } catch (e) {
              debugPrint('⚠️ 从文件提取颜色失败: $e');
            }
          }
        }
        
        // 尝试从嵌入式封面提取颜色
        if (!extractedColors && music.hasEmbeddedCover) {
          try {
            final coverBytes = await music.getCoverBytes();
            if (coverBytes != null && coverBytes.isNotEmpty) {
              try {
                final paletteGenerator = await PaletteGenerator.fromImageProvider(
                  MemoryImage(Uint8List.fromList(coverBytes)),
                  size: const Size(100, 100),
                  maximumColorCount: 10,
                );
                
                colors[0] = (paletteGenerator.dominantColor?.color ?? 
                          paletteGenerator.vibrantColor?.color ?? 
                          Colors.blue).withOpacity(0.6);
                
                colors[1] = (paletteGenerator.mutedColor?.color ?? 
                          paletteGenerator.darkVibrantColor?.color ?? 
                          Colors.purple).withOpacity(0.6);
                
                extractedColors = true;
                debugPrint('✅ 从内嵌图片提取了颜色: ${music.title}，图片大小: ${coverBytes.length}字节');
              } catch (e) {
                debugPrint('⚠️ 从内嵌图片提取颜色失败: $e');
              }
            } else {
              debugPrint('⚠️ 无法获取内嵌图片数据: ${music.title}');
            }
          } catch (e) {
            debugPrint('⚠️ 获取内嵌图片时出错: $e');
          }
        }
        
        // 缓存提取的颜色
        _colorCache[music.id!] = colors;
        
        debugPrint('预加载完成: 已提取 ${music.title} 的颜色');
        
        // 预加载播放列表中的下一首歌
        _preloadNextSong(music);
      } catch (e) {
        debugPrint('预加载图片或提取颜色时出错: $e');
      } finally {
        _isPreloadingImage = false;
      }
    });
  }
  
  // 预加载播放列表中的下一首歌
  Future<void> _preloadNextSong(MusicFile currentMusic) async {
    if (_playlist.isEmpty) return;
    
    try {
      final currentIndex = _playlist.indexOf(currentMusic);
      if (currentIndex == -1 || currentIndex >= _playlist.length - 1) return;
      
      // 获取下一首歌
      final nextMusic = _playlist[currentIndex + 1];
      
      // 如果已经缓存了下一首歌的颜色，就不需要再预加载
      if (_colorCache.containsKey(nextMusic.id!)) return;
      
      // 异步预加载下一首歌的图片和颜色
      Future.delayed(const Duration(milliseconds: 500), () {
        _preloadImageAndExtractColors(nextMusic);
      });
    } catch (e) {
      debugPrint('预加载下一首歌曲失败: $e');
    }
  }
  
  // 获取缓存的颜色
  List<Color>? getCachedColors(String? musicId) {
    if (musicId == null) return null;
    return _colorCache[musicId];
  }
  
  // 内部淡入方法 - 不触发UI更新
  Future<void> _internalFadeIn(int durationMs, double targetVolume) async {
    if (durationMs <= 0) return;
    
    final steps = 10;
    final stepDuration = durationMs ~/ steps;
    final volumeStep = targetVolume / steps;
    
    // 设置初始音量为0
    await _audioPlayer.setVolume(0);
    
    // 淡入过程中静默设置音量，不通知UI
    for (int i = 1; i <= steps; i++) {
      await _audioPlayer.setVolume(volumeStep * i);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
    
    // 设置最终音量
    await setVolume(targetVolume, notify: false);
  }
  
  // 淡出效果
  Future<void> _fadeOut(int durationMs) async {
    if (durationMs <= 0) return;
    
    final steps = 10;
    final stepDuration = durationMs ~/ steps;
    final initialVolume = _audioPlayer.volume;
    final volumeStep = initialVolume / steps;
    
    // 淡出过程中静默设置音量，不触发通知
    for (int i = steps - 1; i >= 0; i--) {
      await _audioPlayer.setVolume(volumeStep * i);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }
  
  // 播放/暂停
  Future<void> playOrPause() async {
    try {
      final music = _currentMusic;
      
      if (music == null) {
        // 如果没有当前音乐但有播放列表，播放第一首
        if (_playlist.isNotEmpty) {
          debugPrint('没有当前音乐，但有播放列表，播放第一首');
          await playMusic(_playlist.first);
        } else {
          debugPrint('没有当前音乐且播放列表为空，无法播放');
          return;
        }
      } else {
        // 如果当前状态是播放中，则暂停
        if (_audioPlayer.playing) {
          debugPrint('当前正在播放，执行暂停');
          await _audioPlayer.pause();
        } else {
          // 否则开始播放
          debugPrint('尝试播放: ${music.title}, ID: ${music.id}');
          final result = await _audioPlayer.play();
          debugPrint('开始播放: ${music.title}, ID: ${music.id}');
        }
      }
    } catch (e) {
      debugPrint('播放/暂停时出错: $e');
    }
  }
  
  // 暂停
  Future<void> pause() async {
    if (_playbackState.value == PlaybackState.playing) {
      await _audioPlayer.pause();
      _playbackState.add(PlaybackState.paused);
      notifyListeners();
    }
  }
  
  // 恢复播放
  Future<void> resume() async {
    if (_playbackState.value == PlaybackState.paused || 
        _playbackState.value == PlaybackState.stopped || 
        _playbackState.value == PlaybackState.completed) {
      await _audioPlayer.play();
      _playbackState.add(PlaybackState.playing);
      notifyListeners();
    }
  }
  
  // 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _position = Duration.zero;
    _playbackState.add(PlaybackState.stopped);
    notifyListeners();
  }
  
  // 下一曲
  Future<void> next() async {
    if (_playlist.isEmpty || _currentMusic == null) return;
    
    debugPrint('切换到下一首歌曲');
    
    // 查找当前音乐在播放列表中的索引
    final currentIndex = _playlist.indexOf(_currentMusic!);
    
    // 计算下一首的索引
    int nextIndex = -1;
    
    if (currentIndex != -1) {
      if (_loopMode == RepeatMode.one || _playbackMode == PlaybackMode.repeatOne) {
        // 单曲循环模式，重新播放当前歌曲
        nextIndex = currentIndex;
      } else {
        // 正常模式，播放下一首
        nextIndex = (currentIndex + 1) % _playlist.length;
      }
    } else if (!_playlist.isEmpty) {
      // 如果找不到当前音乐，从头开始播放
      nextIndex = 0;
    }
    
    if (nextIndex != -1) {
      final nextMusic = _playlist[nextIndex];
      debugPrint('强制播放下一首: ${nextMusic.title}');
      try {
        await playMusic(nextMusic);
      } catch (e) {
        debugPrint('播放下一首失败，尝试跳过: $e');
        // 如果遇到错误，尝试播放再下一首
        if (nextIndex < _playlist.length - 1) {
          await playMusic(_playlist[nextIndex + 1]);
        }
      }
    }
  }
  
  // 上一曲
  Future<void> previous() async {
    if (_playlist.isEmpty || _currentMusic == null) return;
    
    debugPrint('切换到上一首歌曲');
    
    // 查找当前音乐在播放列表中的索引
    final currentIndex = _playlist.indexOf(_currentMusic!);
    
    // 计算上一首的索引
    int prevIndex = -1;
    
    if (currentIndex != -1) {
      if (_loopMode == RepeatMode.one || _playbackMode == PlaybackMode.repeatOne) {
        // 单曲循环模式，重新播放当前歌曲
        prevIndex = currentIndex;
      } else {
        // 正常模式，播放上一首
        prevIndex = (currentIndex - 1 + _playlist.length) % _playlist.length;
      }
    } else if (!_playlist.isEmpty) {
      // 如果找不到当前音乐，从头开始播放
      prevIndex = 0;
    }
    
    if (prevIndex != -1) {
      final prevMusic = _playlist[prevIndex];
      debugPrint('播放上一首: ${prevMusic.title}');
      try {
        await playMusic(prevMusic);
      } catch (e) {
        debugPrint('播放上一首失败，尝试跳过: $e');
        // 如果遇到错误，尝试播放再上一首
        if (prevIndex > 0) {
          await playMusic(_playlist[prevIndex - 1]);
        }
      }
    }
  }
  
  // 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    _position = position;
    notifyListeners();
  }
  
  // 设置音量 - 用于UI控制
  Future<void> setVolume(double volume, {bool notify = true}) async {
    if (volume < 0) volume = 0;
    if (volume > 1) volume = 1;
    
    // 如果值没有变化，不做任何操作
    if ((_volume - volume).abs() < 0.001 && _isMuted == (volume == 0)) {
      return;
    }
    
    bool wasMuted = _isMuted;
    _volume = volume;
    _isMuted = volume == 0;
    
    await _audioPlayer.setVolume(volume);
    
    // 保存设置到SettingsService
    if (_settingsService != null) {
      await _settingsService!.updateVolume(volume);
      if (wasMuted != _isMuted) {
        await _settingsService!.updateMuted(_isMuted);
      }
    }
    
    // 只有在需要时才通知监听器
    if (notify) {
      notifyListeners();
    }
  }
  
  // 静音切换
  Future<void> toggleMute() async {
    final bool newMutedState = !_isMuted;
    _isMuted = newMutedState;
    
    double volumeToSet;
    if (newMutedState) {
      // 静音前保存当前音量
      volumeToSet = 0;
    } else {
      // 取消静音时恢复音量
      volumeToSet = _volume > 0 ? _volume : 0.5;
    }
    
    await _audioPlayer.setVolume(volumeToSet);
    
    // 保存设置到SettingsService
    if (_settingsService != null) {
      await _settingsService!.updateMuted(newMutedState);
      if (!newMutedState && volumeToSet > 0) {
        await _settingsService!.updateVolume(volumeToSet);
      }
    }
    
    notifyListeners();
  }
  
  // 切换循环模式
  void toggleLoopMode() {
    switch (_loopMode) {
      case RepeatMode.off:
        _loopMode = RepeatMode.all;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _loopMode = RepeatMode.one;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _loopMode = RepeatMode.off;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
    notifyListeners();
  }
  
  // 更改播放模式
  void changePlaybackMode(PlaybackMode mode) {
    _playbackMode = mode;
    _updatePlaybackMode();
    notifyListeners();
  }
  
  // 循环切换播放模式
  void togglePlaybackMode() {
    switch (_playbackMode) {
      case PlaybackMode.sequential:
        changePlaybackMode(PlaybackMode.shuffle);
        break;
      case PlaybackMode.shuffle:
        changePlaybackMode(PlaybackMode.repeatOne);
        break;
      case PlaybackMode.repeatOne:
        changePlaybackMode(PlaybackMode.sequential);
        break;
    }
  }
  
  // 设置均衡器启用状态
  void setEqualizerEnabled(bool enabled) {
    _isEqualizerEnabled = enabled;
    _applyEqualizerSettings();
    notifyListeners();
  }
  
  // 设置均衡器值
  void setEqualizerValues(List<double> values) {
    if (values.length == _equalizerValues.length) {
      _equalizerValues = List.from(values);
      _applyEqualizerSettings();
      notifyListeners();
    }
  }
  
  // 应用均衡器设置
  void _applyEqualizerSettings() {
    // 这里实现实际的均衡器设置应用
    // 在实际应用中，这里需要调用平台特定的均衡器API
    
    // 示例：打印均衡器设置（实际应用中应替换为真实实现）
    if (_isEqualizerEnabled) {
      debugPrint('应用均衡器设置: $_equalizerValues');
    } else {
      debugPrint('均衡器已禁用');
    }
  }
  
  // 处理播放完成
  void _handlePlaybackCompletion() async {
    debugPrint('播放完成，处理下一步操作...');
    
    // 如果没有当前音乐，不做任何操作
    if (_currentMusic == null) {
      debugPrint('没有当前播放的音乐，忽略完成事件');
      return;
    }
    
    // 根据播放模式处理播放完成后的行为
    switch (_playbackMode) {
      case PlaybackMode.sequential:
        // 顺序播放模式下，播完最后一首后停止，否则继续播放下一首
        if (_currentMusic != null) {
          int currentIndex = _playlist.indexOf(_currentMusic!);
          if (currentIndex >= _playlist.length - 1) {
            debugPrint('播放列表已结束');
            _playbackState.add(PlaybackState.completed);
            notifyListeners();
          } else {
            debugPrint('播放下一首歌曲');
            // 播放下一首（PlayMusic已确保播放状态）
            await next();
          }
        }
        break;
        
      case PlaybackMode.shuffle:
        // 随机播放模式下，总是自动播放下一首
        debugPrint('随机播放模式，播放下一首');
        await next();
        break;
        
      case PlaybackMode.repeatOne:
        // 单曲循环模式下，重新播放当前歌曲
        if (_currentMusic != null) {
          debugPrint('单曲循环模式，重新播放当前歌曲');
          
          // 先停止当前播放
          await _audioPlayer.stop().catchError((error) {
            if (error.toString().contains('BufferingProgress')) {
              return null;
            }
            throw error;
          });
          
          // 重新播放当前歌曲
          await Future.delayed(const Duration(milliseconds: 500));
          await playMusic(_currentMusic!);
        }
        break;
    }
  }
  
  // 格式化时间
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
  
  // 从设置服务设置音量 - 不保存设置
  Future<void> setVolumeFromSettings(double volume) async {
    if (volume < 0) volume = 0;
    if (volume > 1) volume = 1;
    
    _volume = volume;
    _isMuted = volume == 0;
    
    await _audioPlayer.setVolume(volume);
    notifyListeners();
  }
  
  // 从设置服务设置静音状态 - 不保存设置
  Future<void> setMuteFromSettings(bool muted) async {
    _isMuted = muted;
    
    if (muted) {
      await _audioPlayer.setVolume(0);
    } else {
      await _audioPlayer.setVolume(_volume > 0 ? _volume : 0.5);
    }
    
    notifyListeners();
  }
  
  // 播放指定歌单
  Future<void> playPlaylist(String playlistId, {bool shuffle = false, int initialIndex = 0}) async {
    if (_playlistService == null) {
      debugPrint('错误：未设置播放列表服务');
      return;
    }
    
    final songs = _playlistService!.getPlaylistSongs(playlistId);
    if (songs.isEmpty) {
      debugPrint('错误：歌单为空，无法播放');
      return;
    }
    
    await setPlaylist(songs, shuffle: shuffle, initialIndex: initialIndex);
    await playMusic(songs[initialIndex]);
  }
  
  // 清理资源
  @override
  Future<void> dispose() async {
    // 优化销毁逻辑，使用try-catch避免异常阻塞
    try {
      // 停止所有计时器
      _positionTimer?.cancel();
      _positionTimer = null;
      
      // 释放播放器资源
      try {
        await _audioPlayer.dispose();
      } catch (e) {
        debugPrint('销毁播放器时出错: $e');
      }
    } catch (e) {
      debugPrint('清理资源时出错: $e');
    }
    
    _playbackState.close();
    _currentMusicSubject.close();
    
    // 清理图片缓存
    _imageCache.clear();
    _colorCache.clear();
    
    super.dispose();
  }
} 