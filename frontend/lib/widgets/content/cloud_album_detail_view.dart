import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/subsonic_models.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/enums/content_type.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/enums/playback_state.dart';

class CloudAlbumDetailView extends StatefulWidget {
  final String albumId;
  final String albumName;
  final String artist;

  const CloudAlbumDetailView({
    Key? key,
    required this.albumId,
    required this.albumName,
    required this.artist,
  }) : super(key: key);

  @override
  State<CloudAlbumDetailView> createState() => _CloudAlbumDetailViewState();
}

class _CloudAlbumDetailViewState extends State<CloudAlbumDetailView> {
  bool _isLoading = true;
  Album? _album;
  List<Song> _songs = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  Future<void> _loadAlbumDetails() async {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    if (!subsonicService.isConnected) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未连接到云音乐服务器';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 获取专辑详情
      final albumData = await subsonicService.getAlbum(widget.albumId);
      
      setState(() {
        _album = albumData;
        _songs = albumData.songs ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载专辑详情失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '无法加载专辑详情: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAlbumDetails,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (_album == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.album_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未找到专辑', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
    }
    
    return _buildAlbumDetailView();
  }
  
  Widget _buildAlbumDetailView() {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = _album!.coverArt != null 
        ? subsonicService.getCoverArtUrl(_album!.coverArt!, size: 300)
        : null;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 返回按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回云音乐'),
              onPressed: () {
                // 通知切换回云音乐主页面
                ContentTypeChangedNotification(ContentType.cloudMusic).dispatch(context);
              },
            ),
          ),
          
