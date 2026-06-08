import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

import '../../app/providers.dart';
import '../../core/navigation/predictive_back_shared_element.dart';
import '../../core/theme/mail_list_colors.dart';
import '../../data/local/database/message_with_account.dart';
import '../../data/settings/account_settings.dart';
import '../../data/settings/display_settings.dart';
import '../home/widgets/gmail_mobile_message_item.dart';

/// 邮件搜索页面。
///
/// 功能：
/// - 实时搜索（本地数据库）
/// - 搜索历史
/// - 搜索结果显示
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const Duration _searchDebounceDelay = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<MessageWithAccount> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _hasQuery = false;
  bool _resultsScrolledUnder = false;
  Timer? _searchDebounce;
  int _searchRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();
    final requestId = ++_searchRequestSerial;
    if (query.isEmpty) {
      setState(() {
        _hasQuery = false;
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
        _resultsScrolledUnder = false;
      });
      return;
    }

    if (!_hasQuery || _isSearching) {
      setState(() {
        _hasQuery = true;
        _isSearching = false;
      });
    }

    _searchDebounce = Timer(_searchDebounceDelay, () {
      _performSearch(query, requestId);
    });
  }

  Future<void> _performSearch(String query, int requestId) async {
    if (query.isEmpty || requestId != _searchRequestSerial) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final rawResults = await db.messageDao.searchMessages(query, limit: 100);
      final accountSettings = await AccountSettingsStore.readMany(
        rawResults.map((item) => item.accountId),
      );
      final results = [
        for (final item in rawResults)
          if ((accountSettings[item.accountId] ?? AccountSettings.defaults)
              .canSearchFolder(item.folderType))
            item,
      ];

      if (mounted && requestId == _searchRequestSerial) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _resultsScrolledUnder = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _searchRequestSerial) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displaySettings = ref.watch(displaySettingsProvider);
    final appBarScrolledUnder =
        !_isSearching &&
        _hasSearched &&
        _searchResults.isNotEmpty &&
        _resultsScrolledUnder;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarScrolledUnder
            ? mailListAppBarSurfaceColor(theme)
            : theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        shape: appBarScrolledUnder
            ? Border(
                bottom: BorderSide(color: mailListAppBarDividerColor(theme)),
              )
            : null,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: '搜索邮件...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: theme.textTheme.bodyLarge,
          textInputAction: TextInputAction.search,
          onChanged: _scheduleSearch,
          onSubmitted: (value) {
            _searchDebounce?.cancel();
            final query = value.trim();
            final requestId = ++_searchRequestSerial;
            if (query.isEmpty) {
              _scheduleSearch(query);
            } else {
              _performSearch(query, requestId);
            }
          },
        ),
        actions: [
          if (_hasQuery)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _scheduleSearch('');
                _searchFocusNode.requestFocus();
              },
            ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: _buildBody(theme, displaySettings),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final scrolledUnder = notification.metrics.extentBefore > 0.5;
    if (scrolledUnder != _resultsScrolledUnder) {
      setState(() {
        _resultsScrolledUnder = scrolledUnder;
      });
    }

    return false;
  }

  Widget _buildBody(ThemeData theme, DisplaySettings displaySettings) {
    // 正在搜索
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 未搜索
    if (!_hasSearched) {
      return _buildEmptyState(theme);
    }

    // 无结果
    if (_searchResults.isEmpty) {
      return _buildNoResults(theme);
    }

    // 显示结果
    return _buildResults(theme, displaySettings);
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '搜索邮件',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '按主题、发件人或内容搜索',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到结果',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用不同的关键词',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, DisplaySettings displaySettings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 结果数量
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '找到 ${_searchResults.length} 封邮件',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // 结果列表
        Expanded(
          child: M3ECardList.builder(
            itemCount: _searchResults.length,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            listPadding: const EdgeInsets.only(bottom: 24),
            padding: EdgeInsets.zero,
            gap: 3,
            outerRadius: 24,
            innerRadius: 4,
            color: mailListSurfaceColor(theme),
            physics: const AlwaysScrollableScrollPhysics(),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
            haptic: M3EHapticFeedback.light,
            semanticLabelBuilder: (index) {
              final item = _searchResults[index];
              return _messageSemanticLabel(item);
            },
            onTap: (index) {
              final message = _searchResults[index].message;
              context.push(
                '/message/${Uri.encodeComponent(message.id)}',
                extra: message,
              );
            },
            onLongPress: (index) {
              final message = _searchResults[index].message;
              // TODO: 实现长按选择
              debugPrint('长按选择: ${message.id}');
            },
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              final message = item.message;
              final accountColor = item.accountColorValue != null
                  ? Color(item.accountColorValue!)
                  : null;

              Widget buildPreview(BuildContext context) {
                return GmailMobileMessageCardContent(
                  message: message,
                  accountEmail: item.accountEmail,
                  accountColor: accountColor,
                  showAccountLabel: true,
                  displaySettings: displaySettings,
                );
              }

              return PredictiveBackSharedElementTarget(
                key: ValueKey(message.id),
                id: message.id,
                borderRadius: _messageCardBorderRadius(
                  index,
                  _searchResults.length,
                ),
                backgroundColor: mailListSurfaceColor(theme),
                previewBuilder: buildPreview,
                child: GmailMobileMessageCardContent(
                  message: message,
                  accountEmail: item.accountEmail,
                  accountColor: accountColor,
                  showAccountLabel: true,
                  displaySettings: displaySettings,
                  onStarTap: () {
                    // TODO: 实现星标切换
                    debugPrint('切换星标: ${message.id}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _messageSemanticLabel(MessageWithAccount item) {
    final message = item.message;
    final sender = message.fromName?.trim().isNotEmpty == true
        ? message.fromName!.trim()
        : message.fromEmail?.trim();
    final subject = message.subject.isEmpty ? '无主题' : message.subject;
    return '${sender ?? '未知发件人'}，$subject，账户 ${item.accountEmail}';
  }

  BorderRadius _messageCardBorderRadius(int index, int total) {
    const outerRadius = Radius.circular(24);
    const innerRadius = Radius.circular(4);

    if (total <= 1) {
      return const BorderRadius.all(outerRadius);
    }
    if (index == 0) {
      return const BorderRadius.vertical(top: outerRadius, bottom: innerRadius);
    }
    if (index == total - 1) {
      return const BorderRadius.vertical(top: innerRadius, bottom: outerRadius);
    }
    return const BorderRadius.all(innerRadius);
  }
}
