package cn.com.omnimind.bot.ui.channel

import android.content.Context
import android.os.Handler
import android.os.Looper
import cn.com.omnimind.baselib.util.OmniLog
import cn.com.omnimind.uikit.loader.cat.DraggableBallInstance
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Overlay通道 - 处理Flutter与Android Overlay之间的通信。
 * 仅保留 showMessage 通道（供消息提示使用）；宠物相关方法已删除。
 */
class OverlayChannel {

    private val TAG = "OverlayChannel"
    private val CHANNEL = "cn.com.omnimind.bot/overlay"

    private var methodChannel: MethodChannel? = null
    private var appContext: Context? = null

    fun onCreate(context: Context) {
        appContext = context.applicationContext
        DraggableBallInstance.initialize(context)
    }

    fun setChannel(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showMessage" -> {
                try {
                    val message = call.argument<String>("message") ?: ""
                    showMessageWithRetry(message, result, maxRetries = 5, retryDelayMs = 100L)
                } catch (e: Exception) {
                    OmniLog.e(TAG, "showMessage failed: ${e.message}", e)
                    result.error("SHOW_MESSAGE_FAILED", e.message, null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun clear() {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    /**
     * 带重试机制的消息显示
     */
    private fun showMessageWithRetry(
        message: String,
        result: MethodChannel.Result,
        maxRetries: Int,
        retryDelayMs: Long,
        currentRetry: Int = 0
    ) {
        val instance = DraggableBallInstance.getInstance()
        if (instance == null) {
            if (currentRetry < maxRetries) {
                Handler(Looper.getMainLooper()).postDelayed({
                    showMessageWithRetry(message, result, maxRetries, retryDelayMs, currentRetry + 1)
                }, retryDelayMs)
            } else {
                OmniLog.e(TAG, "DraggableBallInstance is null after $maxRetries retries, overlay may not be initialized")
                result.error("OVERLAY_NOT_INITIALIZED", "Overlay is not initialized after retries", null)
            }
            return
        }
        instance.collapseNotChangeState()
        Handler(Looper.getMainLooper()).post {
            try {
                DraggableBallInstance.message(message)
                result.success(true)
            } catch (e: Exception) {
                OmniLog.e(TAG, "Failed to show message: ${e.message}", e)
                result.error("SHOW_MESSAGE_FAILED", e.message, null)
            }
        }
    }
}
