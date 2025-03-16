import 'package:flutter/material.dart';

/// 自定义页面过渡动画类型
enum PageTransitionType {
  /// 淡入淡出效果
  fade,
  
  /// 从右侧滑入
  slideRight,
  
  /// 从左侧滑入
  slideLeft,
  
  /// 从底部滑入
  slideUp,
  
  /// 从顶部滑入
  slideDown,
  
  /// 缩放效果
  scale,
  
  /// 旋转效果
  rotate,
  
  /// 缩放淡入淡出组合效果
  scaleFade,
}

/// 自定义页面过渡动画
class CustomPageTransition<T> extends PageRouteBuilder<T> {
  /// 目标页面
  final Widget page;
  
  /// 过渡动画类型
  final PageTransitionType type;
  
  /// 过渡动画持续时间
  final Duration duration;
  
  /// 反向动画持续时间
  final Duration reverseDuration;
  
  /// 动画曲线
  final Curve curve;
  
  /// 全屏显示
  final bool fullscreenDialog;
  
  /// 维持状态
  final bool maintainState;
  
  /// 边缘填充，决定背景如何显示
  final EdgeInsets fillEdges;
  
  /// 创建自定义页面过渡动画
  CustomPageTransition({
    required this.page,
    required this.type,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.fullscreenDialog = false,
    this.maintainState = true,
    this.fillEdges = EdgeInsets.zero,
    RouteSettings? settings,
    Object? arguments,
  }) : super(
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return page;
    },
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      switch (type) {
        case PageTransitionType.fade:
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        
        case PageTransitionType.slideRight:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          );
        
        case PageTransitionType.slideLeft:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          );
        
        case PageTransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          );
        
        case PageTransitionType.slideDown:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          );
        
        case PageTransitionType.scale:
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: curve,
            ),
            child: child,
          );
        
        case PageTransitionType.rotate:
          return RotationTransition(
            turns: CurvedAnimation(
              parent: animation,
              curve: curve,
            ),
            child: child,
          );
        
        case PageTransitionType.scaleFade:
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: curve,
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )),
              child: child,
            ),
          );
      }
    },
  );
}

/// 为歌词页面量身定制的过渡动画
class LyricsPageTransition extends PageRouteBuilder {
  final Widget page;
  
  LyricsPageTransition({
    required this.page,
    RouteSettings? settings,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    settings: settings,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 组合动画：淡入淡出 + 缩放
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInQuart,
          ),
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}

/// 主页导航过渡动画（切换内容区域时）
class ContentAreaTransition extends StatelessWidget {
  final Widget child;
  final bool appearing;
  final Duration duration;
  final Curve curve;

  const ContentAreaTransition({
    super.key,
    required this.child,
    this.appearing = true,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ),
      duration: duration,
      curve: curve,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(appearing ? 20.0 * (1.0 - value) : 0.0, 0.0),
            child: child,
          ),
        );
      },
    );
  }
} 