<div align="right">

简体中文 | [English](README_EN.md)

</div>

# 哈气站 (Haqi Station)

一个简洁的 Android 表情包管理应用，使用 Flutter 与 Material Design 3 构建。

## 功能

- 🖼️ **导入表情包**：支持图片（jpg / png / webp / bmp）与 GIF 动图，文件复制进应用私有目录，安全可靠
- 🎠 **网格浏览**：三列网格展示，GIF 自动播放，懒加载解码
- 🗂️ **分类管理**：默认「全部 / 未分类」，多选表情包可创建分类、归入或移出（弹窗内可编辑分类名）；长按分类栏标签可删除分类；分类过滤下依旧支持拖拽排序
- ↔️ **拖拽排序**：长按拖动调整表情包顺序，顺序自动保存
- 🗑️ **多选删除**：右上角「选择」进入多选模式，批量删除
- 📤 **快速分享**：单张或多选一次性调起系统分享面板（自建原生分享通道，兼容微信 / QQ 的高版本权限机制）
- 🎨 **个性主题**：深色模式跟随系统；支持 Android 12+ 壁纸动态取色（Material You），也可用内置取色器自选主题色，整套明暗配色自动生成
- 🔄 **检查更新**：以 Gitee 为主源、GitHub 兜底，发现新版本自动提醒，一键下载安装包
- ⚙️ **设置 / 关于**：外观与色彩设置、版本信息与仓库链接

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
├── main.dart                      # 应用入口、主题与动态取色装配、启动静默检查更新
├── theme.dart                     # MD3 明/暗主题（支持外部配色方案）
├── services/
│   ├── sticker_store.dart         # 表情包模型、文件存储、元数据与分类持久化
│   ├── settings_service.dart      # 外观设置（主题模式 / 色彩模式 / 主题色）
│   ├── dynamic_scheme.dart        # Android 12+ 壁纸动态取色 → ColorScheme
│   ├── native_share.dart          # 原生多文件分享（微信 / QQ 兼容）
│   └── update_service.dart        # 检查更新（Gitee 主源 / GitHub 兜底）
├── pages/
│   ├── home_page.dart             # 底部导航（表情包 / 更多）
│   ├── stickers_page.dart         # 表情包网格：分类栏 / 导入 / 排序 / 多选操作
│   ├── sticker_detail_page.dart   # 详情页：大图预览 + 分享
│   ├── more_page.dart             # 更多：设置 / 关于入口
│   ├── settings_page.dart         # 设置：外观与色彩
│   └── about_page.dart            # 关于：版本 / 检查更新 / 仓库链接
└── widgets/
    ├── sticker_tile.dart          # 网格单元（选择遮罩 / GIF 徽标）
    ├── color_picker.dart          # 主题色取色器（预设色板 + HSV 面板）
    └── update_dialog.dart         # 发现新版本弹窗
```

## License

[MIT](LICENSE)