          // 专辑信息头部
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 专辑封面
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.album, size: 80, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.album, size: 80, color: Colors.grey),
                      ),
              ),
              
              const SizedBox(width: 24),
              
              // 专辑信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _album!.name,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _album!.artist,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_album!.year != null) Text('发行年份: ${_album!.year}'),
                    Text('${_songs.length} 首歌曲'),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('播放全部'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => _playAlbum(0),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle),
                          label: const Text('随机播放'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => _playAlbum(0, shuffle: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 歌曲列表
          _buildSongsList(),
        ],
      ),
    );
  }
  
  Widget _buildSongsList() {
    if (_songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('此专辑没有歌曲'),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 表头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text('#', style: Theme.of(context).textTheme.labelLarge)),
                Expanded(flex: 3, child: Text('标题', style: Theme.of(context).textTheme.labelLarge)),
                Expanded(flex: 2, child: Text('艺术家', style: Theme.of(context).textTheme.labelLarge)),
                SizedBox(width: 80, child: Text('时长', style: Theme.of(context).textTheme.labelLarge)),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // 歌曲列表
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index];
              return _buildSongItem(song, index);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSongItem(Song song, int index) {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // 转换为MusicFile对象
    final streamUrl = subsonicService.getStreamUrl(song.id);
    final coverUrl = song.coverArt != null 
        ? subsonicService.getCoverArtUrl(song.coverArt!)
        : null;
    final musicFile = song.toMusicFile(streamUrl, coverUrl ?? '');
    
    // 检查歌曲是否已缓存
    final bool isCached = audioPlayerService.isCloudMusicCached(musicFile.id);
    
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showSongContextMenu(context, song, RelativeRect.fromLTRB(
          details.globalPosition.dx,
          details.globalPosition.dy,
          details.globalPosition.dx,
          details.globalPosition.dy,
        ));
      },
      child: ListTile(
        leading: Text(
          '${index + 1}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        title: Text(song.title),
        subtitle: Text(song.artist),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCached)
              Icon(
                Icons.offline_pin,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text(
                _formatDuration(Duration(seconds: song.duration)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        onTap: () => _playSong(song),
      ),
    );
  }
  
  void _showSongContextMenu(BuildContext context, Song song, RelativeRect position) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    
    // 转换为MusicFile以便稍后使用
    final streamUrl = subsonicService.getStreamUrl(song.id);
    final coverUrl = song.coverArt != null 
        ? subsonicService.getCoverArtUrl(song.coverArt!)
        : null;
    final musicFile = song.toMusicFile(streamUrl, coverUrl ?? '');
    
    // 检查歌曲是否已缓存
    final bool isCached = audioPlayerService.isCloudMusicCached(musicFile.id);
    
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'play',
          child: Row(
            children: const [
              Icon(Icons.play_arrow),
              SizedBox(width: 8),
              Text('播放'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_queue',
          child: Row(
            children: const [
              Icon(Icons.queue_music),
              SizedBox(width: 8),
              Text('添加到播放队列'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Row(
            children: const [
              Icon(Icons.playlist_add),
              SizedBox(width: 8),
              Text('添加到歌单'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'download',
          enabled: !isCached, // 如果已缓存则禁用
          child: Row(
            children: [
              Icon(
                isCached ? Icons.offline_pin : Icons.download,
                color: isCached ? Theme.of(context).disabledColor : null,
              ),
              const SizedBox(width: 8),
              Text(
                isCached ? '已下载' : '下载',
                style: isCached 
                  ? TextStyle(color: Theme.of(context).disabledColor)
                  : null,
              ),
            ],
          ),
        ),
        if (isCached)
          PopupMenuItem<String>(
            value: 'open_location',
            child: Row(
              children: const [
                Icon(Icons.folder_open),
                SizedBox(width: 8),
                Text('打开文件所在位置'),
              ],
            ),
          ),
      ],
    ).then((value) async {
      if (value == null) return;
      
      switch (value) {
        case 'play':
          _playSong(song);
          break;
        case 'add_to_queue':
          // 将歌曲添加到当前播放队列
          if (audioPlayerService.currentMusic != null) {
            final currentPlaylist = List<MusicFile>.from(audioPlayerService.playlist);
            currentPlaylist.add(musicFile);
            audioPlayerService.setPlaylist(
              currentPlaylist,
              initialIndex: audioPlayerService.playlist.indexOf(audioPlayerService.currentMusic!),
              autoPlay: audioPlayerService.isPlaying,
            );
            
            // 显示提示
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已添加到播放队列: ${song.title}'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            // 如果当前没有播放，则直接播放
            _playSong(song);
          }
          break;
        case 'add_to_playlist':
          _showAddToPlaylistDialog(context, musicFile);
          break;
        case 'download':
          if (!isCached) {
            _downloadSong(song, musicFile);
          }
          break;
        case 'open_location':
          _openFileLocation(song, musicFile);
          break;
      }
    });
  }
  
  Future<void> _downloadSong(Song song, MusicFile musicFile) async {
    // 显示下载中提示
    final snackBar = SnackBar(
      content: Text('正在下载: ${song.title}'),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // 执行下载
    final filePath = await audioPlayerService.downloadCloudMusic(musicFile);
    
    if (filePath != null) {
      // 显示下载成功提示
      final successSnackBar = SnackBar(
        content: Text('${song.title} 下载成功'),
        duration: const Duration(seconds: 2),
      );
      
      // 使用build context安全的方式
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(successSnackBar);
        // 触发UI刷新
        setState(() {});
      }
    } else {
      // 显示下载失败提示
      final failedSnackBar = SnackBar(
        content: Text('${song.title} 下载失败'),
        duration: const Duration(seconds: 2),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(failedSnackBar);
      }
    }
  }
  
  void _showAddToPlaylistDialog(BuildContext context, MusicFile music) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final playlists = playlistService.playlists;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加到歌单'),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: playlist.description.isNotEmpty
                      ? Text(
                          playlist.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () {
                    playlistService.addSongToPlaylist(playlist.id, music);
                    Navigator.of(context).pop();
                    
                    // 显示添加成功提示
                    final snackBar = SnackBar(
                      content: Text('已添加到歌单: ${playlist.name}'),
                      duration: const Duration(seconds: 2),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
  
  void _playAlbum(int startIndex, {bool shuffle = false}) {
    if (_songs.isEmpty) return;
    
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // 转换所有歌曲为MusicFile对象
    final musicFiles = _songs.map((song) {
      final streamUrl = subsonicService.getStreamUrl(song.id);
      final coverUrl = song.coverArt != null 
          ? subsonicService.getCoverArtUrl(song.coverArt!)
          : null;
      
      return song.toMusicFile(streamUrl, coverUrl ?? '');
    }).toList();
    
    // 播放整个专辑
    audioPlayerService.setPlaylist(
      musicFiles,
      initialIndex: startIndex,
      shuffle: shuffle,
      autoPlay: true,
    );
  }
  
  void _playSong(Song song) {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // 获取流媒体URL和封面URL
    final streamUrl = subsonicService.getStreamUrl(song.id);
    final coverUrl = song.coverArt != null 
        ? subsonicService.getCoverArtUrl(song.coverArt!)
        : null;
    
    // 转换为MusicFile对象并播放
    final musicFile = song.toMusicFile(streamUrl, coverUrl ?? '');
    
    // 获取当前歌曲在列表中的索引
    final index = _songs.indexWhere((s) => s.id == song.id);
    if (index != -1) {
      // 创建播放列表并从当前歌曲开始播放
      _playAlbum(index);
    } else {
      // 单独播放这首歌
      final playlist = [musicFile];
      audioPlayerService.setPlaylist(
        playlist,
        initialIndex: 0,
        autoPlay: true
      );
    }
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  // 打开文件所在位置
  Future<void> _openFileLocation(Song song, MusicFile musicFile) async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    final success = await audioPlayerService.openFileLocation(musicFile);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开文件所在位置'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
} 