/// 更新包内建下载器：双平台下载 + Android 下载进度通知 + 调起安装。
/// 下载在页面关闭后继续（异步任务），关闭时请求通知权限并发进度通知。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/l10n.dart';
import 'update_service.dart';

enum UpdateDownloadPhase { idle, downloading, done, failed }

class UpdateDownloadService extends ChangeNotifier {
  static final UpdateDownloadService instance = UpdateDownloadService._();

  UpdateDownloadService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _channel = const MethodChannel('com.haqi.station/share');
  bool _initialized = false;
  bool _pageClosed = false;

  UpdateDownloadPhase _phase = UpdateDownloadPhase.idle;
  UpdateDownloadPhase get phase => _phase;

  double _progress = 0; // 0..1；-1 表示不确定
  double get progress => _progress;

  String _received = '0 MB';
  String get received => _received;

  String _totalSize = '';
  String get totalSize => _totalSize;

  String? _filePath;
  String? get filePath => _filePath;

  /// 应用启动时初始化通知插件与点击回调。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'install') install();
      },
    );
  }

  /// 开始下载（已在下载中时为空操作）。
  Future<void> start(AppUpdate update) async {
    if (_phase == UpdateDownloadPhase.downloading) return;
    _pageClosed = false;
    _phase = UpdateDownloadPhase.downloading;
    _progress = 0;
    _received = '0 MB';
    _totalSize = '';
    _filePath = null;
    notifyListeners();
    try {
      if (Platform.isWindows && update.windowsUrl == null) {
        // 旧版 Release 没有 Windows 安装包资产（v1.8.0 之前是 zip），
        // 应用内无法完成安装器更新，直接置失败让用户手动下载。
        _phase = UpdateDownloadPhase.failed;
        notifyListeners();
        return;
      }
      final file = File(
          '${(await getTemporaryDirectory()).path}'
          '${Platform.isWindows ? '/haqi-station-setup.exe' : '/haqi-update.apk'}');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(update.downloadUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'haqi-station-app');
      final response = await request.close().timeout(UpdateService.timeout);
      if (response.statusCode != 200) {
        throw const HttpException('下载失败');
      }
      final total = response.contentLength;
      _totalSize = total > 0 ? _formatBytes(total) : '';
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        _progress =
            total > 0 ? (received / total).clamp(0.0, 1.0) : -1;
        _received = _formatBytes(received);
        notifyListeners();
        if (_pageClosed) {
          await _showProgressNotification();
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      _filePath = file.path;
      _phase = UpdateDownloadPhase.done;
      notifyListeners();
      if (Platform.isWindows) {
        await _runWindowsInstaller();
        return;
      }
      // 页面已关闭：通知「下载完成」并直接调起安装。
      if (_pageClosed) {
        await _showDoneNotification();
        await install();
      }
    } catch (_) {
      _phase = UpdateDownloadPhase.failed;
      notifyListeners();
    }
  }

  /// 更新页关闭时调用：请求通知权限（Android 13+），后续进度走通知。
  Future<void> onPageClosed() async {
    if (!Platform.isAndroid) return;
    if (_phase != UpdateDownloadPhase.downloading) return;
    _pageClosed = true;
    await Permission.notification.request();
  }

  /// 下载完成后调起系统安装器（Android）。
  Future<void> install() async {
    if (!Platform.isAndroid || _filePath == null) return;
    try {
      await _channel.invokeMethod<bool>(
          'installApk', {'path': _filePath});
    } on PlatformException {
      // 系统安装器调起失败（如未授权安装），忽略——用户可稍后重试。
    }
  }

  /// Windows：/SILENT 静默调起 Inno Setup 安装器（per-user 安装无需
  /// 管理员），稍候退出应用释放文件锁；安装器完成覆盖安装后自动重启。
  Future<void> _runWindowsInstaller() async {
    if (_filePath == null) return;
    var launched = true;
    try {
      await Process.start(
          _filePath!,
          const ['/SILENT', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS'],
          mode: ProcessStartMode.detached);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      _phase = UpdateDownloadPhase.failed;
      notifyListeners();
      return;
    }
    // 给安装器留出启动时间，再退出应用避免安装中被占用。
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    exit(0);
  }

  Future<void> _showProgressNotification() async {
    await _notifications.show(
      id: 1001,
      title: t('notificationDownloading'),
      body: '$_received${_totalSize.isNotEmpty ? ' / $_totalSize' : ''}',
      notificationDetails: _progressDetails(),
    );
  }

  Future<void> _showDoneNotification() async {
    await _notifications.show(
      id: 1001,
      title: t('notificationDone'),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'update_download',
          'update',
          channelDescription: 'update download progress',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        ),
      ),
      payload: 'install',
    );
  }

  NotificationDetails _progressDetails() {
    final pct = _progress >= 0 ? (_progress * 100).round() : 0;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'update_download',
        'update',
        channelDescription: 'update download progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        indeterminate: _progress < 0,
        maxProgress: 100,
        progress: pct,
        ongoing: true,
        onlyAlertOnce: true,
        autoCancel: false,
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
