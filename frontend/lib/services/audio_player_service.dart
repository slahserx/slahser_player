import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:audio_session/audio_session.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:rxdart/rxdart.dart';
import '../enums/playback_state.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:math'; // 添加导入math库以使用min函数
import 'package:slahser_player/utils/cache_manager.dart';

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
  
  // 当前在播放列表中的索引
  int _currentPlaylistIndex = -1;
  int get currentPlaylistIndex => _currentPlaylistIndex;
  
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
  
  // 是否正在播放
  bool get isPlaying => _playbackState.value == PlaybackState.playing;
  
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
  
  // 是否被音频中断（如电话）中断过
  bool _wasInterrupted = false;
  
  // 循环模式
  RepeatMode _loopMode = RepeatMode.off;
  RepeatMode get loopMode => _loopMode;
  
  // 播放模式
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  PlaybackMode get playbackMode => _playbackMode;
  
  // 是否随机播放
  bool get isShuffled => _playbackMode == PlaybackMode.shuffle;
  
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
  
  // 云音乐相关属性
  ConcatenatingAudioSource? _concatenatingSource;
  bool _usingConcatenatingSource = false;
  bool _enableCloudMusicPreBuffer = true; // 默认开启预缓冲
  int _preBufferCloudCount = 2; // 默认预缓冲2首
  
  // 云音乐预缓冲设置的getter
  bool get isPreBufferEnabled => _enableCloudMusicPreBuffer;
  int get preBufferCount => _preBufferCloudCount;
  
  // 已下载的云音乐缓存
  final Map<String, String> _cloudMusicCache = {};
  
  AudioPlayerService() {
    // 使用completer确保初始化串行执行
    _initializePlayer();
  }
  
  // 异步初始化播放器
  Future<void> _initializePlayer() async {
    try {
      // 初始化音频会话
      final session = await AudioSession.instance;
      
      // 确保在主线程上运行
      await WidgetsBinding.instance.endOfFrame;
      
      // 配置音频会话
      await session.configure(const AudioSessionConfiguration.music());
      
      // 设置播放器状态监听
      _audioPlayer.playerStateStream.listen((state) {
        // 使用WidgetsBinding确保在主线程上运行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('播放器状态变化: ${state.playing ? "播放中" : "已暂停"}, ${state.processingState}');
          // 当前是否有音乐加载
          final bool hasCurrent = _currentMusic != null;
          
          if (state.playing) {
            _safeSetPlaybackState(PlaybackState.playing);
            debugPrint('状态更新为: 播放中');
          } else {
            switch (state.processingState) {
              case ProcessingState.idle:
              case ProcessingState.completed:
                _safeSetPlaybackState(hasCurrent ? PlaybackState.completed : PlaybackState.stopped);
                debugPrint('状态更新为: ${hasCurrent ? "完成" : "停止"}');
                break;
              case ProcessingState.loading:
              case ProcessingState.buffering:
                _safeSetPlaybackState(PlaybackState.loading);
                debugPrint('状态更新为: 加载中');
                break;
              case ProcessingState.ready:
                if (hasCurrent) {
                  _safeSetPlaybackState(PlaybackState.paused);
                  debugPrint('状态更新为: 暂停');
                } else {
                  _safeSetPlaybackState(PlaybackState.stopped);
                  debugPrint('状态更新为: 停止（无当前音乐）');
                }
                break;
            }
          }
        });
      }, onError: (error, stackTrace) {
        // 忽略BufferingProgress错误
        if (error.toString().contains('BufferingProgress')) {
          debugPrint('忽略BufferingProgress错误: $error');
          return;
        } else {
          debugPrint('播放器错误: $error');
          // 对于其他类型的错误，传递
          Error.throwWithStackTrace(error, stackTrace);
        }
      });
      
      // 初始化
      await init();
    } catch (e) {
      debugPrint('播放器初始化失败: $e');
    }
  }
  
  // 初始化方法
  Future<void> init() async {
    try {
      // 移除不支持的AndroidAudioAttributes设置
      // 改为设置音频会话配置
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // 初始化音频播放器事件监听
      _audioPlayer.playbackEventStream.listen((event) {
        // 使用WidgetsBinding确保在主线程上运行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (event.processingState == ProcessingState.completed) {
            _handlePlaybackCompletion();
          }
        });
      }, onError: (error, stackTrace) {
        // 忽略BufferingProgress错误
        if (error.toString().contains('BufferingProgress')) {
          debugPrint('事件流忽略BufferingProgress错误: $error');
          return;
        } else {
          debugPrint('播放事件错误: $error');
          Error.throwWithStackTrace(error, stackTrace);
        }
      });
      
      // 添加音频位置监听器
      _audioPlayer.positionStream.listen((position) {
        // 使用WidgetsBinding确保在主线程上运行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _position = position;
          _safeNotifyListeners();
        });
      });
      
      // 添加音频时长监听器
      _audioPlayer.durationStream.listen((duration) {
        // 使用WidgetsBinding确保在主线程上运行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (duration != null) {
            _duration = duration;
            _safeNotifyListeners();
          }
        });
      });
      
      // 配置初始设置
      await _audioPlayer.setVolume(_volume);
      
      // 设置音频会话管理 - 响应电话/通知等中断
      await session.setActive(true);
      
      // 电话/通知中断处理
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          // 中断开始 - 暂停播放
          if (_playbackState.value == PlaybackState.playing) {
            _audioPlayer.pause();
            _wasInterrupted = true;
          }
        } else {
          // 中断结束 - 可以恢复
          if (_wasInterrupted && 
              event.type == AudioInterruptionType.pause &&
              _playbackState.value == PlaybackState.paused) {
            _audioPlayer.play();
            _wasInterrupted = false;
          }
        }
      });
    } catch (e) {
      debugPrint('初始化音频播放器失败: $e');
    }
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
  Future<void> setPlaylist(
    List<MusicFile> playlist, {
    int initialIndex = 0,
    bool autoPlay = false,
    bool shuffle = false,
  }) async {
    if (playlist.isEmpty) {
      debugPrint('无法设置空播放列表');
      return;
    }

    // 设置原始播放列表
    _originalPlaylist = List.from(playlist);
    
    // 设置当前播放列表（如果需要随机，则打乱顺序）
    if (shuffle) {
      // 保存当前播放的歌曲，确保它始终在第一个位置
      final MusicFile firstMusic = playlist[initialIndex];
      
      // 创建一个临时列表进行打乱
      final tempList = List<MusicFile>.from(playlist);
      tempList.removeAt(initialIndex);
      tempList.shuffle();
      
      // 将当前歌曲放在第一位
      tempList.insert(0, firstMusic);
      _playlist = tempList;
      _currentPlaylistIndex = 0; // 当前索引为0
    } else {
      _playlist = List.from(playlist);
      _currentPlaylistIndex = initialIndex; // 设置当前索引为传入的initialIndex
    }
    
    debugPrint('设置播放列表，${playlist.length}首歌曲，初始索引：$initialIndex');
    
    // 设置当前音乐
    if (_playlist.isNotEmpty && initialIndex < _playlist.length) {
      _currentMusic = _playlist[initialIndex];
      _currentMusicSubject.add(_currentMusic);
      
      if (autoPlay) {
        try {
          // 先停止当前播放
          await _audioPlayer.stop();
          
          // 播放新的音乐
          await playMusic(_currentMusic!);
        } catch (e) {
          debugPrint('设置播放列表并自动播放时出错: $e');
        }
      } else {
        // 只停止当前播放，不开始新的播放
        await _audioPlayer.stop();
      }
    } else {
      _currentMusic = null;
      _currentMusicSubject.add(null);
      await _audioPlayer.stop();
    }
    
    // 通知监听器
    notifyListeners();
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
  
  // 设置连续音频源，实现预缓冲
  Future<void> _setupConcatenatingSource(int initialIndex) async {
    _isChangingTrack = true;
    notifyListeners();
    
    try {
      // 创建一个新的连续音频源
      _concatenatingSource = ConcatenatingAudioSource(children: []);
      
      // 获取需要预加载的歌曲范围
      final preBufferStartIndex = initialIndex;
      final preBufferEndIndex = min(initialIndex + _preBufferCloudCount, _playlist.length - 1);
      
      // 首先添加当前播放的歌曲
      MusicFile currentMusic = _playlist[initialIndex];
      await _addMusicToSource(currentMusic, 0);
      
      // 添加后续需要预缓冲的歌曲
      for (int i = initialIndex + 1; i <= preBufferEndIndex; i++) {
        await _addMusicToSource(_playlist[i], i - initialIndex);
      }
      
      // 设置音频源
      await _audioPlayer.setAudioSource(_concatenatingSource!);
      
      // 设置相关状态
      _usingConcatenatingSource = true;
      _isChangingTrack = false;
      
      // 更新状态
      _safeSetPlaybackState(PlaybackState.paused);
      notifyListeners();
      
      debugPrint('预缓冲设置完成，初始索引：$initialIndex, 预缓冲数量：${preBufferEndIndex - initialIndex + 1}');
    } catch (e) {
      debugPrint('设置连续音频源失败: $e');
      _usingConcatenatingSource = false;
      _isChangingTrack = false;
      notifyListeners();
    }
  }
  
  // 将音乐添加到连续音频源
  Future<void> _addMusicToSource(MusicFile music, int index) async {
    if (_concatenatingSource == null) return;
    
    try {
      // 构建音频源
      AudioSource audioSource;
      Uri audioUri;
      
      if (music.isRemote == true) {
        // 检查是否有缓存
        if (_cloudMusicCache.containsKey(music.id)) {
          audioUri = Uri.file(_cloudMusicCache[music.id]!);
          debugPrint('使用缓存的云音乐: ${music.title}, 缓存路径: ${_cloudMusicCache[music.id]}');
        } else {
          audioUri = Uri.parse(music.filePath);
        }
      } else {
        audioUri = Uri.file(music.filePath);
      }
      
      audioSource = AudioSource.uri(audioUri);
      
      // 插入到音频源
      if (index < _concatenatingSource!.length) {
        await _concatenatingSource!.insert(index, audioSource);
      } else {
        await _concatenatingSource!.add(audioSource);
      }
      
      debugPrint('已添加歌曲到连续源: ${music.title}');
    } catch (e) {
      debugPrint('添加歌曲到连续源失败: ${music.title}, 错误: $e');
    }
  }
  
  // 播放音乐
  Future<void> playMusic(MusicFile music) async {
    try {
      _isChangingTrack = true;
      notifyListeners();
      
      // 获取歌曲在播放列表中的索引
      final musicIndex = _playlist.indexOf(music);
      if (musicIndex == -1) {
        // 如果歌曲不在当前播放列表中，则自动添加到播放列表
        debugPrint('歌曲不在当前播放列表中，自动添加: ${music.title}');
        _playlist = [music]; // 创建只包含当前歌曲的新播放列表
        _currentPlaylistIndex = 0; // 重置当前播放索引
        _currentMusic = music;
        _currentMusicSubject.add(music);
      } else {
        // 更新当前播放列表索引
        _currentPlaylistIndex = musicIndex;
      }
      
      // 检查是否需要使用连续音频源（针对云音乐）
      bool hasCloudMusic = _playlist.any((music) => music.isRemote == true);
      
      if (hasCloudMusic && _enableCloudMusicPreBuffer && !_usingConcatenatingSource) {
        // 如果还没有设置连续音频源，现在设置
        await _setupConcatenatingSource(musicIndex);
        await _audioPlayer.play();
        return;
      } else if (_usingConcatenatingSource) {
        // 如果已经在使用连续音频源，检查该歌曲是否已在源中
        final sourceIndex = _playlist.sublist(0, musicIndex + 1).where((m) => m.isRemote == true).length - 1;
        
        if (sourceIndex >= 0 && sourceIndex < _concatenatingSource!.length) {
          // 歌曲在源中，直接跳转
          debugPrint('使用连续源播放: ${music.title}, 源索引: $sourceIndex');
          await _audioPlayer.seek(Duration.zero, index: sourceIndex);
          
          // 预缓冲后续歌曲
          final nextIndex = musicIndex + 1;
          if (nextIndex < _playlist.length) {
            final nextMusicCount = min(_preBufferCloudCount, _playlist.length - nextIndex);
            
            for (int i = 0; i < nextMusicCount; i++) {
              if (nextIndex + i < _playlist.length) {
                final nextSourceIndex = _concatenatingSource!.length;
                await _addMusicToSource(_playlist[nextIndex + i], nextSourceIndex);
              }
            }
          }
          
          // 设置状态
          _currentMusic = music;
          _currentMusicSubject.add(music);
          
          // 预加载图片和颜色
          _preloadImageAndExtractColors(music);
          
          // 播放
          await _audioPlayer.play();
          
          _isChangingTrack = false;
          _safeSetPlaybackState(PlaybackState.playing);
          _safeNotifyListeners();
          return;
        } else {
          // 歌曲不在源中，需要重新设置源
          await _audioPlayer.stop();
          _usingConcatenatingSource = false;
        }
      }
      
      // 以下是原来的播放逻辑（针对非预缓冲情况）
      
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
      
      // 区分网络URL和本地文件路径
      Uri audioUri;
      final bool isNetwork = music.isRemote == true || music.filePath.startsWith('http://') || music.filePath.startsWith('https://');
      
      if (isNetwork) {
        // 检查是否有缓存
        if (_cloudMusicCache.containsKey(music.id)) {
          audioUri = Uri.file(_cloudMusicCache[music.id]!);
          debugPrint('使用缓存的云音乐: ${music.title}, 缓存路径: ${_cloudMusicCache[music.id]}');
        } else {
          // 处理网络URL
          audioUri = Uri.parse(music.filePath);
        }
      } else {
        // 处理本地文件路径
        audioUri = Uri.file(music.filePath);
      }
      
      try {
        // 使用基本的setAudioSource方法，无需高级配置参数
        await _audioPlayer.setAudioSource(
          AudioSource.uri(audioUri),
          preload: true,
        ).timeout(
          const Duration(seconds: 30), 
          onTimeout: () {
            debugPrint('设置音频源超时，尝试使用替代方法');
            throw TimeoutException('设置音频源超时');
          }
        );
        debugPrint('音频源设置成功');
      } catch (e) {
        debugPrint('设置音频源失败: $e');
        // 尝试再次设置
        try {
          // 对于网络URL，直接使用setUrl；对于本地文件，确保路径格式正确
          if (isNetwork) {
            await _audioPlayer.setUrl(
              music.filePath,
              preload: true,
            ).timeout(const Duration(seconds: 20));
          } else {
            // 确保本地文件路径格式正确
            final file = File(music.filePath);
            if (await file.exists()) {
              await _audioPlayer.setUrl(file.path, preload: true);
            } else {
              throw Exception('文件不存在: ${music.filePath}');
            }
          }
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
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          debugPrint('尝试播放: ${music.title}, ID: ${music.id}');
          await _audioPlayer.play().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('播放超时，尝试重试');
              throw TimeoutException('播放超时');
            },
          );
          
          // 成功播放后，明确设置为播放状态
          debugPrint('开始播放: ${music.title}, ID: ${music.id}');
          _safeSetPlaybackState(PlaybackState.playing);
          _isChangingTrack = false;
          _safeNotifyListeners();
          return; // 成功播放，退出函数
        } catch (e) {
          if (e.toString().contains('BufferingProgress')) {
            debugPrint('忽略播放时的BufferingProgress错误');
            _safeSetPlaybackState(PlaybackState.playing);
            _isChangingTrack = false;
            _safeNotifyListeners();
            return; // 这不是真正的错误，可以退出
          } else {
            retryCount++;
            debugPrint('播放失败 (尝试 $retryCount/$maxRetries): $e');
            if (retryCount >= maxRetries) {
              debugPrint('重试次数达到上限，放弃播放');
              _safeSetPlaybackState(PlaybackState.error);
              _isChangingTrack = false;
              _safeNotifyListeners();
              rethrow;
            }
            // 短暂延迟后重试
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
      }
    } catch (e) {
      debugPrint('播放音乐失败: $e');
      _safeSetPlaybackState(PlaybackState.error);
      _isChangingTrack = false;
      _safeNotifyListeners();
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
      
      // 如果使用连续音频源，且当前不是最后一首，直接跳到下一首
      if (_usingConcatenatingSource && _audioPlayer.currentIndex != null &&
          _audioPlayer.currentIndex! < _concatenatingSource!.length - 1) {
        await _audioPlayer.seekToNext();
        
        // 当前音乐更新
        _currentMusic = nextMusic;
        _currentMusicSubject.add(nextMusic);
        
        // 预加载下一首歌曲的图片和颜色
        _preloadImageAndExtractColors(nextMusic);
        
        // 预缓冲更多歌曲
        if (nextIndex + _preBufferCloudCount < _playlist.length) {
          await _addMusicToSource(_playlist[nextIndex + _preBufferCloudCount], _concatenatingSource!.length);
        }
        
        _safeSetPlaybackState(PlaybackState.playing);
        _safeNotifyListeners();
        return;
      }
      
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
  
  // 切换播放模式
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
            _safeSetPlaybackState(PlaybackState.completed);
            _safeNotifyListeners();
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
  
  // 处理频繁缓冲问题
  Future<void> handleFrequentBuffering() async {
    if (_currentMusic == null) return;
    
    // 是否为网络流
    final bool isNetwork = _currentMusic!.filePath.startsWith('http://') || 
                           _currentMusic!.filePath.startsWith('https://');
    
    if (isNetwork) {
      debugPrint('检测到频繁缓冲，尝试降低音质或清除缓存');
      
      // 1. 尝试清除缓存
      try {
        await _audioPlayer.clearCache();
      } catch (e) {
        debugPrint('清除缓存失败: $e');
      }
      
      // 2. 停止当前播放
      await _audioPlayer.stop();
      
      // 3. 重新播放当前歌曲
      await playMusic(_currentMusic!);
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

  // 通用方法：确保在主线程上通知变更
  void _safeNotifyListeners() {
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  // 通用方法：确保在主线程上添加流数据
  void _safeAddToStream<T>(BehaviorSubject<T> stream, T value) {
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!stream.isClosed) {
          stream.add(value);
        }
      });
    } else {
      if (!stream.isClosed) {
        stream.add(value);
      }
    }
  }
  
  // 通用方法：安全地设置状态
  void _safeSetPlaybackState(PlaybackState state) {
    _safeAddToStream(_playbackState, state);
  }

  // 设置是否启用云音乐预缓冲
  void setCloudMusicPreBuffer(bool enable) {
    _enableCloudMusicPreBuffer = enable;
    notifyListeners();
  }
  
  // 设置预缓冲歌曲数量
  void setPreBufferCount(int count) {
    if (count >= 1 && count <= 5) {
      _preBufferCloudCount = count;
    }
    notifyListeners();
  }

  // 下载云音乐到本地缓存
  Future<String?> downloadCloudMusic(MusicFile music) async {
    if (music.isRemote != true) {
      return null;
    }
    
    try {
      // 获取下载目录
      String downloadPath = '';
      
      // 检查设置服务中是否有自定义下载路径
      if (_settingsService != null && 
          _settingsService!.getCloudMusicDownloadPath().isNotEmpty) {
        downloadPath = _settingsService!.getCloudMusicDownloadPath();
        // 确保目录存在
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        // 使用统一的缓存目录
        final cachePath = MusicCacheManager().getCloudMusicCachePath();
        if (cachePath != null) {
          downloadPath = cachePath;
        } else {
          // 如果缓存管理器未初始化，先初始化
          await MusicCacheManager().initialize();
          downloadPath = MusicCacheManager().getCloudMusicCachePath()!;
        }
      }
      
      // 确保缓存目录存在
      final cacheDir = Directory(downloadPath);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      // 获取文件扩展名
      String fileExtension = music.fileExtension.isNotEmpty ? music.fileExtension : 'mp3';
      
      // 清理文件名，移除不允许的字符
      String sanitizedTitle = music.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      String sanitizedArtist = music.artist.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // 生成缓存文件名：歌曲名-歌手.mp3
      final fileName = '${sanitizedTitle}-${sanitizedArtist}.$fileExtension';
      final filePath = '${cacheDir.path}/$fileName';
      
      // 检查是否已存在缓存 (使用音乐ID作为键)
      if (_cloudMusicCache.containsKey(music.id)) {
        return _cloudMusicCache[music.id];
      }
      
      // 检查文件是否已存在
      final file = File(filePath);
      if (await file.exists()) {
        _cloudMusicCache[music.id] = filePath;
        return filePath;
      }
      
      // 下载文件
      debugPrint('开始下载云音乐: ${music.title}, URL: ${music.filePath}');
      final response = await http.get(Uri.parse(music.filePath));
      
      if (response.statusCode == 200) {
        // 写入文件
        await file.writeAsBytes(response.bodyBytes);
        
        // 添加到缓存
        _cloudMusicCache[music.id] = filePath;
        
        debugPrint('云音乐下载完成: ${music.title}, 保存到: $filePath');
        return filePath;
      } else {
        throw Exception('下载失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('下载云音乐失败: $e');
      return null;
    }
  }
  
  // 检查云音乐是否已缓存
  bool isCloudMusicCached(String? musicId) {
    if (musicId == null) return false;
    return _cloudMusicCache.containsKey(musicId);
  }

  // 获取音乐文件的本地路径
  String? getMusicFilePath(MusicFile music) {
    // 如果是本地文件，直接返回路径
    if (music.isRemote != true) {
      return music.filePath;
    }
    
    // 如果是云音乐且已缓存，返回缓存路径
    if (_cloudMusicCache.containsKey(music.id)) {
      return _cloudMusicCache[music.id];
    }
    
    // 未找到本地路径
    return null;
  }
  
  // 打开文件所在位置
  Future<bool> openFileLocation(MusicFile music) async {
    String? filePath = getMusicFilePath(music);
    
    if (filePath == null) {
      debugPrint('找不到文件路径');
      return false;
    }
    
    try {
      debugPrint('准备打开文件所在位置: $filePath');
      
      // 在Windows上使用explorer
      if (Platform.isWindows) {
        // 修复Windows资源管理器命令
        // 需要确保文件路径有效，且参数格式正确
        filePath = filePath.replaceAll('/', '\\'); // 确保使用Windows路径格式
        
        // 首先检查文件是否存在
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('文件不存在: $filePath');
          
          // 如果文件不存在，则尝试打开目录
          final directory = Directory(filePath.substring(0, filePath.lastIndexOf('\\')));
          if (await directory.exists()) {
            await Process.run('explorer.exe', [directory.path]);
            debugPrint('打开目录: ${directory.path}');
            return true;
          }
          return false;
        }
        
        // 两种方式尝试打开文件位置
        try {
          // 修正方法1: 正确格式为 /select,文件路径（不带额外引号）
          final result = await Process.run('explorer.exe', ['/select,$filePath']);
          debugPrint('使用/select参数打开结果: ${result.exitCode}');
          
          if (result.exitCode != 0) {
            // 如果方法1失败，直接打开目录
            final directory = filePath.substring(0, filePath.lastIndexOf('\\'));
            await Process.run('explorer.exe', [directory]);
            debugPrint('打开目录: $directory');
          }
        } catch (e) {
          debugPrint('方法1失败: $e，尝试打开目录');
          // 方法2: 打开文件所在目录
          final directory = filePath.substring(0, filePath.lastIndexOf('\\'));
          await Process.run('explorer.exe', [directory]);
          debugPrint('打开目录: $directory');
        }
        
        return true;
      } 
      // 在macOS上使用Finder
      else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
        return true;
      } 
      // 在Linux上使用默认文件管理器
      else if (Platform.isLinux) {
        final dir = filePath.substring(0, filePath.lastIndexOf('/'));
        await Process.run('xdg-open', [dir]);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('打开文件位置失败: $e');
      return false;
    }
  }

  // 清除云音乐缓存
  void clearCloudMusicCache() {
    _cloudMusicCache.clear();
    
    // 使用缓存管理器清除文件系统中的缓存
    MusicCacheManager().clearCloudMusicCache();
    
    notifyListeners();
  }
}

// ============================
// 平台特定功能的扩展方法
// ============================

// Android扩展方法 - 可能不受某些平台支持
extension AndroidAudioPlayerExtension on AudioPlayer {
  // 尝试设置Android类别，如果不支持则忽略
  Future<void> androidSetCategory(AndroidCategory category) async {
    try {
      // 这些功能可能在平台特定代码中实现，这里只是存根
      debugPrint('尝试设置Android类别: $category');
    } catch (e) {
      debugPrint('设置Android类别失败: $e');
    }
  }
  
  // 清除播放器缓存
  Future<void> clearCache() async {
    try {
      // 这是一个存根方法，实际实现需要平台特定代码
      debugPrint('尝试清除播放器缓存');
    } catch (e) {
      debugPrint('清除播放器缓存失败: $e');
    }
  }
}

// Android音频类别
enum AndroidCategory {
  alarm,
  media,
  playback,
  notification,
} 