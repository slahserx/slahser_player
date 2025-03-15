import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:slahser_player/services/settings_service.dart';

enum PlaybackState {
  none,
  loading,
  playing,
  paused,
  stopped,
  completed,
  error,
}

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
  
  // 当前播放列表
  List<MusicFile> _playlist = [];
  List<MusicFile> get playlist => _playlist;
  
  // 当前播放的音乐
  MusicFile? _currentMusic;
  MusicFile? get currentMusic => _currentMusic;
  
  // 是否正在切换歌曲（用于避免滑块动画）
  bool _isChangingTrack = false;
  bool get isChangingTrack => _isChangingTrack;
  
  // 当前播放状态
  PlaybackState _playbackState = PlaybackState.none;
  PlaybackState get playbackState => _playbackState;
  
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
  
  // 初始化方法
  Future<void> init() async {
    // 配置音频会话
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // 初始化音频播放器
    _audioPlayer.playbackEventStream.listen((event) {
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
  
  // 初始化
  Future<void> _init() async {
    try {
      // 初始化音频会话
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // 监听错误
      _audioPlayer.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace stackTrace) {
          debugPrint('音频播放错误: $e');
          // 如果是BufferingProgress错误，忽略它
          if (e.toString().contains('BufferingProgress')) {
            return;
          }
          // 否则更新状态为错误
          _playbackState = PlaybackState.error;
          notifyListeners();
        },
      );
      
      // 初始化播放模式
      await _updatePlaybackMode();
      
      // 初始化均衡器 (如果支持)
      _applyEqualizerSettings();
    } catch (e) {
      debugPrint('初始化音频播放器失败: $e');
    }
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
  Future<void> setPlaylist(List<MusicFile> playlist, {int initialIndex = 0, bool autoPlay = true, bool shuffle = false}) async {
    if (playlist.isEmpty) return;
    
    _originalPlaylist = List.from(playlist);
    
    if (_playbackMode == PlaybackMode.shuffle || shuffle) {
      _playlist = List.from(playlist)..shuffle();
      // 确保初始索引的歌曲在打乱后的列表中的位置
      if (initialIndex < playlist.length) {
        final initialMusic = playlist[initialIndex];
        _playlist.remove(initialMusic);
        _playlist.insert(0, initialMusic);
        initialIndex = 0;
      }
    } else {
      _playlist = List.from(playlist);
    }
    
    if (initialIndex < _playlist.length) {
      // 始终播放被选择的歌曲
      await playMusic(_playlist[initialIndex]);
    }
  }
  
  // 播放音乐
  Future<void> playMusic(MusicFile music) async {
    try {
      _playbackState = PlaybackState.loading;
      // 设置切换标志
      _isChangingTrack = true;
      notifyListeners();
      
      // 保存当前音量状态
      final savedVolume = _isMuted ? 0.0 : _volume;
      
      // 如果当前正在播放，先淡出
      if (_enableFadeEffect && _audioPlayer.playing) {
        await _fadeOut(_fadeOutDuration);
      }
      
      // 设置音频源
      await _audioPlayer.setFilePath(music.filePath);
      
      // 更新当前音乐
      _currentMusic = music;
      
      // 始终开始播放 - 强制播放状态
      await _audioPlayer.play();
      _playbackState = PlaybackState.playing; // 确保状态被正确设置
      
      // 淡入效果或直接恢复音量（使用内部方法，不通知UI）
      if (_enableFadeEffect) {
        await _internalFadeIn(_fadeInDuration, savedVolume);
      } else {
        await setVolume(savedVolume, notify: false);
      }
      
      // 重置切换标志并一次性通知所有变化
      _isChangingTrack = false;
      notifyListeners();
    } catch (e) {
      _playbackState = PlaybackState.error;
      _isChangingTrack = false; // 确保错误时也重置标志
      debugPrint('播放音乐失败: $e');
      notifyListeners();
    }
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
    if (_currentMusic == null) {
      // 如果没有当前音乐，尝试播放列表中的第一首
      if (_playlist.isNotEmpty) {
        await playMusic(_playlist[0]);
      }
      return;
    }
    
    if (_playbackState == PlaybackState.playing) {
      await pause();
    } else {
      await resume();
    }
  }
  
  // 暂停
  Future<void> pause() async {
    if (_playbackState == PlaybackState.playing) {
      await _audioPlayer.pause();
      _playbackState = PlaybackState.paused;
      notifyListeners();
    }
  }
  
  // 恢复播放
  Future<void> resume() async {
    if (_playbackState == PlaybackState.paused) {
      await _audioPlayer.play();
      _playbackState = PlaybackState.playing;
      notifyListeners();
    }
  }
  
  // 停止
  Future<void> stop() async {
    await _audioPlayer.stop();
    _position = Duration.zero;
    _playbackState = PlaybackState.stopped;
    notifyListeners();
  }
  
  // 下一曲
  Future<void> next() async {
    if (_playlist.isEmpty || _currentMusic == null) return;
    
    final currentIndex = _playlist.indexOf(_currentMusic!);
    if (currentIndex < 0) return;
    
    final nextIndex = (currentIndex + 1) % _playlist.length;
    await playMusic(_playlist[nextIndex]);
    
    // 确保新音乐始终处于播放状态
    if (_playbackState != PlaybackState.playing) {
      await resume();
    }
  }
  
  // 上一曲
  Future<void> previous() async {
    if (_playlist.isEmpty || _currentMusic == null) return;
    
    final currentIndex = _playlist.indexOf(_currentMusic!);
    if (currentIndex < 0) return;
    
    final previousIndex = (currentIndex - 1 + _playlist.length) % _playlist.length;
    await playMusic(_playlist[previousIndex]);
    
    // 确保新音乐始终处于播放状态
    if (_playbackState != PlaybackState.playing) {
      await resume();
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
    // 根据播放模式处理播放完成后的行为
    switch (_playbackMode) {
      case PlaybackMode.sequential:
        // 顺序播放模式下，播完最后一首后停止，否则继续播放下一首
        if (_currentMusic != null) {
          int currentIndex = _playlist.indexOf(_currentMusic!);
          if (currentIndex >= _playlist.length - 1) {
            _playbackState = PlaybackState.completed;
            notifyListeners();
          } else {
            // 播放下一首并确保播放状态
            next();
          }
        }
        break;
        
      case PlaybackMode.shuffle:
        // 随机播放模式下，总是自动播放下一首
        next();
        break;
        
      case PlaybackMode.repeatOne:
        // 单曲循环模式下，重新播放当前歌曲
        if (_currentMusic != null) {
          // 重新播放当前歌曲并确保播放状态
          await playMusic(_currentMusic!);
          if (_playbackState != PlaybackState.playing) {
            await resume();
          }
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
  
  @override
  void dispose() {
    _positionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
} 