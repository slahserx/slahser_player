import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:slahser_player/enums/playback_state.dart';

class AlbumDetailPage extends StatefulWidget {
  final String album;
  final String artist;
  final List<MusicFile> songs;

  const AlbumDetailPage({
    super.key,
    required this.album,
    required this.artist,
    required this.songs,
  });

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late MusicFile? _firstSong;

  @override
  void initState() {
    super.initState();
    _firstSong = widget.songs.isNotEmpty ? widget.songs.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 专辑信息头部
          _buildAlbumHeader(),
          // 歌曲列表
          Expanded(
            child: _buildSongsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // 专辑封面
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildAlbumCover(),
          ),
          const SizedBox(width: 20),
          // 专辑信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.artist,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.songs.length}首歌曲',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                // 播放按钮
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放全部'),
                      onPressed: () {
                        _playAllSongs();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('随机播放'),
                      onPressed: () {
                        _shuffleSongs();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCover() {
    if (_firstSong == null) {
      return Center(
        child: Icon(
          Icons.album,
          size: 60,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
        ),
      );
    }

    if (_firstSong!.coverPath != null && File(_firstSong!.coverPath!).existsSync()) {
      return Hero(
        tag: 'album-cover-${widget.album}',
        child: Image.file(
          File(_firstSong!.coverPath!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } else if (_firstSong!.hasEmbeddedCover && _firstSong!.embeddedCoverBytes != null) {
      return Hero(
        tag: 'album-cover-${widget.album}',
        child: Image.memory(
          Uint8List.fromList(_firstSong!.embeddedCoverBytes!),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.album,
                size: 60,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
            );
          },
        ),
      );
    } else {
      return Center(
        child: Icon(
          Icons.album,
          size: 60,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
        ),
      );
    }
  }

  Widget _buildSongsList() {
    final audioPlayer = Provider.of<AudioPlayerService>(context);
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        final music = widget.songs[index];
        final isPlaying = audioPlayer.currentMusic?.id == music.id && 
                          audioPlayer.playbackState == PlaybackState.playing;
                          
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isPlaying 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isPlaying ? FontWeight.bold : null,
              ),
            ),
          ),
          title: Text(
            music.title.isNotEmpty ? music.title : '未知歌曲',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Text(
            _formatDuration(music.duration),
            style: TextStyle(
              color: isPlaying
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          onTap: () => _playSong(index),
        );
      },
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _playAllSongs() {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    if (widget.songs.isEmpty) return;
    
    audioPlayer.setPlaylist(widget.songs);
    audioPlayer.playMusic(widget.songs.first);
  }

  void _shuffleSongs() {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    if (widget.songs.isEmpty) return;
    
    audioPlayer.setPlaylist(widget.songs, shuffle: true);
    audioPlayer.playMusic(audioPlayer.currentPlaylist.first);
  }

  void _playSong(int index) {
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    if (widget.songs.isEmpty || index >= widget.songs.length) return;

    audioPlayer.setPlaylist(widget.songs, initialIndex: index);
    audioPlayer.playMusic(widget.songs[index]);
  }
} 