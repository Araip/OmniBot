import 'package:flutter/material.dart';

import 'package:ui/services/launcher_icon_service.dart';

/// 打开「外观与伪装」设置弹层。
Future<void> showAppearancePrivacySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AppearancePrivacySheet(),
  );
}

/// 桌面图标方案切换 + 伪装模式开关。
class AppearancePrivacySheet extends StatefulWidget {
  const AppearancePrivacySheet({super.key});

  @override
  State<AppearancePrivacySheet> createState() => _AppearancePrivacySheetState();
}

class _AppearancePrivacySheetState extends State<AppearancePrivacySheet> {
  LauncherIconVariant _current = LauncherIconVariant.purple;
  LauncherIconVariant _lastNormal = LauncherIconVariant.purple;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final variant = await LauncherIconService.current();
    if (!mounted) return;
    setState(() {
      _current = variant;
      if (variant != LauncherIconVariant.feedback) _lastNormal = variant;
    });
  }

  bool get _disguiseOn => _current == LauncherIconVariant.feedback;

  Future<void> _pick(LauncherIconVariant variant) async {
    if (_busy || variant == _current) return;
    setState(() => _busy = true);
    final ok = await LauncherIconService.apply(variant);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _current = variant;
        if (variant != LauncherIconVariant.feedback) _lastNormal = variant;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? variant == LauncherIconVariant.feedback
                    ? '已开启伪装：桌面显示为系统「反馈」'
                    : '桌面图标已切换为「${variant.label}」，桌面稍后自动刷新'
              : '切换失败，请重试',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final titleColor = brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);
    final hintColor = brightness == Brightness.dark
        ? const Color(0xFF9BA1AA)
        : const Color(0xFF8A8F98);
    final cardColor = brightness == Brightness.dark
        ? const Color(0xFF23252A)
        : const Color(0xFFF4F5F8);
    final accent = brightness == Brightness.dark
        ? const Color(0xFF9DB6FF)
        : const Color(0xFF322C76);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '外观与伪装',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '桌面图标只是换个样子，App 内的功能与数据不受影响。',
              style: TextStyle(fontSize: 12.5, color: hintColor, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: LauncherIconVariant.selectable
                  .map(
                    (variant) => _IconPreview(
                      variant: variant,
                      selected: !_disguiseOn && variant == _current,
                      accent: accent,
                      labelColor: hintColor,
                      onTap: _busy ? null : () => _pick(variant),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const _BubbleMark(
                    size: 34,
                    glyph: '!',
                    glyphColor: Color(0xFF3E7BFA),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '伪装模式',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '桌面图标与名称显示为系统「反馈」，打开后是反馈界面；'
                          '长按该界面右上角可回到小程主页。',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: hintColor,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _disguiseOn,
                    onChanged: _busy
                        ? null
                        : (on) => _pick(
                            on
                                ? LauncherIconVariant.feedback
                                : _lastNormal,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面图标预览：圆角底色 + 白色气泡（与小程图标同构）。
class _IconPreview extends StatelessWidget {
  const _IconPreview({
    required this.variant,
    required this.selected,
    required this.accent,
    required this.labelColor,
    this.onTap,
  });

  final LauncherIconVariant variant;
  final bool selected;
  final Color accent;
  final Color labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Color(variant.background),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? accent : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: const Center(
              child: _BubbleMark(size: 44),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            variant.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accent : labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 小尺寸气泡图形：带 [glyph] 时显示感叹号，否则显示金色四角星 + 三点。
class _BubbleMark extends StatelessWidget {
  const _BubbleMark({required this.size, this.glyph, this.glyphColor});

  final double size;
  final String? glyph;
  final Color? glyphColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Center(
        child: glyph != null
            ? Text(
                glyph!,
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w800,
                  color: glyphColor ?? Colors.black,
                  height: 1,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome,
                    size: size * 0.3,
                    color: const Color(0xFFFED44F),
                  ),
                  SizedBox(height: size * 0.02),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(
                      3,
                      (_) => Container(
                        width: size * 0.07,
                        height: size * 0.07,
                        margin: EdgeInsets.symmetric(
                          horizontal: size * 0.022,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2B2B3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
