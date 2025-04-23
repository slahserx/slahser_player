/// 内容类型枚举，用于定义ContentArea显示的内容类型
enum ContentType {
  /// 所有音乐视图
  allMusic,
  
  /// 歌手视图
  artists,
  
  /// 专辑视图
  albums,
  
  /// 歌单列表
  playlists,
  
  /// 歌单详情
  playlist,
  
  /// 设置页面
  settings,
  
  /// 艺术家详情页
  artistDetail,
  
  /// 专辑详情页
  albumDetail,
  
  /// 云音乐视图
  cloudMusic,
  
  /// 云音乐设置 (已整合到settings中)
  @Deprecated("使用settings代替")
  cloudMusicSettings,
  
  /// 云音乐艺术家视图
  cloudArtists,
  
  /// 云音乐专辑视图
  cloudAlbums,
  
  /// 云音乐艺术家详情
  cloudArtistDetail,
  
  /// 云音乐专辑详情
  cloudAlbumDetail,
  
  /// 云音乐专辑列表
  cloudAlbumList,
  
  /// 云音乐搜索结果
  cloudSearchResult,
} 