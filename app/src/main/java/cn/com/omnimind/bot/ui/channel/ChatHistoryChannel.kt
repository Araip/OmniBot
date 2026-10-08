package cn.com.omnimind.bot.ui.channel

import android.content.Context
import cn.com.omnimind.baselib.util.OmniLog
import cn.com.omnimind.bot.webchat.ChatHistoryTransfer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 聊天记录导入/导出通道（纯数据）。
 *
 * 文件选择交由 Flutter 侧使用 file_picker 处理（与 ModelProviderBackupService 一致），
 * 原生只负责 room 数据库的序列化 / 反序列化：
 * - exportChatHistoryJson：全量序列化为 JSON 字符串返回
 * - importChatHistoryJson：把 JSON 字符串反序列化并追加导入
 */
class ChatHistoryChannel {

    companion object {
        private const val TAG = "ChatHistoryChannel"
        private const val CHANNEL = "cn.com.omnimind.bot/chat_history"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var channel: MethodChannel? = null

    @Suppress("UNUSED_PARAMETER")
    fun onCreate(context: Context) {
        // 纯数据通道，无需持有 activity/context。
    }

    fun setChannel(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "exportChatHistoryJson" -> exportChatHistoryJson(result)
                "importChatHistoryJson" -> importChatHistoryJson(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun exportChatHistoryJson(result: MethodChannel.Result) {
        scope.launch {
            try {
                val json = withContext(Dispatchers.IO) {
                    ChatHistoryTransfer.exportAllToJson()
                }
                result.success(json)
            } catch (e: Exception) {
                OmniLog.e(TAG, "Failed to export chat history", e)
                result.error("EXPORT_FAILED", e.message, e.toString())
            }
        }
    }

    private fun importChatHistoryJson(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("json")
        if (json.isNullOrBlank()) {
            result.error("IMPORT_INVALID", "json argument is missing or empty", null)
            return
        }
        scope.launch {
            try {
                val summary = withContext(Dispatchers.IO) {
                    ChatHistoryTransfer.importFromJson(json)
                }
                result.success(
                    mapOf(
                        "conversationsImported" to summary.conversationsImported,
                        "entriesImported" to summary.entriesImported,
                    )
                )
            } catch (e: Exception) {
                OmniLog.e(TAG, "Failed to import chat history", e)
                result.error("IMPORT_FAILED", e.message, e.toString())
            }
        }
    }

    fun clear() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}