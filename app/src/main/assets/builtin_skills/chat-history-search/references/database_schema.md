# 本地聊天数据库 Schema

## 数据库文件

`/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss`

## 表：agent_conversation_entries

对话条目表，存储每条消息/事件。

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| `id` | INTEGER PK | 自增主键 |
| `conversationId` | INTEGER | 所属会话 ID，关联 `conversations.id` |
| `conversationMode` | TEXT | 会话模式（`normal` 等） |
| `entryId` | TEXT | 条目唯一标识（如 `1778572464917-ai-user`） |
| `entryType` | TEXT | 条目类型 |
| `status` | TEXT | 状态 |
| `summary` | TEXT | 简短摘要/预览文本 |
| `payloadJson` | TEXT | 完整 JSON payload |
| `createdAt` | INTEGER | 创建时间（Unix 毫秒） |
| `updatedAt` | INTEGER | 更新时间（Unix 毫秒） |

### entryType 枚举

| 值 | 含义 |
|:---|:---|
| `user_message` | 用户消息 |
| `assistant_message` | AI 回复消息 |
| `tool_event` | 工具调用事件 |
| `ui_card` | 界面卡片 |
| `system_message` | 系统消息 |

### payloadJson 结构

**user_message**：
```json
{
  "id": "1778572464917-ai-user",
  "type": 1,
  "user": 1,
  "content": {
    "text": "用户消息文本",
    "id": "1778572464917-ai-user"
  },
  "isLoading": false,
  "isFirst": false,
  "isError": false,
  "isSummarizing": false,
  "createAt": "2026-05-12T07:54:24.917Z"
}
```

**assistant_message**：与 user_message 结构类似，`user: 0`，`content.text` 含 Markdown 回复。

**tool_event**：
```json
{
  "taskId": "1774841194403-ai",
  "toolName": "browser_use",
  "displayName": "浏览器操作",
  "toolTitle": "截图查看页面",
  "toolType": "browser",
  "status": "success",
  "summary": "截图查看页面",
  "args": {...},
  "argsJson": {...}
}
```

## 表：conversations

会话元数据表。

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| `id` | INTEGER PK | 会话 ID |
| `title` | TEXT | 会话标题 |
| `mode` | TEXT | 模式（`normal` 等） |
| `summary` | TEXT | 会话摘要 |
| `contextSummary` | TEXT | 上下文摘要 |
| `contextSummaryCutoffEntryDbId` | INTEGER | 上下文截止条目 |
| `contextSummaryUpdatedAt` | INTEGER | 上下文摘要更新时间 |
| `status` | INTEGER | 状态 |
| `lastMessage` | TEXT | 最后一条消息 |
| `messageCount` | INTEGER | 消息总数 |
| `latestPromptTokens` | INTEGER | 最新 prompt token 数 |
| `promptTokenThreshold` | INTEGER | token 阈值 |
| `latestPromptTokensUpdatedAt` | INTEGER | token 更新时间 |
| `createdAt` | INTEGER | 创建时间（Unix 毫秒） |
| `updatedAt` | INTEGER | 更新时间（Unix 毫秒） |
| `isArchived` | INTEGER | 是否归档（默认 0） |

## 表：messages

几乎不用（仅 1 条记录），内容已在 `agent_conversation_entries` 中。

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| `id` | INTEGER PK | |
| `messageId` | TEXT | |
| `type` | INTEGER | |
| `user` | INTEGER | |
| `content` | TEXT | |
| `createdAt` | INTEGER | |
| `updatedAt` | INTEGER | |

## 时间转换

```sql
datetime(createdAt/1000, 'unixepoch', 'localtime')
```

`createdAt` 是 Unix 毫秒时间戳，转换需先除以 1000。
