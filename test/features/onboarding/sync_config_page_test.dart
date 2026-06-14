import 'dart:async';

import 'package:drift/native.dart';
import 'package:everyemail/app/providers.dart';
import 'package:everyemail/data/auth/oauth_service.dart';
import 'package:everyemail/data/local/database/app_database.dart';
import 'package:everyemail/data/secure/token_store.dart';
import 'package:everyemail/data/sync/initial_sync_progress.dart';
import 'package:everyemail/data/sync/sync_service.dart';
import 'package:everyemail/domain/enums/account_enums.dart';
import 'package:everyemail/domain/models/account_config.dart';
import 'package:everyemail/features/onboarding/sync_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('同步中展示详细阶段、数量和动画百分比', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.accountDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'account-1',
        email: 'me@example.com',
        displayName: 'Me',
        accountType: AccountType.genericImap,
        authType: AuthType.password,
      ),
    );

    final syncService = _FakeSyncService(db);
    final router = GoRouter(
      initialLocation: '/sync',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/sync',
          builder: (context, state) => const SyncConfigPage(
            email: 'me@example.com',
            accountId: 'account-1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          syncServiceProvider.overrideWithValue(syncService),
        ],
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: true),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('开始同步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始同步'));
    await tester.pump();
    await syncService.started.future;
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('正在首次同步'), findsOneWidget);
    expect(find.text('正在保存最近的邮件'), findsOneWidget);
    expect(find.text('当前文件夹 收件箱 (1/3)'), findsOneWidget);
    expect(find.text('已获取 56 封'), findsOneWidget);
    expect(find.text('已保存 42 封'), findsOneWidget);
    expect(find.text('已更新 7 封'), findsOneWidget);
    expect(find.text('已移除 2 封'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);

    syncService.finish.complete();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}

class _FakeSyncService extends SyncService {
  _FakeSyncService(AppDatabase db)
    : super(db: db, tokenStore: TokenStore(), oauthService: OAuthService());

  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<void> syncAccountWithLimit(
    AccountConfig account,
    int messageLimit, {
    void Function(double progress)? onProgress,
    InitialSyncProgressCallback? onDetailedProgress,
  }) async {
    onProgress?.call(0.58);
    onDetailedProgress?.call(
      const InitialSyncProgress(
        stage: InitialSyncStage.savingMessages,
        progress: 0.58,
        currentFolderName: '收件箱',
        folderIndex: 1,
        folderCount: 3,
        fetchedMessages: 56,
        savedMessages: 42,
        updatedMessages: 7,
        removedMessages: 2,
        statusMessage: '正在保存最近的邮件',
      ),
    );
    started.complete();
    await finish.future;
  }
}
