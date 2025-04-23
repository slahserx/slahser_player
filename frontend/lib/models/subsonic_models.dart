import 'package:slahser_player/models/music_file.dart';

/// Subsonic音乐文件夹
class MusicFolder {
  final String id;
  final String name;
  
  MusicFolder({
    required this.id,
    required this.name,
  });
  
  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(
      id: json['id'].toString(),
      name: json['name'] ?? '未命名文件夹',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// 索引（字母索引）
class Index {
  final String name; // 字母索引名称
  final List<Artist> artists;
  
  Index({
    required this.name,
    required this.artists,
  });
  
  factory Index.fromJson(Map<String, dynamic> json) {
    List<Artist> artistsList = [];
    
    if (json['artist'] != null) {
      if (json['artist'] is List) {
        artistsList = (json['artist'] as List)
            .map((item) => Artist.fromJson(item))
            .toList();
      } else {
        // 如果只有一个艺术家，API可能会返回单个对象而不是列表
        artistsList = [Artist.fromJson(json['artist'])];
      }
    }
    
    return Index(
      name: json['name'] ?? '#',
      artists: artistsList,
    );
  }
}

/// 艺术家
class Artist {
  final String id;
  final String name;
  final String? coverArt;
  final int? albumCount;
  final List<Album>? albums; // 在getArtist响应中会有
  
  Artist({
    required this.id,
    required this.name,
    this.coverArt,
    this.albumCount,
    this.albums,
  });
  
  factory Artist.fromJson(Map<String, dynamic> json) {
    List<Album>? albumsList;
    
    if (json['album'] != null) {
      if (json['album'] is List) {
        albumsList = (json['album'] as List)
            .map((item) => Album.fromJson(item))
            .toList();
      } else {
        // 如果只有一个专辑，API可能会返回单个对象
        albumsList = [Album.fromJson(json['album'])];
      }
    }
    
    return Artist(
      id: json['id'].toString(),
      name: json['name'] ?? '未知艺术家',
      coverArt: json['coverArt']?.toString(),
      albumCount: json['albumCount'],
      albums: albumsList,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (coverArt != null) 'coverArt': coverArt,
      if (albumCount != null) 'albumCount': albumCount,
    };
  }
}

/// 专辑
class Album {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? coverArt;
  final int? songCount;
  final int? duration;
  final DateTime? created;
  final int? year;
  final List<Song>? songs; // 在getAlbum响应中会有
  
  Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.coverArt,
    this.songCount,
    this.duration,
    this.created,
    this.year,
    this.songs,
  });
  
  factory Album.fromJson(Map<String, dynamic> json) {
    List<Song>? songsList;
    
    if (json['song'] != null) {
      if (json['song'] is List) {
        songsList = (json['song'] as List)
            .map((item) => Song.fromJson(item))
            .toList();
      } else {
        // 如果只有一首歌，API可能会返回单个对象
        songsList = [Song.fromJson(json['song'])];
      }
    }
    
    return Album(
      id: json['id'].toString(),
      name: json['name'] ?? '未知专辑',
      artist: json['artist'] ?? '未知艺术家',
      artistId: json['artistId']?.toString(),
      coverArt: json['coverArt']?.toString(),
      songCount: json['songCount'],
      duration: json['duration'],
      created: json['created'] != null ? DateTime.parse(json['created']) : null,
      year: json['year'],
      songs: songsList,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      if (artistId != null) 'artistId': artistId,
      if (coverArt != null) 'coverArt': coverArt,
      if (songCount != null) 'songCount': songCount,
      if (duration != null) 'duration': duration,
      if (created != null) 'created': created!.toIso8601String(),
      if (year != null) 'year': year,
    };
  }
}

/// 歌曲
class Song {
  final String id;
  final String title;
  final String album;
  final String artist;
  final String? albumId;
  final String? artistId;
  final String? coverArt;
  final int duration;
  final int? track;
  final int? year;
  final String? genre;
  final int? size;
  final String? contentType;
  final String? suffix;
  final int? bitRate;
  
