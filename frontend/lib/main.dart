import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:slahser_player/pages/home_page.dart';
import 'package:slahser_player/services/music_library_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/playlist_service.dart';
import 'package:slahser_player/services/update_service.dart';
import 'package:slahser_player/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 配置窗口
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    title: 'Slahser Player',
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(false);
    await windowManager.setResizable(true);
  });
  
  // 初始化设置服务
  final settingsService = SettingsService();
  await settingsService.init();
  
  // 初始化音频播放服务
  final audioPlayerService = AudioPlayerService();
  await audioPlayerService.init();
  
  // 将设置服务传递给音频播放服务
  audioPlayerService.setSettingsService(settingsService);
  
  // 初始化音乐库服务
  final musicLibraryService = MusicLibraryService();
  
  // 初始化歌单服务
  final playlistService = PlaylistService();
  await playlistService.init(musicLibraryService);
  
  // 将歌单服务传递给音频播放服务
  audioPlayerService.setPlaylistService(playlistService);
  
  // 初始化更新服务
  final updateService = UpdateService();
  
  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: audioPlayerService),
        ChangeNotifierProvider.value(value: musicLibraryService),
        ChangeNotifierProvider.value(value: playlistService),
        ChangeNotifierProvider.value(value: updateService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取主题模式和颜色
    final settingsService = Provider.of<SettingsService>(context);
    final customColor = settingsService.currentThemeColor;
    final fontFamily = settingsService.settings.fontFamily == 'System Default' ? null : settingsService.settings.fontFamily;
    
    return MaterialApp(
      title: 'Slahser Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createLightTheme(primaryColor: customColor, fontFamily: fontFamily),
      darkTheme: AppTheme.createDarkTheme(primaryColor: customColor, fontFamily: fontFamily),
      themeMode: settingsService.currentThemeMode,
      home: const HomePage(),
    );
  }
}
