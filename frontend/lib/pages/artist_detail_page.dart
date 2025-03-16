import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/music_file.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:slahser_player/enums/playback_state.dart';

class ArtistDetailPage extends StatefulWidget {
  final String artist;
  final List<MusicFile> songs;

  const ArtistDetailPage({
    super.key,
    required this.artist,
    required this.songs,
  });

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artist),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 歌手信息头部
          _buildArtistHeader(),
          // 歌曲列表
          Expanded(
            child: _buildSongsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          // 歌手头像
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              shape: BoxShape.circle,
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
            child: Icon(
              Icons.person,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
          const SizedBox(width: 20),
          // 歌手信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.artist,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.songs.length}首歌曲',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
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
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildCoverImage(music, isPlaying),
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
          subtitle: Text(
            music.album.isNotEmpty ? music.album : '未知专辑',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.7) 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildCoverImage(MusicFile music, bool isPlaying) {
    if (music.coverPath != null && File(music.coverPath!).existsSync()) {
      return Image.file(
        File(music.coverPath!),
        fit: BoxFit.cover,
        width: 40,
        height: 40,
        gaplessPlayback: true,
      );
    } else if (music.hasEmbeddedCover && music.embeddedCoverBytes != null) {
      return Image.memory(
        Uint8List.fromList(music.embeddedCoverBytes!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackCover(isPlaying);
        },
      );
    } else {
      return _buildFallbackCover(isPlaying);
    }
  }

  Widget _buildFallbackCover(bool isPlaying) {
    return Container(
      color: isPlaying 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
          : Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 20,
          color: isPlaying 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
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