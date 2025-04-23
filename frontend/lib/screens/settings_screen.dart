import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/theme/app_theme.dart';
import '../utils/cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final musicLibraryService = Provider.of<MusicLibraryService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主题设置
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '外观设置',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 主题模式选择
                    ListTile(
                      title: const Text('主题模式'),
                      subtitle: Text(
                        settingsService.currentThemeMode == ThemeMode.system
                            ? '跟随系统'
                            : settingsService.currentThemeMode == ThemeMode.light
                                ? '浅色模式'
                                : '深色模式',
                      ),
                      leading: const Icon(Icons.brightness_6),
                      trailing: DropdownButton<ThemeMode>(
                        value: settingsService.currentThemeMode,
                        onChanged: (ThemeMode? newValue) {
                          if (newValue != null) {
                            settingsService.setThemeMode(newValue);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('跟随系统'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('浅色模式'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('深色模式'),
                          ),
                        ],
                      ),
                      dense: true,
                    ),
                    
                    // 主题颜色选择
                    ListTile(
                      title: const Text('主题颜色'),
                      subtitle: Text('当前颜色: ${settingsService.currentThemeColor.toString().split('(')[1].split(')')[0]}'),
                      leading: const Icon(Icons.color_lens),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: settingsService.currentThemeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      onTap: () {
                        // 显示颜色选择器
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('选择主题颜色'),
                            content: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AppTheme.availableColors.map((color) {
                                  return InkWell(
                                    onTap: () {
                                      settingsService.setThemeColor(color);
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color == settingsService.currentThemeColor
                                              ? Colors.white
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                      dense: true,
                    ),
                    
                    // 字体选择
                    ListTile(
                      title: const Text('字体'),
                      subtitle: Text(settingsService.settings.fontFamily),
                      leading: const Icon(Icons.font_download),
                      trailing: DropdownButton<String>(
                        value: settingsService.settings.fontFamily,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            settingsService.setFontFamily(newValue);
                          }
                        },
                        items: AppTheme.availableFonts.map((font) {
                          return DropdownMenuItem(
                            value: font,
                            child: Text(font),
                          );
                        }).toList(),
                      ),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            
            // 缓存管理
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '缓存管理',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    FutureBuilder<Map<CacheType, String>>(
                      future: musicLibraryService.getAllCacheSizes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            title: Text('缓存大小'),
                            subtitle: Text('计算中...'),
                            leading: Icon(Icons.storage),
                            dense: true,
                          );
                        }
                        
                        final cacheSizes = snapshot.data!;
                        
                        return Column(
                          children: [
                            ListTile(
                              title: const Text('总缓存大小'),
                              subtitle: Text(cacheSizes[CacheType.all] ?? '0 KB'),
                              leading: const Icon(Icons.storage),
                              dense: true,
                            ),
                            
                            ExpansionTile(
                              title: const Text('缓存详情'),
                              leading: const Icon(Icons.folder),
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                ListTile(
                                  title: const Text('封面缓存'),
                                  subtitle: Text(cacheSizes[CacheType.cover] ?? '0 KB'),
                                  leading: const Icon(Icons.image),
                                  dense: true,
                                ),
                                ListTile(
                                  title: const Text('元数据缓存'),
                                  subtitle: Text(cacheSizes[CacheType.metadata] ?? '0 KB'),
                                  leading: const Icon(Icons.audiotrack),
                                  dense: true,
                                ),
                                ListTile(
                                  title: const Text('歌词缓存'),
                                  subtitle: Text(cacheSizes[CacheType.lyrics] ?? '0 KB'),
                                  leading: const Icon(Icons.lyrics),
                                  dense: true,
                                ),
                                ListTile(
                                  title: const Text('云音乐缓存'),
                                  subtitle: Text(cacheSizes[CacheType.cloudMusic] ?? '0 KB'),
                                  leading: const Icon(Icons.cloud_download),
                                  dense: true,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const Divider(),
                    
                    ListTile(
                      title: const Text('清理封面缓存'),
                      subtitle: const Text('删除所有缓存的封面图片'),
                      leading: const Icon(Icons.image),
                      onTap: () async {
                        await MusicCacheManager().clearCache(CacheType.cover);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('封面缓存已清理')),
                          );
                          // 刷新界面
                          setState(() {});
                        }
                      },
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('清理元数据缓存'),
                      subtitle: const Text('删除所有缓存的音乐元数据'),
                      leading: const Icon(Icons.audiotrack),
                      onTap: () async {
                        await MusicCacheManager().clearCache(CacheType.metadata);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('元数据缓存已清理')),
                          );
                          // 刷新界面
                          setState(() {});
                        }
                      },
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('清理歌词缓存'),
                      subtitle: const Text('删除所有缓存的歌词数据'),
                      leading: const Icon(Icons.lyrics),
                      onTap: () async {
                        await MusicCacheManager().clearCache(CacheType.lyrics);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('歌词缓存已清理')),
                          );
                          // 刷新界面
                          setState(() {});
                        }
                      },
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('清理云音乐缓存'),
                      subtitle: const Text('删除所有缓存的云音乐文件'),
                      leading: const Icon(Icons.cloud_download),
                      onTap: () async {
                        await MusicCacheManager().clearCache(CacheType.cloudMusic);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('云音乐缓存已清理')),
                          );
                          // 刷新界面
                          setState(() {});
                        }
                      },
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('清理所有缓存'),
                      subtitle: const Text('删除所有类型的缓存数据'),
                      leading: const Icon(Icons.cleaning_services),
                      onTap: () async {
                        // 显示确认对话框
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('清理所有缓存'),
                              content: const Text('这将删除所有缓存数据，包括封面和元数据缓存。下次打开音乐文件时将重新解析。\n\n确定要继续吗？'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('取消'),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: const Text('确定'),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        
                        if (result == true) {
                          await MusicCacheManager().clearCache(CacheType.all);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('所有缓存已清理')),
                            );
                            // 刷新界面
                            setState(() {});
                          }
                        }
                      },
                      dense: true,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ListTile(
                      title: const Text('重新扫描所有音乐文件'),
                      subtitle: const Text('重新读取所有音乐文件的元数据'),
                      leading: const Icon(Icons.refresh),
                      onTap: () async {
                        // 显示确认对话框
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('重新扫描所有音乐文件'),
                              content: const Text('这将重新读取所有音乐文件的元数据，可能需要一些时间。\n\n确定要继续吗？'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('取消'),
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                ),
                                TextButton(
                                  child: const Text('确定'),
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                        
                        if (result == true) {
                          // 显示进度对话框
                          if (mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return const AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('正在重新扫描音乐文件...'),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                          
                          // 清理缓存并重新扫描
                          await MusicCacheManager().clearCache(CacheType.metadata);
                          final count = await musicLibraryService.rescanAllFiles();
                          
                          // 关闭进度对话框
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已重新扫描 $count 个音乐文件')),
                            );
                            // 刷新界面
                            setState(() {});
                          }
                        }
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            
            // 关于应用
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '关于',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ListTile(
                      title: const Text('Slahser Player'),
                      subtitle: const Text('版本 1.0.0'),
                      leading: const Icon(Icons.music_note),
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('关于应用'),
                      subtitle: const Text('一款美观、简洁的本地音乐播放器'),
                      leading: const Icon(Icons.info),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Slahser Player',
                          applicationVersion: '1.0.0',
                          applicationIcon: const Icon(Icons.music_note),
                          applicationLegalese: '© 2023 Slahser Player Team',
                          children: const [
                            SizedBox(height: 16),
                            Text('一款美观、简洁的本地音乐播放器，支持多种音频格式，提供丰富的功能和优美的界面。'),
                          ],
                        );
                      },
                      dense: true,
                    ),
                    
                    ListTile(
                      title: const Text('软件更新'),
                      subtitle: const Text('点击前往下载页面获取最新版本'),
                      leading: const Icon(Icons.cloud_download),
                      trailing: OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('下载(密码:c5z0)'),
                        onPressed: () async {
                          // 尝试启动默认浏览器打开链接
                          try {
                            await launchUrl(Uri.parse('https://wwb.lanzoum.com/b002uuo6ed'));
                          } catch (e) {
                            // 如果无法打开浏览器，显示错误消息
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('无法打开链接，请手动复制网址')),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () async {
                        // 尝试启动默认浏览器打开链接
                        try {
                          await launchUrl(Uri.parse('https://wwb.lanzoum.com/b002uuo6ed'));
                        } catch (e) {
                          // 如果无法打开浏览器，显示错误消息
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('无法打开链接，请手动复制网址')),
                            );
                          }
                        }
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 