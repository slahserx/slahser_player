import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slahser_player/services/audio_player_service.dart';

class EqualizerDialog extends StatefulWidget {
  const EqualizerDialog({super.key});

  @override
  State<EqualizerDialog> createState() => _EqualizerDialogState();
}

class _EqualizerDialogState extends State<EqualizerDialog> {
  int _selectedPresetIndex = 0;
  bool _enableEqualizer = true;
  
  // 预设名称
  final List<String> _presets = [
    '默认',
    '流行',
    '摇滚',
    '电子',
    '古典',
    '爵士',
    '嘻哈',
    '声乐',
    '自定义',
  ];
  
  // 均衡器频段
  final List<String> _bands = [
    '31Hz',
    '62Hz',
    '125Hz',
    '250Hz',
    '500Hz',
    '1kHz',
    '2kHz',
    '4kHz',
    '8kHz',
    '16kHz',
  ];
  
  // 预设值
  final Map<String, List<double>> _presetValues = {
    '默认': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    '流行': [3, 2, 0, -1, -2, -1, 0, 2, 3, 3],
    '摇滚': [4, 3, 1, 0, -1, 0, 2, 3, 4, 3],
    '电子': [4, 3, 0, -2, -3, -2, 0, 2, 4, 5],
    '古典': [3, 2, 1, 1, 0, -1, -1, 0, 2, 3],
    '爵士': [2, 1, 0, 1, 2, 3, 2, 1, 2, 2],
    '嘻哈': [5, 4, 2, 0, -1, 0, 1, 2, 3, 3],
    '声乐': [-1, -2, -1, 1, 4, 3, 1, 0, -1, -2],
    '自定义': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  };
  
  List<double> _currentValues = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  
  @override
  void initState() {
    super.initState();
    // 初始化时加载当前均衡器设置
    final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
    _enableEqualizer = audioPlayer.isEqualizerEnabled;
    _currentValues = List.from(audioPlayer.equalizerValues);
    
    // 判断当前设置是否匹配任何预设
    bool matchesPreset = false;
    _presetValues.forEach((presetName, values) {
      if (listEquals(values, _currentValues)) {
        _selectedPresetIndex = _presets.indexOf(presetName);
        matchesPreset = true;
      }
    });
    
    if (!matchesPreset && _enableEqualizer) {
      _selectedPresetIndex = _presets.indexOf('自定义');
    }
  }
  
  bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.01) return false;
    }
    return true;
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '均衡器',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 启用均衡器开关
            SwitchListTile(
              title: Text(
                '启用均衡器',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              value: _enableEqualizer,
              onChanged: (value) {
                setState(() {
                  _enableEqualizer = value;
                });
                
                final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                audioPlayer.setEqualizerEnabled(value);
              },
              secondary: Icon(
                _enableEqualizer ? Icons.equalizer : Icons.equalizer_outlined,
                color: _enableEqualizer 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 预设选择
            Text(
              '预设',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_presets.length, (index) {
                final isSelected = _selectedPresetIndex == index;
                return ChoiceChip(
                  label: Text(_presets[index]),
                  selected: isSelected,
                  onSelected: _enableEqualizer ? (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPresetIndex = index;
                        _currentValues = List.from(_presetValues[_presets[index]]!);
                      });
                      
                      final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                      audioPlayer.setEqualizerValues(_currentValues);
                    }
                  } : null,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  labelStyle: TextStyle(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 24),
            
            // 均衡器滑块
            SizedBox(
              height: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_bands.length, (index) {
                  return _buildEqualizerSlider(
                    context, 
                    _bands[index], 
                    _currentValues[index], 
                    (value) {
                      setState(() {
                        _currentValues[index] = value;
                        // 如果手动调整了，切换到自定义预设
                        _selectedPresetIndex = _presets.indexOf('自定义');
                      });
                      
                      final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                      audioPlayer.setEqualizerValues(_currentValues);
                    },
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 重置按钮
            Center(
              child: TextButton(
                onPressed: _enableEqualizer ? () {
                  setState(() {
                    _selectedPresetIndex = 0; // 默认预设
                    _currentValues = List.from(_presetValues[_presets[0]]!);
                  });
                  
                  final audioPlayer = Provider.of<AudioPlayerService>(context, listen: false);
                  audioPlayer.setEqualizerValues(_currentValues);
                } : null,
                child: const Text('重置'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEqualizerSlider(
    BuildContext context,
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Text(
          '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}dB',
          style: TextStyle(
            fontSize: 12,
            color: value != 0 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: value != 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
                thumbColor: Theme.of(context).colorScheme.primary,
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: value,
                min: -12.0,
                max: 12.0,
                divisions: 24,
                onChanged: _enableEqualizer ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
} 