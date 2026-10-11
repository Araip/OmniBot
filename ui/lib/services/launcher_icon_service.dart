import 'dart:async';

import 'package:flutter/services.dart';

/// 桌面图标方案（与原生 LauncherIconChannel 中的 variantId 一一对应）。
enum LauncherIconVariant {
  purple('purple', '品牌紫', 0xFF322C76),
  ink('ink', '石墨黑', 0xFF1B1B1F),
  ocean('ocean', '深海蓝', 0xFF123A63),
  feedback('feedback', '反馈', 0xFF3E7BFA);

  const LauncherIconVariant(this.id, this.label, this.background);

  final String id;
  final String label;
  final int background;

  /// 设置页里可选的三个正常图标方案（不含伪装方案）。
  static const List<LauncherIconVariant> selectable = <LauncherIconVariant>[
    purple,
    ink,
    ocean,
  ];

  static LauncherIconVariant fromId(String? id) {
    for (final variant in values) {
      if (variant.id == id) return variant;
    }
    return purple;
  }
}

/// 桌面图标切换：通过原生 activity-alias 实现，秒级生效（桌面刷新略慢）。
class LauncherIconService {
  LauncherIconService._();

  static const MethodChannel _channel = MethodChannel(
    'cn.com.omnimind.bot/launcher_icon',
  );

  /// 读取当前生效的图标方案；失败时按默认方案处理。
  static Future<LauncherIconVariant> current() async {
    try {
      final id = await _channel
          .invokeMethod<String>('getVariant')
          .timeout(const Duration(seconds: 2));
      return LauncherIconVariant.fromId(id);
    } catch (_) {
      return LauncherIconVariant.purple;
    }
  }

  /// 切换图标方案，返回是否成功。
  static Future<bool> apply(LauncherIconVariant variant) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('setVariant', <String, dynamic>{
            'variant': variant.id,
          })
          .timeout(const Duration(seconds: 3));
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
