import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/providers.dart';
import '../../../core/platform/avatar_image_picker.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/settings/account_settings.dart';

/// 账户配色候选（ARGB）。账户设置页与「添加账户」向导共用，保证两处一致。
const List<int> kAccountColorValues = [
  0xFF1A73E8,
  0xFF0B8043,
  0xFF00838F,
  0xFF5E35B1,
  0xFFC2185B,
  0xFFB06000,
  0xFF5F6368,
  0xFFB3261E,
];

/// 头像预设图标条目。
class AvatarIconPreset {
  const AvatarIconPreset(this.id, this.icon, this.label);

  final String id;
  final IconData icon;
  final String label;
}

const List<AvatarIconPreset> kAvatarIconPresets = [
  AvatarIconPreset('person', Symbols.person_outline_rounded, '个人'),
  AvatarIconPreset('work', Symbols.work_outline_rounded, '工作'),
  AvatarIconPreset('business', Symbols.business_center, '商务'),
  AvatarIconPreset('group', Symbols.groups, '团队'),
  AvatarIconPreset('school', Symbols.school, '学习'),
  AvatarIconPreset('home', Symbols.home, '家庭'),
  AvatarIconPreset('code', Symbols.code_rounded, '开发'),
  AvatarIconPreset('shopping', Symbols.shopping_bag, '购物'),
  AvatarIconPreset('flight', Symbols.flight_takeoff_rounded, '旅行'),
  AvatarIconPreset('star', Symbols.star_border_rounded, '星标'),
  AvatarIconPreset('favorite', Symbols.favorite_border_rounded, '关注'),
  AvatarIconPreset('folder', Symbols.folder, '文件夹'),
];

/// 按 id 查头像预设图标，找不到（含 id 为空）返回 null。
AvatarIconPreset? avatarIconPreset(String? iconId) {
  if (iconId == null) return null;
  for (final preset in kAvatarIconPresets) {
    if (preset.id == iconId) return preset;
  }
  return null;
}

/// 账户头像：按 [AccountSettings] 渲染文字/图标/图片三种模式，缺省回退到名称首字母。
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    required this.account,
    this.settings,
    this.radius = 22,
    super.key,
  });

  final Account account;
  final AccountSettings? settings;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = account.colorValue == null
        ? colors.primary
        : Color(account.colorValue!);
    final mode = settings?.avatarMode ?? AccountAvatarMode.text;
    final onColor = _onColor(color);

    if (mode == AccountAvatarMode.image &&
        settings?.avatarImagePath?.isNotEmpty == true) {
      final size = radius * 2;
      return ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: Image.file(
            File(settings!.avatarImagePath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _fallbackAvatar(color, onColor);
            },
          ),
        ),
      );
    }

    final preset = mode == AccountAvatarMode.icon
        ? avatarIconPreset(settings?.avatarIconId)
        : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: preset == null
          ? Text(
              _initial,
              style: TextStyle(
                color: onColor,
                fontSize: radius < 24 ? 14 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          : Icon(preset.icon, color: onColor, size: radius < 24 ? 20 : 30),
    );
  }

  Widget _fallbackAvatar(Color color, Color onColor) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _initial,
        style: TextStyle(
          color: onColor,
          fontSize: radius < 24 ? 14 : 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String get _initial {
    final custom = settings?.avatarText?.trim();
    if (custom != null && custom.isNotEmpty) {
      return String.fromCharCodes(custom.runes.take(2)).toUpperCase();
    }
    final displayName = account.displayName.trim();
    if (displayName.isNotEmpty) {
      return displayName.characters.first.toUpperCase();
    }
    final email = account.email.trim();
    if (email.isNotEmpty) return email.characters.first.toUpperCase();
    return '?';
  }

  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

/// 账户配色选择圆点（选中态描边 + 勾选）。
class AccountColorDot extends StatelessWidget {
  const AccountColorDot({
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected ? colors.onSurface : colors.outlineVariant,
            ),
          ),
          child: selected
              ? Icon(Symbols.check_rounded, color: _onColor(color))
              : null,
        ),
      ),
    );
  }

  Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

