# Slahser Player

一款本地和云端音乐播放器，使用 Flutter 开发。


## 安装
- [安装版 (.exe)](https://github.com/slahserx/slahser_player/releases/download/v0.9.5/slahser_player_setup_0.9.5.exe) - 推荐大多数用户使用
- [便携版 (.zip)](https://github.com/slahserx/slahser_player/releases/download/v0.9.5/slahser_player_0.9.5_portable.zip) - 无需安装，解压即用


## 技术栈
- 前端：Flutter (Windows Desktop)
- 音频处理：just_audio
- 数据库：SQLite (本地缓存)
- 云音乐：Subsonic API



## 项目结构

```
slahser_player/
├── frontend/                # Flutter前端代码
│   ├── lib/                 # Flutter源码目录
│   │   ├── enums/           # 枚举定义
│   │   ├── models/          # 数据模型
│   │   ├── pages/           # 页面组件
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

## 云音乐功能

Slahser Player 现在支持连接到 Subsonic 兼容的音乐服务器，包括:

- Navidrome
- Airsonic
- Gonic
- Subsonic
- LMS（带有 Subsonic 插件）

### 如何使用云音乐功能

1. 在侧边栏点击"云音乐"
2. 点击"前往设置"按钮，或在云音乐界面右上角的设置图标
3. 输入您的 Subsonic 服务器信息:
   - 服务器地址
   - 用户名
   - 密码
   - 认证方式（新版或旧版）
4. 点击"测试连接"确认连接成功
5. 保存设置后即可浏览和播放云端音乐


## 贡献指南

我们欢迎各种形式的贡献，无论是功能请求、bug报告还是代码贡献。请按照以下步骤提交您的贡献：

1. Fork 项目仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开一个 Pull Request

## 许可证

本项目采用 MIT 许可证 - 有关详细信息，请查看 LICENSE 文件。

