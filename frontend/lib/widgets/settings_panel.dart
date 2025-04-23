import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:slahser_player/services/settings_service.dart';
import 'package:slahser_player/services/audio_player_service.dart';
import 'package:slahser_player/services/subsonic_service.dart';
import 'package:slahser_player/services/update_service.dart';
import 'package:slahser_player/models/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:slahser_player/utils/cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';

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
    '云音乐',
    '关于',
  ];
  
  final List<IconData> _settingsIcons = [
    Icons.palette,
    Icons.music_note,
    Icons.cloud_outlined,
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
        return const CloudMusicSettingsTab();
      case 3:
        return const AboutSettingsTab();
      default:
        return const AppearanceSettingsTab();
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
      spacing: 12,
      runSpacing: 12,
          children: [
            ...List.generate(themeColors.length, (index) {
        final color = themeColors[index];
        final themeColor = themeColorValues[index];
              final isSelected = settingsService.currentThemeColor.value == color.value && 
                                settings.themeColor != ThemeColor.custom;
        
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
            // 添加自定义颜色选择器按钮
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _showColorPickerDialog(context, settingsService);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: settings.themeColor == ThemeColor.custom 
                        ? Color(settings.customColor)
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: settings.themeColor == ThemeColor.custom
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: settings.themeColor == ThemeColor.custom
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : Icon(
                          Icons.color_lens,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (settings.themeColor == ThemeColor.custom) ...[
          Text(
            '当前使用自定义颜色',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              _showColorPickerDialog(context, settingsService);
            },
            icon: const Icon(Icons.edit),
            label: const Text('修改自定义颜色'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(settings.customColor),
              foregroundColor: _getTextColorForBackground(Color(settings.customColor)),
            ),
          ),
        ],
      ],
    );
  }

  // 显示颜色选择器对话框
  void _showColorPickerDialog(BuildContext context, SettingsService settingsService) {
    // 使用当前颜色作为初始值
    Color currentColor = settingsService.currentThemeColor;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('主题选择器'),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SingleChildScrollView(
            child: _buildColorPicker(
              currentColor,
              (Color color) {
                currentColor = color;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              child: const Text('确定'),
              onPressed: () {
                settingsService.updateCustomColor(currentColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  
  // 构建颜色选择器组件
  Widget _buildColorPicker(Color initialColor, void Function(Color) onColorChanged) {
    // 创建一个状态控制器，保存当前选择的颜色
    final ValueNotifier<Color> colorNotifier = ValueNotifier<Color>(initialColor);
    
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签切换(Hex/RGB)
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(context, 'Hex', true),
                      _buildTabButton(context, 'RGB', false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 颜色输入框
            TextField(
              controller: TextEditingController(
                text: '#${colorNotifier.value.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
              ),
              decoration: InputDecoration(
                labelText: 'Hex',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                if (value.startsWith('#') && value.length == 7) {
                  try {
                    final color = Color(int.parse('FF${value.substring(1)}', radix: 16));
                    setState(() {
                      colorNotifier.value = color;
                      onColorChanged(color);
                    });
                  } catch (e) {
                    // 忽略无效的颜色值
                  }
                }
              },
            ),
            const SizedBox(height: 24),
            
            // HSV色环选择器
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    center: Alignment.center,
                    colors: const [
                      Colors.red,
                      Colors.pink,
                      Colors.purple,
                      Colors.blue,
                      Colors.cyan,
                      Colors.green,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 中间白色到黑色渐变区域
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 中间灰色过渡区域
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Colors.transparent, Colors.black],
                            stops: [0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    
                    // 颜色选择点
                    ValueListenableBuilder<Color>(
                      valueListenable: colorNotifier,
                      builder: (context, color, _) {
                        // 获取当前颜色的HSV
                        final HSVColor hsvColor = HSVColor.fromColor(color);
                        
                        // 计算选择点的位置
                        final double angle = hsvColor.hue * (3.14159 / 180);
                        final double saturation = hsvColor.saturation; 
                        final double value = hsvColor.value;
                        
                        // 外环选择点
                        Widget circleSelector = Positioned(
                          left: 140 + 120 * cos(angle.toDouble()),
                          top: 140 + 120 * sin(angle.toDouble()),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              // 计算新的角度和饱和度
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              final Offset center = renderBox.size.center(Offset.zero);
                              final Offset position = details.localPosition;
                              
                              final double dx = position.dx - center.dx;
                              final double dy = position.dy - center.dy;
                              
                              final double distance = sqrt(dx * dx + dy * dy);
                              final double maxRadius = 100.0; // 内圆最大半径
                              
                              final double newSaturation = (distance / maxRadius).clamp(0.0, 1.0);
                              
                              // 计算新的角度
                              final double newAngle = atan2(dy, dx);
                              final double newHue = (newAngle * (180 / 3.14159)) % 360;
                              
                              // 更新颜色
                              final HSVColor newHsvColor = HSVColor.fromAHSV(
                                1.0, 
                                newHue < 0 ? newHue + 360 : newHue, 
                                newSaturation, 
                                hsvColor.value
                              );
                              
                              setState(() {
                                final Color newColor = newHsvColor.toColor();
                                colorNotifier.value = newColor;
                                onColorChanged(newColor);
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.3), 
                                  width: 2.0
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: HSVColor.fromAHSV(1.0, hsvColor.hue, 1.0, 1.0).toColor(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        
                        // 内部亮度和饱和度选择点
                        Widget innerSelector = Positioned(
                          left: 140 + (saturation * 90) * cos(angle.toDouble()),
                          top: 140 + (saturation * 90) * sin(angle.toDouble()),
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              // 计算新的角度和饱和度
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              final Offset center = renderBox.size.center(Offset.zero);
                              final Offset position = details.localPosition;
                              
                              final double dx = position.dx - center.dx;
                              final double dy = position.dy - center.dy;
                              
                              final double distance = sqrt(dx * dx + dy * dy);
                              final double maxRadius = 100.0; // 内圆最大半径
                              
                              final double newSaturation = (distance / maxRadius).clamp(0.0, 1.0);
                              
                              // 计算新的角度
                              final double newAngle = atan2(dy, dx);
                              final double newHue = (newAngle * (180 / 3.14159)) % 360;
                              
                              // 更新颜色
                              final HSVColor newHsvColor = HSVColor.fromAHSV(
                                1.0, 
                                newHue < 0 ? newHue + 360 : newHue, 
                                newSaturation, 
                                hsvColor.value
                              );
                              
                              setState(() {
                                final Color newColor = newHsvColor.toColor();
                                colorNotifier.value = newColor;
                                onColorChanged(newColor);
                              });
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: Border.all(
                                  color: Colors.white, 
                                  width: 2.0
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        
                        return Stack(
                          children: [
                            GestureDetector(
                              onPanDown: (details) {
                                _handleColorPanUpdate(
                                  details.localPosition, 
                                  context, 
                                  colorNotifier, 
                                  onColorChanged, 
                                  setState
                                );
                              },
                              onPanUpdate: (details) {
                                _handleColorPanUpdate(
                                  details.localPosition, 
                                  context, 
                                  colorNotifier, 
                                  onColorChanged, 
                                  setState
                                );
                              },
                              child: Container(
                                width: 280,
                                height: 280,
                                color: Colors.transparent,
                              ),
                            ),
                            circleSelector,
                            innerSelector,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 当前选中的颜色预览
            ValueListenableBuilder<Color>(
              valueListenable: colorNotifier,
              builder: (context, color, _) {
                return Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '预览颜色',
                      style: TextStyle(
                        color: _getTextColorForBackground(color),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // 颜色值
            ValueListenableBuilder<Color>(
              valueListenable: colorNotifier,
              builder: (context, color, _) {
                return Center(
                  child: Text(
                    '颜色值: #${color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // 处理颜色盘上的手势
  void _handleColorPanUpdate(
    Offset localPosition, 
    BuildContext context, 
    ValueNotifier<Color> colorNotifier, 
    void Function(Color) onColorChanged,
    StateSetter setState
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    final double dx = localPosition.dx - centerX;
    final double dy = localPosition.dy - centerY;
    final double distance = sqrt(dx * dx + dy * dy);
    
    // 计算角度（hue）
    double angle = atan2(dy, dx);
    double hue = (angle * (180 / 3.14159)) % 360;
    if (hue < 0) hue += 360;
    
    // 计算饱和度（saturation）
    const double maxRadius = 140; // 颜色盘最大半径
    const double innerRadius = 30; // 中心白色区域半径
    
    double saturation = 0.0;
    if (distance > innerRadius) {
      saturation = ((distance - innerRadius) / (maxRadius - innerRadius)).clamp(0.0, 1.0);
    }
    
    // 计算明度（value）- 简化实现，可以固定为1
    double value = 1.0;
    
    // 创建新颜色
    final HSVColor hsvColor = HSVColor.fromAHSV(1.0, hue, saturation, value);
    final Color newColor = hsvColor.toColor();
    
    setState(() {
      colorNotifier.value = newColor;
      onColorChanged(newColor);
    });
  }
  
  // 构建标签切换按钮
  Widget _buildTabButton(BuildContext context, String label, bool isSelected) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        // 切换标签逻辑
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // 获取适合背景色的文本颜色（黑色或白色）
  Color _getTextColorForBackground(Color backgroundColor) {
    // 计算颜色的亮度
    final double brightness = backgroundColor.computeLuminance();
    // 亮度大于0.5返回黑色，否则返回白色
    return brightness > 0.5 ? Colors.black : Colors.white;
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

// 云音乐设置标签页
class CloudMusicSettingsTab extends StatefulWidget {
  const CloudMusicSettingsTab({super.key});

  @override
  State<CloudMusicSettingsTab> createState() => _CloudMusicSettingsTabState();
}

class _CloudMusicSettingsTabState extends State<CloudMusicSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLegacyAuth = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isEditMode = false;
  
  // 新增的预缓冲设置
  bool _enablePreBuffer = true;
  int _preBufferCount = 2;
  
  // 下载路径设置
  String _downloadPath = '';
  bool _isCustomDownloadPath = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _loadSettings() {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    
    // 加载当前设置到表单
    _serverUrlController.text = subsonicService.serverUrl;
    _usernameController.text = subsonicService.username;
    _isLegacyAuth = subsonicService.isLegacyAuth;
    
    // 确定是否为编辑模式
    _isEditMode = subsonicService.isConnected;
    
    // 反映音频播放器中的预缓冲设置
    setState(() {
      _enablePreBuffer = audioPlayerService.isPreBufferEnabled;
      _preBufferCount = audioPlayerService.preBufferCount;
      
      // 加载下载路径设置
      _downloadPath = settingsService.getCloudMusicDownloadPath();
      _isCustomDownloadPath = _downloadPath.isNotEmpty;
    });
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await subsonicService.saveSettings(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        isLegacyAuth: _isLegacyAuth,
      );
      
      setState(() {
        _isLoading = false;
        _errorMessage = subsonicService.isConnected ? '' : subsonicService.errorMessage;
      });
      
      if (subsonicService.isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('云音乐设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // 先保存设置
      await subsonicService.saveSettings(
        serverUrl: _serverUrlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        isLegacyAuth: _isLegacyAuth,
      );
      
      // 测试连接
      final isConnected = await subsonicService.testConnection();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = isConnected ? '' : subsonicService.errorMessage;
        });
        
        if (isConnected) {
          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('连接成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subsonicService = Provider.of<SubsonicService>(context);
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 连接状态卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接状态',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: subsonicService.isConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        subsonicService.isConnected
                            ? Icons.check_circle
                            : Icons.info,
                        color: subsonicService.isConnected
                            ? Colors.green
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subsonicService.isConnected
                                  ? '已连接到 Subsonic 服务器'
                                  : '未连接到服务器',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (subsonicService.isConnected)
                              Text(
                                '服务器: ${subsonicService.serverUrl}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 服务器配置表单
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subsonic 服务器配置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 服务器URL
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: InputDecoration(
                      labelText: '服务器地址',
                      hintText: '例如: https://music.example.com',
                      prefixIcon: const Icon(Icons.link),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入服务器地址';
                      }
                      if (!value.startsWith('http://') && !value.startsWith('https://')) {
                        return '服务器地址必须以http://或https://开头';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 用户名
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '用户名',
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 密码
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      hintText: _isEditMode ? '(保持不变)' : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    obscureText: true,
                    validator: (value) {
                      // 编辑模式下可以为空，表示保持原密码不变
                      if (!_isEditMode && (value == null || value.isEmpty)) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 认证方式
                  SwitchListTile(
                    title: const Text('使用旧版认证方式'),
                    subtitle: const Text('某些旧版Subsonic服务器需要使用旧版认证'),
                    value: _isLegacyAuth,
                    onChanged: (value) {
                      setState(() {
                        _isLegacyAuth = value;
                      });
                    },
                    secondary: Icon(
                      Icons.security,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 错误信息
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 测试连接按钮
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('测试连接'),
                        onPressed: _isLoading ? null : _testConnection,
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 保存设置按钮
                      FilledButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: const Text('保存设置'),
                        onPressed: _isLoading ? null : _saveSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 预缓冲设置卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '播放设置',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                
                // 启用预缓冲开关
                SwitchListTile(
                  title: const Text('启用云音乐预缓冲'),
                  subtitle: const Text('预先加载和缓冲即将播放的歌曲，减少切换时的加载延迟'),
                  value: _enablePreBuffer,
                  onChanged: (value) {
                    setState(() {
                      _enablePreBuffer = value;
                    });
                    audioPlayerService.setCloudMusicPreBuffer(value);
                  },
                ),
                
                const SizedBox(height: 8),
                
                // 预缓冲数量滑块
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text('预缓冲歌曲数量'),
                      ),
                      Expanded(
                        flex: 3,
                        child: Slider(
                          value: _preBufferCount.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _preBufferCount.toString(),
                          onChanged: _enablePreBuffer
                              ? (value) {
                                  setState(() {
                                    _preBufferCount = value.toInt();
                                  });
                                  audioPlayerService.setPreBufferCount(value.toInt());
                                }
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$_preBufferCount',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '预缓冲数量越大，播放体验越流畅，但会消耗更多网络流量和内存',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 下载路径设置
                Text(
                  '下载设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 使用自定义下载路径
                SwitchListTile(
                  title: const Text('使用自定义下载路径'),
                  subtitle: const Text('默认将使用系统临时目录保存下载的云音乐'),
                  value: _isCustomDownloadPath,
                  onChanged: (value) {
                    setState(() {
                      _isCustomDownloadPath = value;
                      if (!value) {
                        _downloadPath = '';
                        // 更新设置
                        Provider.of<SettingsService>(context, listen: false)
                          .updateCloudMusicDownloadPath('');
                      }
                    });
                  },
                ),
                
                // 下载路径选择器
                if (_isCustomDownloadPath)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _downloadPath.isEmpty ? '未选择下载路径' : _downloadPath,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _selectDownloadPath,
                          child: const Text('选择目录'),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // 缓存管理
                ListTile(
                  title: const Text('清除云音乐缓存'),
                  subtitle: const Text('删除所有已下载的云音乐歌曲缓存'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      _showClearCacheDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 显示清除缓存确认对话框
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清除云音乐缓存'),
          content: const Text('确定要清除所有已下载的云音乐缓存吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _clearCache();
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
  
  // 清除缓存
  Future<void> _clearCache() async {
    try {
      // 使用缓存管理器清除云音乐缓存
      await MusicCacheManager().clearCloudMusicCache();
      
      // 刷新音频播放器服务中的缓存记录
      final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);
      audioPlayerService.clearCloudMusicCache();
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('云音乐缓存已清除'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除缓存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectDownloadPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _downloadPath = selectedDirectory;
        _isCustomDownloadPath = true;
        Provider.of<SettingsService>(context, listen: false)
          .updateCloudMusicDownloadPath(_downloadPath);
      });
    }
  }
}

// 关于设置标签页
class AboutSettingsTab extends StatelessWidget {
  const AboutSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = Provider.of<UpdateService>(context);
    final version = updateService.currentVersion;
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 应用信息卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '应用信息',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  context, 
                  label: '应用名称', 
                  value: 'Slahser Player',
                ),
                _buildInfoItem(
                  context, 
                  label: '版本', 
                  value: version != null ? '${version.version} (${version.buildNumber})' : '未知',
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 关于卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关于',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Slahser Player 是一款功能强大的本地音乐播放器，支持多种音频格式，支持歌词显示，专辑封面显示等功能。'
                  '同时还支持通过Subsonic协议连接到远程音乐服务器，让您的音乐随时随地可用。',
                ),
                const SizedBox(height: 16),
                const Text(
                  '本应用使用Flutter框架开发，遵循Material Design 3设计规范。',
                ),
                const SizedBox(height: 16),
                // 添加捐赠按钮
                FilledButton.icon(
                  icon: const Icon(Icons.coffee),
                  label: const Text('请Slahser喝咖啡'),
                  onPressed: () {
                    _showDonationDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 检查更新卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '检查更新',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        updateService.updateAvailable
                            ? '有新版本可用: ${updateService.latestVersion?.version}'
                            : updateService.lastChecked != null
                                ? '已是最新版本 (上次检查: ${_formatDate(updateService.lastChecked!)})'
                                : '未检查更新',
                      ),
                    ),
                    FilledButton.icon(
                      icon: updateService.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(updateService.isChecking ? '检查中...' : '检查更新'),
                      onPressed: updateService.isChecking
                          ? null
                          : () {
                              updateService.checkForUpdates();
                            },
                    ),
                  ],
                ),
                if (updateService.updateAvailable && updateService.latestVersion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('GitHub下载'),
                            onPressed: () {
                              updateService.downloadUpdate();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cloud_download),
                            label: const Text('蓝奏云下载(密码:c5z0)'),
                            onPressed: () async {
                              final lanZouUrl = 'https://wwb.lanzoum.com/b002uuo6ed';
                              try {
                                await launchUrl(Uri.parse(lanZouUrl));
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('无法打开链接，请手动复制网址')),
                                  );
                                }
                              }
                            },
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

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} 分钟前';
      }
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }

  // 显示捐赠对话框
  static void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('请开发者喝咖啡'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('感谢您对Slahser Player的支持！'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('支付宝'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/zfb.jpg',
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('微信'),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/wx.jpg',
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
} 