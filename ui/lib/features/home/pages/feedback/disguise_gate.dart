import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ui/services/launcher_icon_service.dart';

/// 伪装闸门。
///
/// 当桌面图标方案为「反馈」时，整个 App 界面会被替换为仿系统反馈页；
/// 在该页面长按右上角即可解锁并进入小程主页。
class DisguiseGate extends StatefulWidget {
  const DisguiseGate({super.key, required this.child});

  final Widget child;

  @override
  State<DisguiseGate> createState() => _DisguiseGateState();
}

class _DisguiseGateState extends State<DisguiseGate> {
  bool _resolved = false;
  bool _disguised = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final variant = await LauncherIconService.current();
    if (!mounted) return;
    setState(() {
      _disguised = variant == LauncherIconVariant.feedback;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 伪装界面是浅色的，固定用深色系统栏图标，避免深色主题下状态栏看不见。
    const overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF5F6F8),
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    if (!_resolved) {
      // 首帧短暂占位：避免伪装设备在读到状态前闪出真实界面。
      return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: ColoredBox(color: Color(0xFFF5F6F8)),
      );
    }
    if (_disguised && !_unlocked) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: FakeFeedbackPage(
          onUnlock: () => setState(() => _unlocked = true),
        ),
      );
    }
    return widget.child;
  }
}

/// 仿系统「用户反馈」界面。长按右上角热区进入小程主页。
class FakeFeedbackPage extends StatefulWidget {
  const FakeFeedbackPage({super.key, required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  State<FakeFeedbackPage> createState() => _FakeFeedbackPageState();
}

class _FakeFeedbackPageState extends State<FakeFeedbackPage> {
  static const List<String> _categories = <String>[
    '功能异常',
    '界面显示',
    '耗电发热',
    '系统卡顿',
    '其他',
  ];

  static const List<List<String>> _faq = <List<String>>[
    <String>[
      '系统更新后耗电变快怎么办？',
      '建议关闭后台自启动，或在夜间充电时完成一次完整的省电优化。',
    ],
    <String>[
      '如何提交日志帮助定位问题？',
      '进入「设置 - 关于本机 - 反馈日志」即可一键上传，日志仅用于问题定位。',
    ],
    <String>[
      '反馈多久会被受理？',
      '工作日 9:00 - 18:00 提交的工单，一般在 1-2 个工作日内响应。',
    ],
  ];

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  int _categoryIndex = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    final messenger = ScaffoldMessenger.of(context);
    if (_descriptionController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先描述您遇到的问题')),
      );
      return;
    }
    final ticket = DateTime.now().millisecondsSinceEpoch % 1000000;
    messenger.showSnackBar(
      SnackBar(content: Text('反馈已提交，工单号 SF$ticket')),
    );
    _descriptionController.clear();
    _contactController.clear();
    setState(() => _categoryIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          '用户反馈',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: <Widget>[
          // 隐藏入口：长按右上角进入小程主页（无任何可见内容）。
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: widget.onUnlock,
            child: const SizedBox(width: 64, height: kToolbarHeight),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: <Widget>[
          _card(
            child: const Text(
              '感谢您使用本机服务。请尽量详细地描述遇到的问题，'
              '我们会尽快核实并处理，带 * 的为必填项。',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFF6B6F76),
              ),
            ),
          ),
          _sectionTitle('问题类型 *'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(_categories.length, (index) {
              final selected = index == _categoryIndex;
              return GestureDetector(
                onTap: () => setState(() => _categoryIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE8F0FE) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF3E7BFA)
                          : const Color(0xFFE2E4E8),
                    ),
                  ),
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? const Color(0xFF3E7BFA)
                          : const Color(0xFF4A4D52),
                    ),
                  ),
                ),
              );
            }),
          ),
          _sectionTitle('问题描述 *'),
          _card(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _descriptionController,
              maxLines: 6,
              minLines: 5,
              maxLength: 500,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: '请描述问题出现的场景、操作步骤以及期望的结果…',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFA8ACB3)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA8ACB3),
                ),
              ),
            ),
          ),
          _sectionTitle('联系方式'),
          _card(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _contactController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '手机号 / 邮箱（选填，便于我们回访）',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFA8ACB3)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E7BFA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: const Text(
                '提交反馈',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _sectionTitle('常见问题'),
          for (final item in _faq)
            _card(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: const Color(0xFFA8ACB3),
                  collapsedIconColor: const Color(0xFFA8ACB3),
                  title: Text(
                    item[0],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  children: <Widget>[
                    Text(
                      item[1],
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF6B6F76),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              '工单受理时间：工作日 9:00 - 18:00',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFA8ACB3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A4D52),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: child,
    );
  }
}