  Song({
    required this.id,
    required this.title,
    required this.album,
    required this.artist,
    this.albumId,
    this.artistId,
    this.coverArt,
    required this.duration,
    this.track,
    this.year,
    this.genre,
    this.size,
    this.contentType,
    this.suffix,
    this.bitRate,
  });
  
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'].toString(),
      title: json['title'] ?? '未知歌曲',
      album: json['album'] ?? '未知专辑',
      artist: json['artist'] ?? '未知艺术家',
      albumId: json['albumId']?.toString(),
      artistId: json['artistId']?.toString(),
      coverArt: json['coverArt']?.toString(),
      duration: json['duration'] ?? 0,
      track: json['track'],
      year: json['year'],
      genre: json['genre'],
      size: json['size'],
      contentType: json['contentType'],
      suffix: json['suffix'],
      bitRate: json['bitRate'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'album': album,
      'artist': artist,
      if (albumId != null) 'albumId': albumId,
      if (artistId != null) 'artistId': artistId,
      if (coverArt != null) 'coverArt': coverArt,
      'duration': duration,
      if (track != null) 'track': track,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (size != null) 'size': size,
      if (contentType != null) 'contentType': contentType,
      if (suffix != null) 'suffix': suffix,
      if (bitRate != null) 'bitRate': bitRate,
    };
  }
  
  // 转换为本地MusicFile对象，用于与播放器集成
  MusicFile toMusicFile(String streamUrl, String coverUrl) {
    return MusicFile(
      id: id,
      filePath: streamUrl,  // 使用流URL作为文件路径
      fileName: title,
      fileExtension: suffix ?? 'mp3',
      title: title,
      artist: artist,
      album: album,
      duration: Duration(seconds: duration),
      coverUrl: coverUrl,  // 添加封面URL
      isRemote: true,  // 标记为远程文件
    );
  }
}

/// 播放列表
class Playlist {
  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool? public;
  final int? songCount;
  final int? duration;
  final DateTime? created;
  final DateTime? changed;
  final List<Song>? songs;
  
  Playlist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.public,
    this.songCount,
    this.duration,
    this.created,
    this.changed,
    this.songs,
  });
  
  factory Playlist.fromJson(Map<String, dynamic> json) {
    List<Song>? songsList;
    
    if (json['entry'] != null) {
      if (json['entry'] is List) {
        songsList = (json['entry'] as List)
            .map((item) => Song.fromJson(item))
            .toList();
      } else {
        // 如果只有一首歌，API可能会返回单个对象
        songsList = [Song.fromJson(json['entry'])];
      }
    }
    
    return Playlist(
      id: json['id'].toString(),
      name: json['name'] ?? '未命名播放列表',
      comment: json['comment'],
      owner: json['owner'],
      public: json['public'],
      songCount: json['songCount'],
      duration: json['duration'],
      created: json['created'] != null ? DateTime.parse(json['created']) : null,
      changed: json['changed'] != null ? DateTime.parse(json['changed']) : null,
      songs: songsList,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (comment != null) 'comment': comment,
      if (owner != null) 'owner': owner,
      if (public != null) 'public': public,
      if (songCount != null) 'songCount': songCount,
      if (duration != null) 'duration': duration,
      if (created != null) 'created': created!.toIso8601String(),
      if (changed != null) 'changed': changed!.toIso8601String(),
    };
  }
}

/// 搜索结果
class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;
  
  SearchResult({
    required this.artists,
    required this.albums,
    required this.songs,
  });
  
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    List<Artist> artistsList = [];
    List<Album> albumsList = [];
    List<Song> songsList = [];
    
    if (json['artist'] != null) {
      if (json['artist'] is List) {
        artistsList = (json['artist'] as List)
            .map((item) => Artist.fromJson(item))
            .toList();
      } else {
        artistsList = [Artist.fromJson(json['artist'])];
      }
    }
    
    if (json['album'] != null) {
      if (json['album'] is List) {
        albumsList = (json['album'] as List)
            .map((item) => Album.fromJson(item))
            .toList();
      } else {
        albumsList = [Album.fromJson(json['album'])];
      }
    }
    
    if (json['song'] != null) {
      if (json['song'] is List) {
        songsList = (json['song'] as List)
            .map((item) => Song.fromJson(item))
            .toList();
      } else {
        songsList = [Song.fromJson(json['song'])];
      }
    }
    
    return SearchResult(
      artists: artistsList,
      albums: albumsList,
      songs: songsList,
    );
  }
} 