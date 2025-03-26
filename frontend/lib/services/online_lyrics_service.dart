import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OnlineLyricsService {
  // 使用QQ音乐API
  static const String _baseUrl = 'https://c.y.qq.com';
  
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 10);
  
  // 搜索歌曲
  static Future<Map<String, dynamic>?> searchSong(String keyword) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/splcloud/fcgi-bin/smartbox_new.fcg?key=${Uri.encodeComponent(keyword)}&format=json'),
        headers: {
          'Referer': 'https://y.qq.com',
          'User-Agent': 'Mozilla/5.0',
        },
      );
      
      debugPrint('搜索响应状态码: ${response.statusCode}');
      debugPrint('搜索响应内容: ${response.body}\n');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('搜索歌曲出错: $e');
    }
    return null;
  }
  
  // 获取歌词（包括翻译）
  static Future<String?> getLyrics(String songMid) async {
    try {
      // 获取原文歌词
      final originalResponse = await http.get(
        Uri.parse('$_baseUrl/lyric/fcgi-bin/fcg_query_lyric_new.fcg?format=json&nobase64=1&songmid=$songMid&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq.json'),
        headers: {
          'Referer': 'https://y.qq.com',
          'User-Agent': 'Mozilla/5.0',
        },
      );

      // 获取翻译歌词
      final translationResponse = await http.get(
        Uri.parse('$_baseUrl/lyric/fcgi-bin/fcg_query_lyric_new.fcg?format=json&nobase64=1&songmid=$songMid&g_tk=5381&loginUin=0&hostUin=0&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq.json&trans=1'),
        headers: {
          'Referer': 'https://y.qq.com',
          'User-Agent': 'Mozilla/5.0',
        },
      );

      if (originalResponse.statusCode == 200 && translationResponse.statusCode == 200) {
        final originalData = json.decode(originalResponse.body);
        final translationData = json.decode(translationResponse.body);
        
        debugPrint('原文歌词响应: ${originalResponse.body}');
        debugPrint('翻译歌词响应: ${translationResponse.body}');

        String? originalLyric = originalData['lyric'];
        String? translationLyric = translationData['trans'];
        
        if (originalLyric != null) {
          if (translationLyric != null) {
            // 解析原文和翻译
            final Map<String, String> translations = {};
            final List<String> transLines = translationLyric.split('\n');
            
            for (String line in transLines) {
              final match = RegExp(r'^\[(\d{2}:\d{2}\.\d{2,3})\](.*)$').firstMatch(line);
              if (match != null) {
                final timeTag = match.group(1)!;
                final translation = match.group(2)!.trim();
                if (translation.isNotEmpty) {
                  translations[timeTag] = translation;
                }
              }
            }
            
            // 合并原文和翻译
            final List<String> originalLines = originalLyric.split('\n');
            final List<String> mergedLines = [];
            
            for (String line in originalLines) {
              mergedLines.add(line);
              final match = RegExp(r'^\[(\d{2}:\d{2}\.\d{2,3})\](.*)$').firstMatch(line);
              if (match != null) {
                final timeTag = match.group(1)!;
                if (translations.containsKey(timeTag)) {
                  mergedLines.add('[$timeTag]${translations[timeTag]}');
                }
              }
            }
            
            return mergedLines.join('\n');
          }
          return originalLyric;
        }
      }
    } catch (e) {
      debugPrint('获取歌词出错: $e');
    }
    return null;
  }
  
  // 搜索并获取歌词
  static Future<String?> searchAndGetLyrics(String title, String artist) async {
    try {
      debugPrint('开始搜索歌曲，关键词: $title $artist');
      
      final searchResult = await searchSong('$title $artist');
      if (searchResult != null && searchResult['code'] == 0) {
        final data = searchResult['data'];
        final songList = data['song']['itemlist'] as List;
        
        if (songList.isNotEmpty) {
          debugPrint('成功获取到 ${songList.length} 首歌曲');
          
          // 找到最匹配的歌曲
          var bestMatch = songList[0];
          var bestScore = 0;
          
          for (var song in songList) {
            final songTitle = song['name'].toString().toLowerCase();
            final songArtist = song['singer'].toString().toLowerCase();
            final targetTitle = title.toLowerCase();
            final targetArtist = artist.toLowerCase();
            
            debugPrint('比较歌曲: $songTitle - $songArtist');
            debugPrint('与目标: $targetTitle - $targetArtist');
            
            var score = 0;
            if (songTitle.contains(targetTitle) || targetTitle.contains(songTitle)) score += 5;
            if (songArtist.contains(targetArtist) || targetArtist.contains(songArtist)) score += 5;
            
            debugPrint('匹配得分: $score');
            
            if (score > bestScore) {
              bestScore = score;
              bestMatch = song;
              debugPrint('找到更好的匹配');
            }
          }
          
          final songMid = bestMatch['mid'].toString();
          debugPrint('选择最佳匹配歌曲: MID=$songMid, 标题=${bestMatch['name']}, 歌手=${bestMatch['singer']}');
          
          final lyrics = await getLyrics(songMid);
          if (lyrics != null) {
            debugPrint('成功获取原文歌词');
            debugPrint('成功获取翻译歌词');
            return lyrics;
          }
        }
      }
    } catch (e) {
      debugPrint('搜索并获取歌词出错: $e');
    }
    return null;
  }
  
  // 清理资源
  static void dispose() {
    _client.close();
  }
} 