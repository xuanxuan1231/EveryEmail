import 'package:drift/native.dart';
import 'package:everyemail/app/app.dart';
import 'package:everyemail/app/providers.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/data/settings/app_font_settings.dart';
import 'package:everyemail/data/settings/display_settings.dart';
import 'package:everyemail/data/settings/worker_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首页渲染空状态', (WidgetTester tester) async {
    // 创建测试用的内存数据库
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          appFontProvider.overrideWith(
            (ref) => AppFontController(AppFont.system),
          ),
          displaySettingsProvider.overrideWith(
            (ref) => DisplaySettingsController(DisplaySettings.defaults),
          ),
          workerSettingsProvider.overrideWith(
            (ref) => WorkerSettingsController(WorkerSettings.defaults),
          ),
        ],
        child: const EveryMailApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎使用 EveryEmail'), findsOneWidget);
    expect(find.text('添加账户'), findsOneWidget);

    // 清理
    await testDb.close();
  });
}
