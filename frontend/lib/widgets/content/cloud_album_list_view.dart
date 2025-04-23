import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/subsonic_models.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/providers/app_state.dart';
import 'package:slahser_player/enums/content_type.dart';
import 'package:slahser_player/widgets/content/notifications.dart';

/// 云音乐专辑列表视图，用于显示所有专辑
class CloudAlbumListView extends StatefulWidget {
  const CloudAlbumListView({Key? key}) : super(key: key);

  @override
  State<CloudAlbumListView> createState() => _CloudAlbumListViewState();
}

class _CloudAlbumListViewState extends State<CloudAlbumListView> {
  bool _isLoading = true;
  List<Album> _albums = [];
  String _errorMessage = '';
  int _page = 0;
  static const int _pageSize = 50;
  bool _hasMoreAlbums = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500 && !_isLoading && _hasMoreAlbums) {
      _loadMoreAlbums();
    }
  }

  Future<void> _loadAlbums() async {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!subsonicService.isConnected || appState.cloudAlbumListData == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '未连接到云音乐服务器或缺少专辑列表数据';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _page = 0;
    });
    
    try {
      // 获取专辑列表
      final albums = await subsonicService.getAlbumList(
        type: appState.cloudAlbumListData!.type,
        size: _pageSize,
        offset: _page * _pageSize,
      );
      
      setState(() {
        _albums = albums;
        _isLoading = false;
        _hasMoreAlbums = albums.length == _pageSize;
        _page++;
      });
    } catch (e) {
      debugPrint('加载专辑列表失败: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '无法加载专辑列表: ${e.toString()}';
      });
    }
  }
  
  Future<void> _loadMoreAlbums() async {
    if (_isLoading || !_hasMoreAlbums) return;
    
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 获取更多专辑
      final moreAlbums = await subsonicService.getAlbumList(
        type: appState.cloudAlbumListData!.type,
        size: _pageSize,
        offset: _page * _pageSize,
      );
      
      setState(() {
        _albums.addAll(moreAlbums);
        _isLoading = false;
        _hasMoreAlbums = moreAlbums.length == _pageSize;
        _page++;
      });
    } catch (e) {
      debugPrint('加载更多专辑失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    if (appState.cloudAlbumListData == null) {
      return const Center(child: Text('未找到专辑列表数据'));
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
                  appState.cloudAlbumListData!.title,
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
        
        // 专辑网格
        Expanded(
          child: _isLoading && _albums.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildAlbumsGrid(),
        ),
      ],
    );
  }
  
  Widget _buildAlbumsGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _albums.length + (_hasMoreAlbums ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _albums.length) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return _buildAlbumItem(_albums[index]);
      },
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
} 