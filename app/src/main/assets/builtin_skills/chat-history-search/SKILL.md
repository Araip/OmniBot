---
name: chat-history-search
description: 搜索和查询 Omnibot 本地聊天历史数据库。当用户要求查找历史聊天记录、搜索过去聊过的某句话、回顾某天或某个会话的对话内容、统计聊天数据、或提到"聊天记录/历史消息/之前聊过/翻聊天记录/搜数据库"等信号时触发。通过 terminal_execute + Python sqlite3 访问应用私有数据库。
---

# Chat History Search

专门面向 Omnibot 本地聊天历史数据库的搜索与查询技能。

## 环境要点

- **数据库路径**：`/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss`
- **访问方式**：必须使用 `terminal_execute`（Alpine 环境），`file_search`/`file_read` 无法访问该路径。
- **搜索工具**：优先用 Python `sqlite3` 模块，避免 sqlite3 CLI 的 UTF-8 LIKE 兼容问题。
- **主要表**：`agent_conversation_entries`（对话条目）、`conversations`（会话元数据）。`messages` 表几乎不用。
- **内容字段**：`summary` 存简短摘要，`payloadJson` 存完整 JSON（含 `content.text` 等真实消息体）。

## 核心表结构

参考 `references/database_schema.md` 获取完整 schema。

快速要点：
- `agent_conversation_entries`：`id`, `conversationId`, `entryType`（user_message/assistant_message/tool_event/ui_card 等）, `summary`, `payloadJson`, `createdAt`（Unix 毫秒）
- `conversations`：`id`, `title`, `mode`, `summary`, `lastMessage`, `messageCount`, `createdAt`, `updatedAt`

## 常见任务

### 按关键词搜索消息

```python
python3 -c "
import sqlite3, json
conn = sqlite3.connect('/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss')
cur = conn.cursor()
keyword = '替换为搜索关键词'
cur.execute('''SELECT id, conversationId, entryType, summary,
    datetime(createdAt/1000,\"unixepoch\",\"localtime\") as time
    FROM agent_conversation_entries
    WHERE summary LIKE ? OR payloadJson LIKE ?
    ORDER BY id DESC LIMIT 30''', (f'%{keyword}%', f'%{keyword}%'))
for r in cur.fetchall():
    print(r)
conn.close()
"
```

### 查看某会话完整对话

```python
python3 -c "
import sqlite3, json
conn = sqlite3.connect('/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss')
cur = conn.cursor()
conv_id = 替换为会话ID
cur.execute('''SELECT id, entryType, summary, payloadJson,
    datetime(createdAt/1000,\"unixepoch\",\"localtime\") as time
    FROM agent_conversation_entries
    WHERE conversationId=? ORDER BY id''', (conv_id,))
for r in cur.fetchall():
    payload = json.loads(r[3])
    text = payload.get('content',{}).get('text','') if isinstance(payload, dict) else ''
    print(f'[{r[4]}] {r[1]}: {r[2][:80]} | {text[:120]}')
conn.close()
"
```

### 按时间范围查询

```python
# createdAt 是 Unix 毫秒时间戳
# 用 datetime(createdAt/1000,'unixepoch','localtime') 转换
```

### 列出最近会话

```python
python3 -c "
import sqlite3
conn = sqlite3.connect('/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss')
cur = conn.cursor()
cur.execute('''SELECT id, title, mode, messageCount,
    datetime(createdAt/1000,\"unixepoch\",\"localtime\")
    FROM conversations ORDER BY id DESC LIMIT 20''')
for r in cur.fetchall():
    print(r)
conn.close()
"
```

## 注意事项

- 时间字段 `createdAt` 是 **Unix 毫秒** 时间戳，转换需 `/1000`。
- `payloadJson` 是 JSON 字符串，`user_message`/`assistant_message` 类型的真正文本在 `content.text` 中。
- `entryType` 可能值：`user_message`、`assistant_message`、`tool_event`、`ui_card` 等。
- 搜索中文内容必须用 Python，CLI 版 sqlite3 在 proot 下 LIKE 中文有问题。
- 只读查询，不要对数据库执行 INSERT/UPDATE/DELETE。
