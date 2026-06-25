import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

class WorkerSettings {
  const WorkerSettings({required this.workerBaseUrl});

  static const defaults = WorkerSettings(
    workerBaseUrl: AppConfig.defaultWorkerBaseUrl,
  );

  final String workerBaseUrl;

  WorkerSettings copyWith({String? workerBaseUrl}) {
    return WorkerSettings(workerBaseUrl: workerBaseUrl ?? this.workerBaseUrl);
  }

  static String normalizeWorkerBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Worker URL 不能为空');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('请输入完整的 http 或 https URL');
    }

    final base = '${uri.scheme}://${uri.authority}';
    var normalized = '$base${uri.path}';
    while (normalized.length > base.length && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WorkerSettings && workerBaseUrl == other.workerBaseUrl;
  }

  @override
  int get hashCode => workerBaseUrl.hashCode;
}

class WorkerSettingsStore {
  const WorkerSettingsStore._();

  static const String _workerBaseUrlKey = 'worker.baseUrl';

  static Future<WorkerSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_workerBaseUrlKey);
    if (stored == null || stored.trim().isEmpty) {
      return WorkerSettings.defaults;
    }
    try {
      return WorkerSettings(
        workerBaseUrl: WorkerSettings.normalizeWorkerBaseUrl(stored),
      );
    } on FormatException {
      return WorkerSettings.defaults;
    }
  }

  static Future<void> write(WorkerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _workerBaseUrlKey,
      WorkerSettings.normalizeWorkerBaseUrl(settings.workerBaseUrl),
    );
  }
}
