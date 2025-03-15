# Slahser Player

一个优雅的本地音乐播放器，使用 Flutter + Rust 开发。

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

### MVP 阶段（第一阶段）
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

### 后续规划
- [ ] 高级音频处理
  - 均衡器
  - 音效增强
- [ ] 歌词同步显示
- [ ] 播放列表导入导出
- [ ] 快捷键支持
- [ ] 迷你模式

## 开发计划

### 第一阶段：基础架构搭建
1. 创建 Flutter 和 Rust 项目
2. 实现基础 UI 布局
3. 搭建 FFI 通信层
4. 实现基础播放功能

### 第二阶段：核心功能开发
1. 音乐库管理
2. 播放列表功能
3. 元数据解析
4. 主题系统

### 第三阶段：功能完善
1. 高级音频处理
2. 歌词显示
3. 性能优化
4. 用户体验改进

## 开发环境要求
- Flutter SDK: 3.19.0 或更高
- Rust: 1.75.0 或更高
- Windows 10/11
- Visual Studio 2019 或更高（用于 Windows 开发）

## 构建和运行
```bash
# 安装依赖
flutter pub get
cd backend && cargo build

# 运行应用
flutter run -d windows
``` 