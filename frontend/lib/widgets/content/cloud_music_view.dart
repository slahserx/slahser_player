import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/subsonic_models.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/enums/content_type.dart';
import 'package:slahser_player/providers/app_state.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/playlist_service.dart';

/// 云音乐主视图，显示最新、热门、随机推荐等内容
class CloudMusicView extends StatefulWidget {
  const CloudMusicView({Key? key}) : super(key: key);

  @override
  State<CloudMusicView> createState() => _CloudMusicViewState();
}

class _CloudMusicViewState extends State<CloudMusicView> {
  bool _isLoading = false;
  List<Album> _recentAlbums = [];
  List<Album> _randomAlbums = [];
  List<Song> _randomSongs = [];
  List<Album> _frequentAlbums = [];
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    if (!subsonicService.isConnected) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 并行加载数据
      final results = await Future.wait([
        subsonicService.getAlbumList(type: 'newest', size: 10),
        subsonicService.getAlbumList(type: 'random', size: 10),
        subsonicService.getRandomSongs(size: 20),
        subsonicService.getAlbumList(type: 'frequent', size: 10),
      ]);
      
      setState(() {
        _recentAlbums = results[0] as List<Album>;
        _randomAlbums = results[1] as List<Album>;
        _randomSongs = results[2] as List<Song>;
        _frequentAlbums = results[3] as List<Album>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载云音乐数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      return;
    }
    
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!subsonicService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未连接到云音乐服务器'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 设置搜索数据
    appState.setCloudSearchData(query);
    
    // 导航到搜索结果页面
    ContentTypeChangedNotification(ContentType.cloudSearchResult).dispatch(context);
  }
  
  @override
  Widget build(BuildContext context) {
    final subsonicService = Provider.of<SubsonicService>(context);
    
    if (!subsonicService.isConnected) {
      return _buildNotConnectedView();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和搜索栏
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Subsonic',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索歌曲、专辑、艺术家',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
            ],
          ),
        ),
        
        // 主内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(),
        ),
      ],
    );
  }
  
  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            '未连接到 Subsonic 服务器',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '请在设置中配置云音乐服务器信息',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('前往设置'),
            onPressed: () {
              // 发送通知，切换到设置页面的云音乐设置标签
              ContentTypeChangedNotification(ContentType.settings).dispatch(context);
              // TODO: 在实际应用中还需添加一个通知来选择特定的设置标签页，暂时使用这个简化方案
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('最新添加'),
          _buildAlbumGrid(_recentAlbums),
          
          const SizedBox(height: 24),
          _buildSectionTitle('随机推荐'),
          _buildAlbumGrid(_randomAlbums),
          
          const SizedBox(height: 24),
          _buildSectionTitle('随机歌曲'),
          _buildSongsList(_randomSongs),
          
          const SizedBox(height: 24),
          _buildSectionTitle('常听专辑'),
          _buildAlbumGrid(_frequentAlbums),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (title != '随机歌曲') // 对于专辑类别添加"查看全部"按钮
            TextButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('查看全部'),
              onPressed: () {
                _navigateToAllAlbums(title);
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildAlbumGrid(List<Album> albums) {
    if (albums.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据'),
        ),
      );
    }
    
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return _buildAlbumItem(album);
        },
      ),
    );
  }
  
  Widget _buildAlbumItem(Album album) {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);
    
    final coverUrl = album.coverArt != null 
        ? subsonicService.getCoverArtUrl(album.coverArt!, size: 300)
        : null;
    
    return GestureDetector(
      onTap: () {
        // 设置当前专辑数据
        appState.setCloudAlbumData(album.id, album.name, album.artist);
        
        // 通知上下文切换到专辑详情页面
        ContentTypeChangedNotification(ContentType.cloudAlbumDetail).dispatch(context);
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 专辑封面
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                          child: const Icon(Icons.album, size: 50, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.album, size: 50, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // 专辑名称
            Text(
              album.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // 艺术家名称
            Text(
              album.artist,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('暂无数据'),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _buildSongItem(song, index);
        },
      ),
    );
  }
  
  Widget _buildSongItem(Song song, int index) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    // 检查歌曲是否已缓存
    final musicFile = song.toMusicFile(
      subsonicService.getStreamUrl(song.id),
      song.coverArt != null ? subsonicService.getCoverArtUrl(song.coverArt!) : ''
    );
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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${song.artist} · ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            Text(
              _formatDuration(Duration(seconds: song.duration)),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: () {
          // 播放歌曲
          _playSong(song);
        },
      ),
    );
  }
  
  // 显示歌曲右键菜单
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
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'view_artist',
          child: Row(
            children: const [
              Icon(Icons.person),
              SizedBox(width: 8),
              Text('查看艺术家'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'view_album',
          child: Row(
            children: const [
              Icon(Icons.album),
              SizedBox(width: 8),
              Text('查看专辑'),
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
        case 'view_artist':
          if (song.artistId != null) {
            _navigateToArtist(song.artistId!, song.artist);
          }
          break;
        case 'view_album':
          if (song.albumId != null) {
            _navigateToAlbum(song.albumId!, song.album, song.artist);
          }
          break;
      }
    });
  }
  
  // 下载歌曲
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
  
  // 打开文件所在位置
  Future<void> _openFileLocation(Song song, MusicFile musicFile) async {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    final success = await audioPlayerService.openFileLocation(musicFile);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('无法打开文件所在位置'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  // 显示添加到歌单对话框
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
  
  // 导航到艺术家详情页
  void _navigateToArtist(String artistId, String artistName) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setCloudArtist(artistId, artistName);
  }
  
  // 导航到专辑详情页
  void _navigateToAlbum(String albumId, String albumName, String artist) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setCloudAlbum(albumId, albumName, artist);
  }
  
  // 导航到全部专辑页面
  void _navigateToAllAlbums(String category) {
    final appState = Provider.of<AppState>(context, listen: false);
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    // 根据不同的类别设置获取方式
    String albumListType = 'newest';
    if (category == '随机推荐') {
      albumListType = 'random';
    } else if (category == '常听专辑') {
      albumListType = 'frequent';
    }
    
    // 导航到专辑列表页面
    appState.setCloudAlbumList(albumListType, category);
    ContentTypeChangedNotification(ContentType.cloudAlbumList).dispatch(context);
  }
  
  void _playSong(Song song) {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    
    // 获取流媒体URL和封面URL
    final streamUrl = subsonicService.getStreamUrl(song.id);
    final coverUrl = song.coverArt != null 
        ? subsonicService.getCoverArtUrl(song.coverArt!)
        : null;
    
    // 转换为MusicFile对象
    final musicFile = song.toMusicFile(streamUrl, coverUrl ?? '');
    
    // 创建一个只包含当前歌曲的播放列表
    final playlist = [musicFile];
    
    // 先设置播放列表，然后播放
    audioPlayerService.setPlaylist(
      playlist,
      initialIndex: 0,
      autoPlay: true
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
} 