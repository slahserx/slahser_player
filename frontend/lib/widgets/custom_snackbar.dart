import 'package:flutter/material.dart';

/// 显示自定义Snackbar的工具类
class CustomSnackBar {
  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    if (!_isContextValid(context)) return;
    
    _show(
      context: context,
      message: message,
      icon: Icons.check_circle_outline,
      backgroundColor: Colors.green.shade800,
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示错误提示
  static void showError(BuildContext context, String message) {
    if (!_isContextValid(context)) return;
    
    _show(
      context: context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: Colors.red.shade800,
      duration: const Duration(seconds: 3),
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    if (!_isContextValid(context)) return;
    
    _show(
      context: context,
      message: message,
      icon: Icons.warning_amber,
      backgroundColor: Colors.orange.shade800,
      duration: const Duration(seconds: 3),
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message) {
    if (!_isContextValid(context)) return;
    
    _show(
      context: context,
      message: message,
      icon: Icons.info_outline,
      backgroundColor: Colors.blue.shade800,
      duration: const Duration(seconds: 2),
    );
  }
  
  /// 检查context是否有效
  static bool _isContextValid(BuildContext context) {
    // 检查context是否仍挂载
    return context.mounted;
  }

  /// 显示自定义Snackbar的内部方法
  static void _show({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
  }) {
    try {
      final ThemeData theme = Theme.of(context);
      
      // 确保有ScaffoldMessenger可用
      if (ScaffoldMessenger.maybeOf(context) == null) {
        debugPrint('无法显示SnackBar: 找不到ScaffoldMessenger');
        return;
      }

      // 创建一个更漂亮的SnackBar
      final snackBar = SnackBar(
        content: Row(
          children: [
            // 带有淡色背景的圆形图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // 消息文本
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        elevation: 8, // 增加阴影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        dismissDirection: DismissDirection.horizontal, // 水平滑动关闭
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {
            try {
              if (context.mounted && ScaffoldMessenger.maybeOf(context) != null) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }
            } catch (e) {
              debugPrint('关闭SnackBar时出错: $e');
            }
          },
        ),
      );

      // 显示SnackBar，并在显示新的SnackBar前先移除旧的
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(snackBar);
      }
    } catch (e) {
      debugPrint('显示SnackBar时出错: $e');
    }
  }
} 