/// 头像图标选择按钮（用于头像编辑弹窗的图标网格）。
class AvatarIconChoiceButton extends StatelessWidget {
  const AvatarIconChoiceButton({
    required this.preset,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AvatarIconPreset preset;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: preset.label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: selected ? 3 : 1,
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(preset.icon, color: color),
              if (selected)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Symbols.check_circle_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出头像编辑底部弹窗（文字/图标/图片三模式，自行持久化到
/// [accountSettingsProvider]）。账户设置页与「添加账户」向导共用。
Future<void> showAccountAvatarSheet(
  BuildContext context, {
  required Account account,
  required AccountSettings settings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) =>
        AvatarEditorSheet(account: account, settings: settings),
  );
}

/// 头像编辑底部弹窗。文字/图标/图片三模式实时预览，保存写入
/// [accountSettingsProvider]。
class AvatarEditorSheet extends ConsumerStatefulWidget {
  const AvatarEditorSheet({
    required this.account,
    required this.settings,
    super.key,
  });

  final Account account;
  final AccountSettings settings;

  @override
  ConsumerState<AvatarEditorSheet> createState() => _AvatarEditorSheetState();
}

class _AvatarEditorSheetState extends ConsumerState<AvatarEditorSheet>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late AccountAvatarMode _mode;
  late String _iconId;
  String? _imagePath;
  Timer? _keyboardInsetTimer;
  double _keyboardInset = 0;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.settings.avatarMode;
    _controller = TextEditingController(text: widget.settings.avatarText ?? '');
    _controller.addListener(_handleTextChanged);
    _iconId = _validIconId(widget.settings.avatarIconId);
    _imagePath = widget.settings.avatarImagePath;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardInsetTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _keyboardInsetTimer ??= Timer(
      const Duration(milliseconds: 48),
      _updateKeyboardInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: _keyboardInset),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '头像',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<AccountAvatarMode>(
              segments: const [
                ButtonSegment(
                  value: AccountAvatarMode.text,
                  icon: Icon(Symbols.text_fields_rounded),
                  label: Text('文字'),
                ),
                ButtonSegment(
                  value: AccountAvatarMode.icon,
                  icon: Icon(Symbols.emoji_emotions),
                  label: Text('图标'),
                ),
                ButtonSegment(
                  value: AccountAvatarMode.image,
                  icon: Icon(Symbols.image),
                  label: Text('图片'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.single;
                  if (_mode == AccountAvatarMode.icon) {
                    _iconId = _validIconId(_iconId);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            Material(
              color: colors.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildEditorContent(context, colors),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isPickingImage
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isPickingImage ? null : _save,
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorContent(BuildContext context, ColorScheme colors) {
    return switch (_mode) {
      AccountAvatarMode.text => _buildTextEditor(colors),
      AccountAvatarMode.icon => _buildIconEditor(colors),
      AccountAvatarMode.image => _buildImageEditor(context, colors),
    };
  }

  Widget _buildTextEditor(ColorScheme colors) {
    return Column(
      key: const ValueKey(AccountAvatarMode.text),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AccountAvatar(
            account: widget.account,
            settings: _previewSettings,
            radius: 36,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLength: 2,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: '头像文字'),
          onSubmitted: (_) {
            unawaited(_save());
          },
        ),
      ],
    );
  }

  Widget _buildIconEditor(ColorScheme colors) {
    return Wrap(
      key: const ValueKey(AccountAvatarMode.icon),
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final preset in kAvatarIconPresets)
          AvatarIconChoiceButton(
            preset: preset,
            color: colors.secondary,
            selected: _iconId == preset.id,
            onTap: () {
              setState(() {
                _iconId = preset.id;
              });
            },
          ),
      ],
    );
  }

  Widget _buildImageEditor(BuildContext context, ColorScheme colors) {
    return Row(
      key: const ValueKey(AccountAvatarMode.image),
      children: [
        AccountAvatar(
          account: widget.account,
          settings: _previewSettings,
          radius: 36,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isPickingImage ? null : _pickImage,
            icon: _isPickingImage
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : const Icon(Symbols.image),
            label: Text(_imagePath == null ? '选择图片' : '更换图片'),
          ),
        ),
      ],
    );
  }

  AccountSettings get _previewSettings {
    return widget.settings.copyWith(
      avatarMode: _mode,
      avatarText: _controller.text,
      avatarIconId: _iconId,
      avatarImagePath: _imagePath,
    );
  }

  void _handleTextChanged() {
    if (_mode == AccountAvatarMode.text) {
      setState(() {});
    }
  }

  void _updateKeyboardInset() {
    _keyboardInsetTimer = null;
    if (!mounted) return;

    final view = View.of(context);
    final nextInset = view.viewInsets.bottom / view.devicePixelRatio;
    if ((_keyboardInset - nextInset).abs() < 1) return;

    setState(() {
      _keyboardInset = nextInset;
    });
  }

  Future<void> _pickImage() async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final path = await AvatarImagePicker.pickAccountAvatarImage(
        widget.account.id,
      );
      if (!mounted) return;
      if (path != null) {
        setState(() {
          _imagePath = path;
          _mode = AccountAvatarMode.image;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像图片选择失败: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final controller = ref.read(
      accountSettingsProvider(widget.account.id).notifier,
    );

    switch (_mode) {
      case AccountAvatarMode.text:
        await controller.setAvatarText(_controller.text);
        break;
      case AccountAvatarMode.icon:
        await controller.setAvatarIcon(_validIconId(_iconId));
        break;
      case AccountAvatarMode.image:
        final imagePath = _imagePath;
        if (imagePath == null || imagePath.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请选择头像图片')));
          return;
        }
        await controller.setAvatarImagePath(imagePath);
        break;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _validIconId(String? iconId) {
    for (final preset in kAvatarIconPresets) {
      if (preset.id == iconId) return preset.id;
    }
    return kAvatarIconPresets.first.id;
  }
}
