enum AgentSlashSubmitKind {
  none,
  openModelPicker,
  selectModel,
  startReview,
  startInit,
  togglePlan,
  startPlan,
  unsupported,
}

class AgentSlashSubmitIntent {
  const AgentSlashSubmitIntent(this.kind, {this.value});

  final AgentSlashSubmitKind kind;
  final String? value;
}

AgentSlashSubmitIntent resolveAgentSlashSubmitIntent(String messageText) {
  final trimmed = messageText.trim();
  if (!trimmed.startsWith('/')) {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.none);
  }

  final normalized = trimmed.toLowerCase();
  if (normalized == '/model') {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.openModelPicker);
  }
  if (normalized.startsWith('/model ')) {
    final modelId = trimmed.substring('/model'.length).trim();
    if (modelId.isEmpty) {
      return const AgentSlashSubmitIntent(AgentSlashSubmitKind.openModelPicker);
    }
    return AgentSlashSubmitIntent(
      AgentSlashSubmitKind.selectModel,
      value: modelId,
    );
  }

  if (normalized == '/review') {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.startReview);
  }
  if (normalized == '/init') {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.startInit);
  }
  if (normalized == '/plan') {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.togglePlan);
  }
  if (normalized.startsWith('/plan ')) {
    final prompt = trimmed.substring('/plan'.length).trim();
    if (prompt.isEmpty) {
      return const AgentSlashSubmitIntent(AgentSlashSubmitKind.togglePlan);
    }
    return AgentSlashSubmitIntent(
      AgentSlashSubmitKind.startPlan,
      value: prompt,
    );
  }

  // 粘贴的本地绝对路径（例如 /storage/emulated/0/Download/app.apk）是普通消息，
  // 不是斜杠命令。缺少这道判断时，开头的 '/' 会把整条消息送进斜杠命令解析，
  // 于是发送本地路径总是报「不支持的 Agent 命令」。
  // 已知命令（/model /review /init /plan）在上面都已提前 return，不受影响。
  if (_looksLikeFilesystemPath(trimmed)) {
    return const AgentSlashSubmitIntent(AgentSlashSubmitKind.none);
  }

  return const AgentSlashSubmitIntent(AgentSlashSubmitKind.unsupported);
}

/// 判断输入是否更像绝对文件路径而不是斜杠命令。
bool _looksLikeFilesystemPath(String value) {
  if (!value.startsWith('/')) {
    return false;
  }
  final body = value.substring(1).trim();
  if (body.isEmpty) {
    return false;
  }
  // /storage/emulated/0/... 出现第二层分隔符即视为路径。
  if (body.contains('/')) {
    return true;
  }
  final first = body.split(RegExp(r'\s+')).first.toLowerCase();
  return _filesystemRoots.contains(first);
}

const Set<String> _filesystemRoots = <String>{
  'sdcard',
  'storage',
  'emulated',
  'data',
  'system',
  'vendor',
  'mnt',
  'media',
  'proc',
  'dev',
  'sys',
  'root',
  'tmp',
  'home',
  'opt',
  'usr',
  'android',
  'download',
  'downloads',
  'documents',
  'pictures',
  'dcim',
  'movies',
  'music',
  'workspace',
};

/// A UI shortcut may select only a value advertised by the active ACP session.
String? advertisedPlanMode(Iterable<String> modes) {
  for (final mode in modes) {
    if (mode.trim().toLowerCase() == 'plan') return mode;
  }
  return null;
}
