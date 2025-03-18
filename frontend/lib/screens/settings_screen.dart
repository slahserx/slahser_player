import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/theme/app_theme.dart';
import '../utils/cache_manager.dart';

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
                    
                    FutureBuilder<String>(
                      future: musicLibraryService.getCacheSize(),
                      builder: (context, snapshot) {
                        return ListTile(
                          title: const Text('缓存大小'),
                          subtitle: Text(snapshot.data ?? '计算中...'),
                          leading: const Icon(Icons.storage),
                          dense: true,
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