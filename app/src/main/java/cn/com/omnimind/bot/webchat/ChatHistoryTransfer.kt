package cn.com.omnimind.bot.webchat

import cn.com.omnimind.baselib.database.AgentConversationEntry
import cn.com.omnimind.baselib.database.Conversation
import cn.com.omnimind.baselib.database.DatabaseHelper
import org.json.JSONArray
import org.json.JSONObject

/**
 * 聊天记录导入/导出核心逻辑。
 *
 * 导出：把 `conversations` + `agent_conversation_entries` 全量序列化为一个 JSON 字符串。
 * 导入：把 JSON 反序列化为「追加」语义的新会话（新 id），并正确重映射本备份内部的
 * 父子会话关系（parentConversationId）。
 *
 * 设计约定：
 * - 只导出展示/业务字段；运行时 checkpoint（contextSummary 系列、token 计数）不导出，
 *   避免导入后 checkpoint 的 entry DB id 指向错误行。
 * - `id` / `parentConversationId` 是设备本地自增主键/外键，导出时仅记 `sourceId` /
 *   `parentSourceId` 用于导入侧重建，不要求目标库保持原 id。
 * - 导入为「追加」：每次导入生成全新会话，不覆盖、不去重现有数据。
 */
object ChatHistoryTransfer {
    const val FORMAT = "omnibot-chat-backup"
    const val VERSION = 1
    const val EXPORTER = "cn.com.omnimind.bot"

    data class ImportSummary(
        val conversationsImported: Int,
        val entriesImported: Int,
    )

    // region Export

    /** 读取全量会话及其条目，生成格式化 JSON（缩进 2 空格）。 */
    suspend fun exportAllToJson(): String {
        val root = JSONObject()
        root.put("format", FORMAT)
        root.put("version", VERSION)
        root.put("exporter", EXPORTER)
        root.put("exportedAt", System.currentTimeMillis())

        val conversationsArray = JSONArray()
        for (conversation in DatabaseHelper.getAllConversations()) {
            // 一个会话下所有模式（agent/codex/normal）的条目都归入同一会话。
            val entries = DatabaseHelper.getDatabase()
                .agentConversationEntryDao()
                .getConversationEntriesAsc(conversation.id)
            conversationsArray.put(serializeConversation(conversation, entries))
        }
        root.put("conversations", conversationsArray)
        return root.toString(2)
    }

    private fun serializeConversation(
        conversation: Conversation,
        entries: List<AgentConversationEntry>,
    ): JSONObject {
        val item = JSONObject()

        val conv = JSONObject()
        conv.put("sourceId", conversation.id)
        conv.put("title", conversation.title)
        conv.put("mode", conversation.mode)
        conv.put("isArchived", conversation.isArchived)
        conv.put("isPinned", conversation.isPinned)
        putNullable(conv, "parentSourceId", conversation.parentConversationId)
        putNullable(conv, "parentSourceMode", conversation.parentConversationMode)
        putNullable(conv, "scheduledTaskId", conversation.scheduledTaskId)
        putNullable(conv, "summary", conversation.summary)
        putNullable(conv, "lastMessage", conversation.lastMessage)
        conv.put("messageCount", conversation.messageCount)
        conv.put("status", conversation.status)
        conv.put("createdAt", conversation.createdAt)
        conv.put("updatedAt", conversation.updatedAt)
        item.put("conversation", conv)

        val entriesArray = JSONArray()
        for (entry in entries) {
            val e = JSONObject()
            e.put("conversationMode", entry.conversationMode)
            e.put("entryId", entry.entryId)
            e.put("entryType", entry.entryType)
            e.put("status", entry.status)
            e.put("summary", entry.summary)
            e.put("payloadJson", entry.payloadJson)
            e.put("createdAt", entry.createdAt)
            e.put("updatedAt", entry.updatedAt)
            entriesArray.put(e)
        }
        item.put("entries", entriesArray)
        return item
    }

    private fun putNullable(obj: JSONObject, key: String, value: Any?) {
        if (value == null) obj.put(key, JSONObject.NULL) else obj.put(key, value)
    }

