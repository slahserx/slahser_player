import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OnlineLyricsService {
  // 使用QQ音乐API
  static const String _baseUrl = 'https://c.y.qq.com';
  
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 10);
  
  // 搜索歌曲
  static Future<List<Map<String, dynamic>>> searchSong(String keyword) async {
    try {
      final encodedKeyword = Uri.encodeComponent(keyword);
      final url = '$_baseUrl/splcloud/fcgi-bin/smartbox_new.fcg'
          '?format=json'
          '&key=$encodedKeyword'
          '&platform=yqq.json';
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://y.qq.com',
          'Origin': 'https://y.qq.com'
        }
      ).timeout(_timeout);
      
      debugPrint('搜索响应状态码: ${response.statusCode}');
      debugPrint('搜索响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0 && data['data'] != null && data['data']['song'] != null) {
          final songs = List<Map<String, dynamic>>.from(data['data']['song']['itemlist']);
          debugPrint('成功获取到 ${songs.length} 首歌曲');
          return songs;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('搜索歌曲失败: $e');
      debugPrint('错误堆栈: $stackTrace');
    }
    
    return [];
  }
  
  // 获取歌词
  static Future<String?> getLyrics(String songMid) async {
    try {
      final url = '$_baseUrl/lyric/fcgi-bin/fcg_query_lyric_new.fcg'
          '?format=json'
          '&nobase64=1'
          '&songmid=$songMid'
          '&platform=yqq.json';
      
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://y.qq.com',
          'Origin': 'https://y.qq.com'
        }
      ).timeout(_timeout);
      
      debugPrint('歌词响应状态码: ${response.statusCode}');
      debugPrint('歌词响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0 && data['lyric'] != null) {
          final lyrics = data['lyric'];
          if (lyrics.isNotEmpty) {
            debugPrint('成功获取歌词');
            return lyrics;
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('获取歌词失败: $e');
      debugPrint('错误堆栈: $stackTrace');
    }
    
    return null;
  }
  
  // 搜索并获取歌词
  static Future<String?> searchAndGetLyrics(String title, String artist) async {
    try {
      // 移除版本信息，提高匹配率
      title = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
      final keyword = '$title $artist'.trim();
      debugPrint('开始搜索歌曲，关键词: $keyword');
      
      final songs = await searchSong(keyword);
      if (songs.isEmpty) {
        debugPrint('未找到匹配的歌曲');
        return null;
      }
      
      // 尝试找到最匹配的歌曲
      var bestMatch = songs[0];
      var bestScore = 0;
      
      for (var song in songs) {
        var score = 0;
        final songTitle = song['name'].toString().toLowerCase();
        final songSinger = song['singer'].toString().toLowerCase();
        
        // 移除版本信息后比较
        final cleanTitle = title.toLowerCase();
        final cleanArtist = artist.toLowerCase();
        
        debugPrint('比较歌曲: $songTitle - $songSinger');
        debugPrint('与目标: $cleanTitle - $cleanArtist');
        
        if (songTitle.contains(cleanTitle)) score += 2;
        if (songSinger.contains(cleanArtist)) score += 2;
        if (songTitle == cleanTitle) score += 3;
        if (songSinger == cleanArtist) score += 3;
        
        debugPrint('匹配得分: $score');
        
        if (score > bestScore) {
          bestScore = score;
          bestMatch = song;
          debugPrint('找到更好的匹配');
        }
      }
      
      if (bestScore > 0) {
        final songMid = bestMatch['mid'];
        debugPrint('选择最佳匹配歌曲: MID=$songMid, 标题=${bestMatch['name']}, 歌手=${bestMatch['singer']}');
        
        return await getLyrics(songMid);
      } else {
        debugPrint('没有找到足够匹配的歌曲');
      }
    } catch (e, stackTrace) {
      debugPrint('搜索并获取歌词失败: $e');
      debugPrint('错误堆栈: $stackTrace');
    }
    
    return null;
  }
  
  // 清理资源
  static void dispose() {
    _client.close();
  }
} 