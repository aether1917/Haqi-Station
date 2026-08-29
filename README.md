# 哈气站 (Haqi Station)

一个简洁的 Android 表情包管理应用，使用 Flutter 与 Material Design 3 构建。

## 功能

- 🖼️ **导入表情包**：支持图片（jpg / png / webp / bmp）与 GIF 动图，文件复制进应用私有目录，安全可靠
- 🎠 **网格浏览**：三列网格展示，GIF 自动播放，懒加载解码
- ↔️ **拖拽排序**：长按拖动调整表情包顺序，顺序自动保存
- 🗑️ **多选删除**：长按或点击右上角「选择」进入多选模式，右上角删除按钮批量删除
- 📤 **一键分享**：点击表情包进入详情页，调起系统分享面板发送给朋友
- 🌓 **深色模式**：默认白色亮色主题，支持跟随系统切换深色模式
- ⚙️ **更多页面**：内含「设置」（外观切换）与「关于」


## 构建环境

- Flutter (stable) ≥ 3.47
- JDK 17
- Android SDK（Platform 36 + Build-Tools 36）

## 构建步骤

```bash
flutter pub get
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`，编译完成后复制到 `out/`。

## 项目结构

```
lib/
├── main.dart                  # 应用入口与主题装配
├── theme.dart                 # MD3 明/暗两套配色
├── models/  (services/)
│   └── sticker_store.dart     # 表情包模型、文件存储、元数据持久化
├── services/
│   └── settings_service.dart  # 深色模式设置持久化
├── pages/
│   ├── home_page.dart         # 底部导航（表情包 / 更多）
│   ├── stickers_page.dart     # 表情包网格：导入 / 排序 / 多选删除
│   ├── sticker_detail_page.dart # 详情页：大图预览 + 分享
│   ├── more_page.dart         # 更多：设置 / 关于入口
│   ├── settings_page.dart     # 设置：外观切换
│   └── about_page.dart        # 关于
└── widgets/
    └── sticker_tile.dart      # 网格单元（选择遮罩 / GIF 徽标）
```

## License

[MIT](LICENSE)
