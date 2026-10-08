import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../utils/picked_attachment_metadata.dart';
import 'omnibot_resource_service.dart';

/// 聊天记录导出的结果摘要。
class ChatHistoryExportResult {
  const ChatHistoryExportResult({
    this.filePath,
    this.message,
    this.cancelled = false,
  });

  final String? filePath;
  final String? message;
  final bool cancelled;
}

/// 聊天记录导入的结果摘要。
class ChatHistoryImportResult {
  const ChatHistoryImportResult({
    this.conversationsImported = 0,
    this.entriesImported = 0,
    this.message,
    this.cancelled = false,
  });

  final int conversationsImported;
  final int entriesImported;
  final String? message;
  final bool cancelled;
}

/// 聊天记录（全量会话 + 消息条目）的备份与恢复。
///
/// 序列化 / 反序列化由原生侧 [ChatHistoryTransfer]（room 数据库）完成，
/// 这里只负责调用 channel、写 workspace 备份目录与唤起系统分享面板，
/// 文件选择沿用 file_picker（与 ModelProviderBackupService 一致）。
class ChatHistoryService {
  const ChatHistoryService._();

  static const MethodChannel _channel = MethodChannel(
    'cn.com.omnimind.bot/chat_history',
  );

  /// 让原生侧全量序列化并返回 JSON 字符串。
  static Future<String> buildBackupJson() async {
    final json = await _channel.invokeMethod<String>('exportChatHistoryJson');
    if (json == null || json.isEmpty) {
      throw Exception('原生返回空的聊天记录数据');
    }
    return json;
  }

  /// 一键导出：写入 workspace 备份目录，同时唤起系统分享面板。
  static Future<ChatHistoryExportResult> exportBackup() async {
    final json = await buildBackupJson();
    String? filePath;
    try {
      final paths = await OmnibotResourceService.ensureWorkspacePathsLoaded();
      final dir = Directory('${paths.rootPath}/backups');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/chat-history-${_timestamp()}.json');
      file.writeAsStringSync(json, flush: true);
      filePath = file.path;
    } catch (error) {
      filePath = null;
    }
    await OmnibotResourceService.shareText(json);
    return ChatHistoryExportResult(filePath: filePath);
  }

  /// 选择备份文件并追加导入。
  static Future<ChatHistoryImportResult> importFromPickedFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) {
      return const ChatHistoryImportResult(cancelled: true);
    }
    final file = files.first;
    // 复用附件选择的同一套解析：优先本地路径，其次 SAF content:// URI。
    final metadata = pickedAttachmentMetadata(file);
    final path = metadata?.path.trim() ?? '';
    if (path.isEmpty) {
      return const ChatHistoryImportResult(message: '无法读取所选文件');
    }
    String raw;
    try {
      raw = path.startsWith('content://')
          ? utf8.decode(await file.readAsBytes())
          : File(path).readAsStringSync();
    } catch (error) {
      return ChatHistoryImportResult(message: '读取备份文件失败：$error');
    }
    return importBackupJson(raw);
  }

  /// 把整份备份 JSON 交给原生侧导入。
  static Future<ChatHistoryImportResult> importBackupJson(String raw) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'importChatHistoryJson',
        {'json': raw},
      );
      final conversations =
          (result?['conversationsImported'] as num?)?.toInt() ?? 0;
      final entries = (result?['entriesImported'] as num?)?.toInt() ?? 0;
      return ChatHistoryImportResult(
        conversationsImported: conversations,
        entriesImported: entries,
        message: '导入完成：新增 $conversations 个会话，$entries 条消息',
      );
    } on PlatformException catch (e) {
      return ChatHistoryImportResult(message: '导入失败：${e.message ?? e.code}');
    } catch (e) {
      return ChatHistoryImportResult(message: '导入失败：$e');
    }
  }

  static String _timestamp() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${pad(now.month)}${pad(now.day)}'
        '-${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
  }
}