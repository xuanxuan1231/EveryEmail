import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/local/database/message_with_account.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<MessageWithAccount> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final results = await db.messageDao.searchMessages(query, limit: 100);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: '搜索邮件...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          style: theme.textTheme.bodyLarge,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            // 实时搜索（防抖）
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _performSearch(value);
              }
            });
          },
          onSubmitted: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _hasSearched = false;
                });
                _searchFocusNode.requestFocus();
              },
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // 正在搜索
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
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
    return _buildResults(theme);
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

  Widget _buildResults(ThemeData theme) {
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
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              final message = item.message;

              return GmailMobileMessageItem(
                message: message,
                onTap: () {
                  context.push('/message/${message.id}');
                },
                accountEmail: item.accountEmail,
                accountColor: item.accountColorValue != null
                    ? Color(item.accountColorValue!)
                    : null,
                showAccountLabel: true,
                onStarTap: () {
                  // TODO: 实现星标切换
                  debugPrint('切换星标: ${message.id}');
                },
                onLongPress: () {
                  // TODO: 实现长按选择
                  debugPrint('长按选择: ${message.id}');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
