import 'package:everyemail/core/config/app_config.dart';
import 'package:everyemail/data/settings/worker_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Worker 设置默认使用内置 URL', () async {
    final settings = await WorkerSettingsStore.read();

    expect(settings.workerBaseUrl, AppConfig.defaultWorkerBaseUrl);
  });

  test('Worker URL 会归一化并持久化', () async {
    await WorkerSettingsStore.write(
      const WorkerSettings(workerBaseUrl: ' https://example.com/hooks/ '),
    );

    final settings = await WorkerSettingsStore.read();

    expect(settings.workerBaseUrl, 'https://example.com/hooks');
  });

  test('无效 Worker URL 会回退默认值', () async {
    SharedPreferences.setMockInitialValues({'worker.baseUrl': 'not-a-url'});

    final settings = await WorkerSettingsStore.read();

    expect(settings.workerBaseUrl, AppConfig.defaultWorkerBaseUrl);
  });
}
