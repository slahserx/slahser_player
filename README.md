# Slahser Player

一款本地音乐播放器，使用 Flutter + Rust 开发。


## 安装
- [安装版 (.exe)](https://github.com/slahserx/slahser_player/releases/download/v0.9.2/slahser_player_setup_0.9.2.exe) - 推荐大多数用户使用
- [便携版 (.zip)](https://github.com/slahserx/slahser_player/releases/download/v0.9.2/slahser_player_0.9.2_portable.zip) - 无需安装，解压即用


## 技术栈
- 前端：Flutter (Windows Desktop)
- 后端：Rust
- 通信：flutter_rust_bridge + Protobuf
- 音频处理：Symphonia + CPAL
- 数据库：SQLite


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

## 项目结构

```
slahser_player/
├── backend/                 # Rust后端代码
│   ├── src/                 # Rust源码目录
│   │   ├── audio/           # 音频处理相关代码
│   │   ├── db/              # 数据库操作相关代码
│   │   ├── frontend/        # 与前端通信相关代码
│   │   ├── metadata/        # 音频元数据处理代码
│   │   └── utils/           # 工具函数
│   ├── Cargo.toml           # Rust项目配置文件
│   └── Cargo.lock           # Rust依赖锁定文件
├── frontend/                # Flutter前端代码
│   ├── lib/                 # Flutter源码目录
│   │   ├── enums/           # 枚举定义
│   │   ├── models/          # 数据模型
│   │   ├── pages/           # 页面组件
│   │   ├── platform/        # 平台相关代码
│   │   ├── screens/         # 屏幕组件
│   │   ├── services/        # 服务层
│   │   ├── theme/           # 主题设置
│   │   ├── utils/           # 工具函数
│   │   └── widgets/         # UI组件
│   ├── assets/              # 静态资源
│   └── pubspec.yaml         # Flutter项目配置文件
├── styles/                  # 样式相关文件
└── release/                 # 发布相关文件和脚本
```

## 优化建议

### 性能优化
- 对大型文件和列表进行懒加载和虚拟化
- 优化图片加载和缓存机制
- 减少不必要的状态更新和重建
- 实现更高效的音频元数据解析

### 代码结构优化
- 重构大型Widget，分离为更小的组件
- 统一状态管理方案
- 优化错误处理流程
- 分离业务逻辑和UI逻辑

### 用户体验优化
- 添加更多自定义选项
- 实现快捷键支持
- 优化启动速度
- 完善歌词和封面显示

## 更新日志

### v0.9.1 (进行中)
- 优化项目结构，拆分大型组件
- 添加内存缓存机制，提高缓存效率
- 使用并行处理优化音乐文件导入和加载
- 减少UI重建，提高界面响应速度
- 修复封面加载和元数据解析中的问题

### v0.9.0
- 首次公开发布版本
- 实现基础播放控制功能
- 支持本地音乐库管理
- 添加基础歌词显示功能
- 支持播放列表管理

## 未来计划

### v1.0.0
- 实现均衡器功能
- 添加快捷键支持
- 优化歌词匹配和显示
- 添加迷你播放模式
- 支持播放列表导入/导出

### v1.1.0
- 添加音频可视化效果
- 支持在线歌词和元数据获取
- 添加更多主题和自定义选项
- 支持歌曲排序和高级搜索
- 优化大型音乐库的性能

## 贡献指南

我们欢迎各种形式的贡献，无论是功能请求、bug报告还是代码贡献。请按照以下步骤提交您的贡献：

1. Fork 项目仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开一个 Pull Request

## 许可证

本项目采用 MIT 许可证 - 有关详细信息，请查看 LICENSE 文件。

