import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/update_service.dart';
import 'package:slahser_player/models/app_version.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  int _selectedIndex = 0;
  
  final List<String> _settingsTitles = [
    '外观',
    '播放',
    '快捷键',
    '关于',
  ];
  
  final List<IconData> _settingsIcons = [
    Icons.palette,
    Icons.music_note,
    Icons.keyboard,
    Icons.info_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '设置',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // 分类选项卡
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingsTab(
                  context,
                  icon: _settingsIcons[0],
                  title: _settingsTitles[0],
                  isSelected: _selectedIndex == 0,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                ),
                const SizedBox(width: 8), // 添加间隙
                _buildSettingsTab(
                  context,
                  icon: _settingsIcons[1],
                  title: _settingsTitles[1],
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
                const SizedBox(width: 8), // 添加间隙
                _buildSettingsTab(
                  context,
                  icon: _settingsIcons[2],
                  title: _settingsTitles[2],
                  isSelected: _selectedIndex == 2,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
                const SizedBox(width: 8), // 添加间隙
                _buildSettingsTab(
                  context,
                  icon: _settingsIcons[3],
                  title: _settingsTitles[3],
                  isSelected: _selectedIndex == 3,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
              ],
            ),
          ),
          // 设置内容
          Expanded(
            child: _buildSettingsContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsTab(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsContent() {
    switch (_selectedIndex) {
      case 0:
        return const AppearanceSettingsTab();
      case 1:
        return const PlaybackSettingsTab();
      case 2:
        return const ShortcutsSettingsTab();
      case 3:
        return const AboutSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

// 外观设置标签页
class AppearanceSettingsTab extends StatelessWidget {
  const AppearanceSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final settings = settingsService.settings;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 主题模式
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题模式',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildThemeModeSelector(context, settingsService, settings),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 主题颜色
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题颜色',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildThemeColorSelector(context, settingsService, settings),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 字体设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '字体设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildFontSelector(context, settingsService, settings),
                const SizedBox(height: 16),
                Text(
                  '预览',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '音乐是生活的调味剂',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '人生如音乐，要用心弹奏每一个音符。',
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeSelector(
    BuildContext context,
    SettingsService settingsService,
    AppSettings settings,
  ) {
    return Row(
      children: [
        _buildThemeModeOption(
          context,
          icon: Icons.light_mode,
          title: '浅色',
          isSelected: settingsService.currentThemeMode == ThemeMode.light,
          onTap: () {
            settingsService.updateThemeMode(AppThemeMode.light);
          },
        ),
        const SizedBox(width: 16),
        _buildThemeModeOption(
          context,
          icon: Icons.dark_mode,
          title: '深色',
          isSelected: settingsService.currentThemeMode == ThemeMode.dark,
          onTap: () {
            settingsService.updateThemeMode(AppThemeMode.dark);
          },
        ),
        const SizedBox(width: 16),
        _buildThemeModeOption(
          context,
          icon: Icons.brightness_auto,
          title: '跟随系统',
          isSelected: settingsService.currentThemeMode == ThemeMode.system,
          onTap: () {
            settingsService.updateThemeMode(AppThemeMode.system);
          },
        ),
      ],
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeColorSelector(
    BuildContext context,
    SettingsService settingsService,
    AppSettings settings,
  ) {
    final themeColors = [
      SettingsService.themeColorMap[ThemeColor.blue]!,
      SettingsService.themeColorMap[ThemeColor.purple]!,
      SettingsService.themeColorMap[ThemeColor.red]!,
      SettingsService.themeColorMap[ThemeColor.orange]!,
      SettingsService.themeColorMap[ThemeColor.green]!,
    ];
    
    final themeColorValues = [
      ThemeColor.blue,
      ThemeColor.purple,
      ThemeColor.red,
      ThemeColor.orange,
      ThemeColor.green,
    ];
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(themeColors.length, (index) {
        final color = themeColors[index];
        final themeColor = themeColorValues[index];
        final isSelected = settingsService.currentThemeColor.value == color.value;
        
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              settingsService.updateThemeColor(themeColor);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFontSelector(
    BuildContext context,
    SettingsService settingsService,
    AppSettings settings,
  ) {
    // 确保当前字体在列表中
    final fonts = [
      'System Default',
      'Roboto',
      'Open Sans',
      'Lato',
      'Montserrat',
      'Source Han Sans',
      '微软雅黑',
      '宋体',
      '黑体',
    ];
    
    // 如果当前字体不在列表中，添加它
    if (!fonts.contains(settings.fontFamily)) {
      fonts.add(settings.fontFamily);
    }
    
    return DropdownButtonFormField<String>(
      value: settings.fontFamily,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: fonts.map((font) {
        return DropdownMenuItem<String>(
          value: font,
          child: Text(
            font,
            style: TextStyle(
              fontFamily: font == 'System Default' ? null : font,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          settingsService.updateFontFamily(value);
        }
      },
    );
  }
}

// 播放设置标签页
class PlaybackSettingsTab extends StatelessWidget {
  const PlaybackSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final settings = settingsService.settings;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 音频输出设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '音频输出',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // 音频设备选择器（示例）
                DropdownButtonFormField<String>(
                  value: '默认输出设备',
                  decoration: InputDecoration(
                    labelText: '输出设备',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: '默认输出设备',
                      child: Text('默认输出设备'),
                    ),
                  ],
                  onChanged: (value) {
                    // TODO: 实现音频设备切换
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 音频效果设置
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '音频效果',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // 淡入淡出效果
                SwitchListTile(
                  title: const Text('启用淡入淡出效果'),
                  subtitle: const Text('在歌曲切换时应用淡入淡出效果'),
                  value: settings.enableFadeEffect,
                  onChanged: (value) {
                    settingsService.updateFadeEffect(value);
                  },
                ),
                // 淡入淡出持续时间
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '淡入持续时间: ${settings.fadeInDuration ~/ 1000}.${(settings.fadeInDuration % 1000) ~/ 100}秒',
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: settings.fadeInDuration.toDouble(),
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          label: '${settings.fadeInDuration ~/ 1000}.${(settings.fadeInDuration % 1000) ~/ 100}秒',
                          onChanged: settings.enableFadeEffect
                              ? (value) {
                                  settingsService.updateFadeInDuration(value.toInt());
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                // 淡出持续时间
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '淡出持续时间: ${settings.fadeOutDuration ~/ 1000}.${(settings.fadeOutDuration % 1000) ~/ 100}秒',
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: settings.fadeOutDuration.toDouble(),
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          label: '${settings.fadeOutDuration ~/ 1000}.${(settings.fadeOutDuration % 1000) ~/ 100}秒',
                          onChanged: settings.enableFadeEffect
                              ? (value) {
                                  settingsService.updateFadeOutDuration(value.toInt());
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 快捷键设置标签页
class ShortcutsSettingsTab extends StatelessWidget {
  const ShortcutsSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final settings = settingsService.settings;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全局快捷键',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // 快捷键列表
                _buildShortcutItem(
                  context,
                  action: '播放/暂停',
                  shortcut: settings.shortcuts[ShortcutAction.playPause]?.displayText ?? 'Space',
                ),
                _buildShortcutItem(
                  context,
                  action: '上一曲',
                  shortcut: settings.shortcuts[ShortcutAction.previous]?.displayText ?? 'Ctrl+Left',
                ),
                _buildShortcutItem(
                  context,
                  action: '下一曲',
                  shortcut: settings.shortcuts[ShortcutAction.next]?.displayText ?? 'Ctrl+Right',
                ),
                _buildShortcutItem(
                  context,
                  action: '音量增加',
                  shortcut: settings.shortcuts[ShortcutAction.volumeUp]?.displayText ?? 'Ctrl+Up',
                ),
                _buildShortcutItem(
                  context,
                  action: '音量减少',
                  shortcut: settings.shortcuts[ShortcutAction.volumeDown]?.displayText ?? 'Ctrl+Down',
                ),
                _buildShortcutItem(
                  context,
                  action: '静音',
                  shortcut: settings.shortcuts[ShortcutAction.mute]?.displayText ?? 'Ctrl+M',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(
    BuildContext context, {
    required String action,
    required String shortcut,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(action),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 关于设置标签页
class AboutSettingsTab extends StatelessWidget {
  const AboutSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 应用信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 应用图标
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 应用名称
                    Text(
                      'Slahser Player',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // 版本信息和检查更新按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '版本: ${AppVersion.current.version} (Build ${AppVersion.current.buildNumber})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 36,
                          child: _buildUpdateButton(context, updateService),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 更新状态显示
                    if (updateService.status != UpdateStatus.idle)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildUpdateStatus(context, updateService),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '发布日期: ${_formatDate(AppVersion.current.releaseDate)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 更新日志卡片 - 占满整行
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和版本选择器在一行
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '更新日志',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        // 版本选择下拉框
                        SizedBox(
                          width: 120,
                          child: DropdownButtonFormField<AppVersion>(
                            value: updateService.selectedVersion,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            items: updateService.versionHistory.map((version) {
                              return DropdownMenuItem<AppVersion>(
                                value: version,
                                child: Text(version.version),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                updateService.selectVersion(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 版本日期
                    Text(
                      '发布日期: ${_formatDate(updateService.selectedVersion.releaseDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // 更新日志列表（固定高度，有滚动条）
                    Container(
                      height: 200, // 固定高度
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: updateService.selectedVersion.changelog.length,
                        itemBuilder: (context, index) {
                          final item = updateService.selectedVersion.changelog[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(item)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // 构建更新按钮
  Widget _buildUpdateButton(BuildContext context, UpdateService updateService) {
    switch (updateService.status) {
      case UpdateStatus.available:
        return ElevatedButton(
          onPressed: () {
            updateService.downloadUpdate();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('下载更新'),
        );
      case UpdateStatus.checking:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return ElevatedButton(
          onPressed: () {
            updateService.checkForUpdates();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('检查更新'),
        );
    }
  }

  // 构建更新状态显示部分
  Widget _buildUpdateStatus(BuildContext context, UpdateService updateService) {
    switch (updateService.status) {
      case UpdateStatus.checking:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '正在检查更新...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case UpdateStatus.available:
        return Text(
          '发现新版本: ${updateService.latestVersion?.version ?? ''}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        );
      case UpdateStatus.upToDate:
        return Text(
          '当前已是最新版本',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
        );
      case UpdateStatus.error:
        return Text(
          '检查更新失败: ${updateService.errorMessage}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
} 