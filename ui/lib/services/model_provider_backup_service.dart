import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../utils/picked_attachment_metadata.dart';
import 'model_provider_config_service.dart';
import 'omnibot_resource_service.dart';

/// 模型服务商 Key 备份 / 恢复的结果摘要。
class ModelProviderBackupResult {
  const ModelProviderBackupResult({
    this.added = 0,
    this.updated = 0,
    this.failed = 0,
    this.filePath,
    this.message,
    this.cancelled = false,
  });

  final int added;
  final int updated;
  final int failed;
  final String? filePath;
  final String? message;
  final bool cancelled;
}

/// 模型服务商 Key 的备份与恢复。
///
/// 复用现有 provider profile 通道（listProfiles / saveProfile），导入与手动配置
/// 走同一条写入路径，因此不直接触碰原生侧的加密 Key 存储。
class ModelProviderBackupService {
  const ModelProviderBackupService._();

  static const String backupSchema = 'omnibot.model-provider-backup';
  static const int backupSchemaVersion = 1;

  /// 生成备份 JSON（含明文 apiKey，仅导出可写的自定义服务商）。
  static Future<String> buildBackupJson() async {
    final payload = await ModelProviderConfigService.listProfiles();
    final profiles = <Map<String, dynamic>>[];
    for (final profile in payload.profiles) {
      if (profile.readOnly) {
        continue;
      }
      profiles.add(<String, dynamic>{
        'id': profile.id,
        'name': profile.name,
        'baseUrl': profile.baseUrl,
        'apiKey': profile.apiKey,
        'customHeaders': profile.customHeaders,
        'sourceType': profile.sourceType,
        'protocolType': profile.protocolType,
        'wireApi': profile.wireApi,
      });
    }
    return JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'schema': backupSchema,
      'schemaVersion': backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profileCount': profiles.length,
      'profiles': profiles,
    });
  }

  /// 一键导出：写入 workspace 备份目录，同时唤起系统分享面板。
  static Future<ModelProviderBackupResult> exportBackup() async {
    final json = await buildBackupJson();
    String? filePath;
    try {
      final paths = await OmnibotResourceService.ensureWorkspacePathsLoaded();
      final dir = Directory('${paths.rootPath}/backups');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('${dir.path}/key-backup-${_timestamp()}.json');
      file.writeAsStringSync(json, flush: true);
      filePath = file.path;
    } catch (_) {
      filePath = null;
    }
    await OmnibotResourceService.shareText(json);
    return ModelProviderBackupResult(filePath: filePath);
  }

  /// 选择备份文件并导入。
  static Future<ModelProviderBackupResult> importFromPickedFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) {
      return const ModelProviderBackupResult(cancelled: true);
    }
    final file = files.first;
    // 复用附件选择的同一套解析：优先本地路径，其次 SAF content:// URI。
    final metadata = pickedAttachmentMetadata(file);
    final path = metadata?.path.trim() ?? '';
    if (path.isEmpty) {
      return const ModelProviderBackupResult(message: '无法读取所选文件');
    }
    String raw;
    try {
      raw = path.startsWith('content://')
          ? utf8.decode(await file.readAsBytes())
          : File(path).readAsStringSync();
    } catch (error) {
      return ModelProviderBackupResult(message: '读取备份文件失败：$error');
    }
    return importBackupJson(raw);
  }

  /// 应用备份 JSON。同名服务商覆盖更新，新服务商追加。
  static Future<ModelProviderBackupResult> importBackupJson(String raw) async {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const ModelProviderBackupResult(message: '备份文件不是合法的 JSON');
    }
    if (decoded is! Map) {
      return const ModelProviderBackupResult(message: '备份文件格式不正确');
    }
    final root = Map<String, dynamic>.from(decoded);
    if (root['schema'] != backupSchema) {
      return const ModelProviderBackupResult(message: '这不是本应用的 Key 备份文件');
    }
    final entries = root['profiles'];
    if (entries is! List || entries.isEmpty) {
      return const ModelProviderBackupResult(message: '备份文件里没有可导入的 Key');
    }

    final existing = await ModelProviderConfigService.listProfiles();
    final idByName = <String, String>{};
    for (final profile in existing.profiles) {
      if (profile.readOnly) {
        continue;
      }
      final key = profile.name.trim().toLowerCase();
      if (key.isNotEmpty) {
        idByName[key] = profile.id;
      }
    }

    var added = 0;
    var updated = 0;
    var failed = 0;
    final failures = <String>[];

    for (final entry in entries) {
      if (entry is! Map) {
        failed += 1;
        continue;
      }
      final item = Map<String, dynamic>.from(entry);
      final name = (item['name'] ?? '').toString().trim();
      final baseUrl = (item['baseUrl'] ?? '').toString().trim();
      if (name.isEmpty) {
        failed += 1;
        continue;
      }
      final apiKey = (item['apiKey'] ?? '').toString().trim();
      final matchedId = idByName[name.toLowerCase()];
      try {
        await ModelProviderConfigService.saveProfile(
          id: matchedId,
          name: name,
          baseUrl: baseUrl,
          apiKey: apiKey.isEmpty ? null : apiKey,
          customHeaders: _readHeaders(item['customHeaders']),
          sourceType: (item['sourceType'] ?? 'custom').toString(),
          protocolType: (item['protocolType'] ?? 'openai_compatible').toString(),
          wireApi: _readWireApi(item['wireApi']),
        );
        if (matchedId == null) {
          added += 1;
        } else {
          updated += 1;
        }
      } catch (_) {
        failed += 1;
        failures.add(name);
      }
    }

    final summary = '导入完成：新增 $added 个，更新 $updated 个';
    return ModelProviderBackupResult(
      added: added,
      updated: updated,
      failed: failed,
      message: failures.isEmpty
          ? summary
          : '$summary，失败 ${failures.length} 个（${failures.join('、')}）',
    );
  }

  static Map<String, String>? _readHeaders(Object? value) {
    if (value is! Map) {
      return null;
    }
    final headers = <String, String>{};
    value.forEach((key, item) {
      final name = key.toString().trim();
      if (name.isEmpty) {
        return;
      }
      headers[name] = item.toString();
    });
    return headers.isEmpty ? null : headers;
  }

  static String? _readWireApi(Object? value) {
    final wireApi = (value ?? '').toString().trim();
    return wireApi.isEmpty ? null : wireApi;
  }

  static String _timestamp() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${pad(now.month)}${pad(now.day)}'
        '-${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
  }
}
