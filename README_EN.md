<div align="right">

[简体中文](README.md) | English

</div>

# Haqi Station (哈气站)

A simple Android sticker manager built with Flutter and Material Design 3.

## Features

- 🖼️ **Import stickers** — images (jpg / png / webp / bmp) and animated GIFs; files are copied into the app's private storage for safety
- 🎠 **Grid browsing** — three-column grid with auto-playing GIFs and lazy decoding
- 🗂️ **Categories** — built-in "All / Uncategorized"; multi-select stickers to create a category (editable name), assign or remove them; long-press a category chip to delete it; drag-to-reorder still works while filtered
- ↔️ **Drag to reorder** — long-press and drag to rearrange stickers; order is saved automatically
- 🗑️ **Multi-select delete** — tap the "select" action in the top bar to batch delete
- 📤 **Quick sharing** — share a single sticker or a whole selection via the system share sheet (custom native share channel, compatible with WeChat / QQ permission handling on modern Android)
- 🎨 **Personalized themes** — dark mode follows the system; Material You dynamic color on Android 12+, or pick your own seed color with the built-in HSV picker (full light & dark palettes generated automatically)
- 🔄 **In-app updates** — checks Gitee first with GitHub as fallback; prompts on new releases and jumps straight to the APK download
- ⚙️ **Settings / About** — appearance & color settings, version info and repository links

## Requirements

- Flutter (stable) ≥ 3.47
- JDK 17
- Android SDK (Platform 36 + Build-Tools 36)

## Build

```bash
flutter pub get
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`; copy it into `out/` after building.

## Project structure

```
lib/
├── main.dart                      # App entry, theme & dynamic color wiring, startup update check
├── theme.dart                     # MD3 light/dark themes (accepts external color schemes)
├── services/
│   ├── sticker_store.dart         # Sticker model, file storage, metadata & category persistence
│   ├── settings_service.dart      # Appearance settings (theme mode / color mode / seed color)
│   ├── dynamic_scheme.dart        # Android 12+ wallpaper dynamic color → ColorScheme
│   ├── native_share.dart          # Native multi-file sharing (WeChat / QQ compatible)
│   └── update_service.dart        # Update check (Gitee primary / GitHub fallback)
├── pages/
│   ├── home_page.dart             # Bottom navigation (stickers / more)
│   ├── stickers_page.dart         # Sticker grid: category bar / import / reorder / multi-select
│   ├── sticker_detail_page.dart   # Detail page: full-screen preview + share
│   ├── more_page.dart             # More: settings / about entries
│   ├── settings_page.dart         # Settings: appearance & colors
│   └── about_page.dart            # About: version / check updates / repo link
└── widgets/
    ├── sticker_tile.dart          # Grid tile (selection mask / GIF badge)
    ├── color_picker.dart          # Seed color picker (preset swatches + HSV panel)
    └── update_dialog.dart         # "New version available" dialog
```

## License

[MIT](LICENSE)
