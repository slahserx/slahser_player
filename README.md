# Slahser Player

一款本地音乐播放器，使用 Flutter + Rust 开发。

##安装
- [安装版 (.exe)](https://github.com/slahserx/slahser_player/releases/download/v0.8.0/slahser_player_setup_0.8.0.exe) - 推荐大多数用户使用
- [便携版 (.zip)](https://github.com/slahserx/slahser_player/releases/download/v0.8.0/slahser_player_0.8.0_portable.zip) - 无需安装，解压即用

## 项目架构

### 技术栈
- 前端：Flutter (Windows Desktop)
- 后端：Rust
- 通信：flutter_rust_bridge + Protobuf
- 音频处理：Symphonia + CPAL
- 数据库：SQLite

### 目录结构
```
slahser_player/
├── frontend/           # Flutter 前端项目
│   ├── lib/
│   │   ├── main.dart
│   │   ├── pages/     # 页面组件
│   │   ├── widgets/   # 可复用组件
│   │   ├── models/    # 数据模型
│   │   └── services/  # 服务层
│   └── pubspec.yaml
├── backend/           # Rust 后端项目
│   ├── src/
│   │   ├── main.rs
│   │   ├── audio/     # 音频处理模块
│   │   ├── metadata/  # 元数据解析
│   │   └── db/        # 数据库操作
│   └── Cargo.toml
└── shared/           # 共享代码
    └── protos/       # Protobuf 定义
```

## 功能特性


- [x] 基础播放功能
  - 播放/暂停
  - 上一曲/下一曲
  - 进度条控制
  - 音量调节
- [x] 音乐库管理
  - 本地音乐文件扫描
  - 播放列表创建
- [x] 基础界面
  - 无边框窗口
  - 深色/浅色主题
  - 响应式布局
- [ ] 高级音频处理
  - 均衡器
  - 音效增强
- [x] 歌词同步显示
- [ ] 播放列表导入导出
- [ ] 快捷键支持
- [ ] 迷你模式

