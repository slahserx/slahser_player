import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/subsonic_models.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/providers/app_state.dart';
import 'package:slahser_player/enums/content_type.dart';
import 'package:slahser_player/widgets/content/notifications.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/playlist_service.dart';

/// 云音乐搜索结果视图
class CloudSearchView extends StatefulWidget {
  const CloudSearchView({Key? key}) : super(key: key);

  @override
  State<CloudSearchView> createState() => _CloudSearchViewState();
}

class _CloudSearchViewState extends State<CloudSearchView> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';
  SearchResult? _searchResult;
  
  // 标签控制器
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _performSearch();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _performSearch() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    // 检查搜索数据
    if (appState.cloudSearchData == null || appState.cloudSearchData!.query.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '没有搜索关键词';
      });
      return;
    }
    
    // 检查是否连接到服务器
    if (!subsonicService.isConnected) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未连接到云音乐服务器';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // 执行搜索
      final result = await subsonicService.search(appState.cloudSearchData!.query);
      
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('搜索失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '搜索失败: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    if (appState.cloudSearchData == null) {
      return const Center(child: Text('未找到搜索数据'));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和返回按钮
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  ContentTypeChangedNotification(ContentType.cloudMusic).dispatch(context);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '搜索: ${appState.cloudSearchData!.query}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 错误消息
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        
        // 加载指示器
        if (_isLoading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        
        // 搜索结果
        if (!_isLoading && _searchResult != null)
          Expanded(
            child: Column(
              children: [
                // 搜索结果标签页
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '歌曲'),
                    Tab(text: '专辑'),
                    Tab(text: '艺术家'),
                  ],
                ),
                
                // 标签页内容
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 歌曲结果
                      _buildSongsTab(),
                      
                      // 专辑结果
                      _buildAlbumsTab(),
                      
                      // 艺术家结果
                      _buildArtistsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildSongsTab() {
    if (_searchResult == null || _searchResult!.songs.isEmpty) {
      return const Center(child: Text('没有找到歌曲'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _searchResult!.songs.length,
      itemBuilder: (context, index) {
        final song = _searchResult!.songs[index];
        return _buildSongItem(song);
      },
    );
  }
  
  Widget _buildAlbumsTab() {
    if (_searchResult == null || _searchResult!.albums.isEmpty) {
      return const Center(child: Text('没有找到专辑'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResult!.albums.length,
      itemBuilder: (context, index) {
        final album = _searchResult!.albums[index];
        return _buildAlbumItem(album);
      },
    );
  }
  
  Widget _buildArtistsTab() {
    if (_searchResult == null || _searchResult!.artists.isEmpty) {
      return const Center(child: Text('没有找到艺术家'));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _searchResult!.artists.length,
      itemBuilder: (context, index) {
        final artist = _searchResult!.artists[index];
        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(artist.name),
          onTap: () => _navigateToArtist(artist.id, artist.name),
        );
      },
    );
  }
  
  Widget _buildSongItem(Song song) {
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
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: song.coverArt != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  subsonicService.getCoverArtUrl(song.coverArt!, size: 80),
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stackTrace) => const Icon(Icons.music_note),
                ),
              )
            : const Center(child: Icon(Icons.music_note)),
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
      onTap: () => _playSong(song),
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
        // 设置当前专辑数据并导航
        appState.setCloudAlbumData(album.id, album.name, album.artist);
        ContentTypeChangedNotification(ContentType.cloudAlbumDetail).dispatch(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 专辑封面
          Expanded(
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
    );
  }
  
  void _navigateToArtist(String artistId, String artistName) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setCloudArtist(artistId, artistName);
    ContentTypeChangedNotification(ContentType.cloudArtistDetail).dispatch(context);
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