    // endregion

    // region Import

    /**
     * 解析并导入整份备份 JSON。失败会抛异常并回滚整个事务（Room `withTransaction`）。
     */
    suspend fun importFromJson(json: String): ImportSummary {
        val root = JSONObject(json)
        val format = root.optString("format")
        val version = root.optInt("version", -1)
        require(format == FORMAT) { "Unsupported backup format: $format" }
        require(version == VERSION) { "Unsupported backup version: $version" }

        val conversationsArray = root.optJSONArray("conversations")
            ?: throw IllegalArgumentException("Missing conversations array")

        var importedConversations = 0
        var importedEntries = 0
        val sourceIdMap = HashMap<Long, Long>()
        // newId -> (oldParentSourceId, oldParentSourceMode)
        val pendingParentLinks = HashMap<Long, Pair<Long?, String?>>()

        DatabaseHelper.withTransaction {
            for (i in 0 until conversationsArray.length()) {
                val item = conversationsArray.getJSONObject(i)
                val convJson = item.getJSONObject("conversation")

                val sourceId = convJson.optLong("sourceId", -1L)
                val oldParentId = convJson.optLong("parentSourceId", 0L).takeIf { it > 0L }
                val oldParentMode = convJson.optString("parentSourceMode", "")
                    .takeIf { it.isNotEmpty() }
                val mode = convJson.optString("mode", "normal").ifBlank { "normal" }

                val conversation = Conversation(
                    title = convJson.optString("title", ""),
                    mode = mode,
                    isArchived = convJson.optBoolean("isArchived", false),
                    isPinned = convJson.optBoolean("isPinned", false),
                    scheduledTaskId = convJson.optString("scheduledTaskId", "")
                        .takeIf { it.isNotEmpty() },
                    summary = convJson.optString("summary", "").takeIf { it.isNotEmpty() },
                    lastMessage = convJson.optString("lastMessage", "").takeIf { it.isNotEmpty() },
                    messageCount = convJson.optInt("messageCount", 0),
                    status = convJson.optInt("status", 0),
                    createdAt = convJson.optLong("createdAt", System.currentTimeMillis()),
                    updatedAt = convJson.optLong("updatedAt", System.currentTimeMillis()),
                )
                val newId = DatabaseHelper.insertConversation(conversation)
                if (sourceId > 0L) sourceIdMap[sourceId] = newId
                if (oldParentId != null) pendingParentLinks[newId] = oldParentId to oldParentMode
                importedConversations++

                val entriesArray = item.optJSONArray("entries") ?: JSONArray()
                for (j in 0 until entriesArray.length()) {
                    val eJson = entriesArray.getJSONObject(j)
                    val entry = AgentConversationEntry(
                        conversationId = newId,
                        conversationMode = eJson.optString("conversationMode", "").ifBlank { mode },
                        entryId = eJson.optString("entryId", "")
                            .ifBlank { "${System.currentTimeMillis()}-$i-$j" },
                        entryType = eJson.optString("entryType", ""),
                        status = eJson.optString("status", ""),
                        summary = eJson.optString("summary", ""),
                        payloadJson = eJson.optString("payloadJson", ""),
                        createdAt = eJson.optLong("createdAt", System.currentTimeMillis()),
                        updatedAt = eJson.optLong("updatedAt", System.currentTimeMillis()),
                    )
                    DatabaseHelper.upsertAgentConversationEntry(entry)
                    importedEntries++
                }
            }

            // 所有会话落库后再重建父子关系，避免依赖插入顺序。
            for ((newId, link) in pendingParentLinks) {
                val (oldParentId, oldParentMode) = link
                val mappedParentId = sourceIdMap[oldParentId] ?: continue
                val current = DatabaseHelper.getConversationById(newId) ?: continue
                DatabaseHelper.updateConversation(
                    current.copy(
                        parentConversationId = mappedParentId,
                        parentConversationMode = oldParentMode,
                    )
                )
            }
        }

        return ImportSummary(importedConversations, importedEntries)
    }

    // endregion
}