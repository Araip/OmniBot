package cn.com.omnimind.bot.ui.channel

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 桌面图标方案切换（含「反馈」伪装模式）。
 *
 * 实现方式：AndroidManifest 中预置多个 activity-alias，它们都指向同一个
 * LauncherActivity，但拥有各自的 icon / label / enabled 状态。切换时启用目标
 * 别名并禁用其余别名，Android 桌面会在随后几秒内刷新图标与名称。
 */
class LauncherIconChannel : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "LauncherIconChannel"
        private const val CHANNEL = "cn.com.omnimind.bot/launcher_icon"
        private const val PREFS = "omni_launcher_icon"
        private const val KEY_VARIANT = "variant"

        const val VARIANT_PURPLE = "purple"
        const val VARIANT_INK = "ink"
        const val VARIANT_OCEAN = "ocean"
        const val VARIANT_FEEDBACK = "feedback"

        /** variantId -> activity-alias 全限定类名 */
        private val ALIASES: LinkedHashMap<String, String> = linkedMapOf(
            VARIANT_PURPLE to "cn.com.omnimind.bot.activity.LauncherIconPurple",
            VARIANT_INK to "cn.com.omnimind.bot.activity.LauncherIconInk",
            VARIANT_OCEAN to "cn.com.omnimind.bot.activity.LauncherIconOcean",
            VARIANT_FEEDBACK to "cn.com.omnimind.bot.activity.LauncherFeedback",
        )
    }

    private var appContext: Context? = null
    private var channel: MethodChannel? = null

    fun onCreate(context: Context) {
        appContext = context.applicationContext
    }

    fun setChannel(flutterEngine: FlutterEngine) {
        val created = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        created.setMethodCallHandler(this)
        channel = created
    }

    fun clear() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVariant" -> result.success(currentVariant())
            "setVariant" -> {
                val target = call.argument<String>("variant") ?: currentVariant()
                result.success(applyVariant(target))
            }
            else -> result.notImplemented()
        }
    }

    private fun currentVariant(): String {
        val context = appContext ?: return VARIANT_PURPLE
        val stored = context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_VARIANT, VARIANT_PURPLE)
        return if (stored != null && ALIASES.containsKey(stored)) stored else VARIANT_PURPLE
    }

    private fun applyVariant(variantId: String): Boolean {
        val context = appContext ?: return false
        if (!ALIASES.containsKey(variantId)) return false
        val packageManager = context.packageManager
        val packageName = context.packageName
        var applied = false
        ALIASES.forEach { (id, aliasClass) ->
            val state = if (id == variantId) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            try {
                packageManager.setComponentEnabledSetting(
                    ComponentName(packageName, aliasClass),
                    state,
                    PackageManager.DONT_KILL_APP,
                )
                if (id == variantId) applied = true
            } catch (error: Exception) {
                Log.w(TAG, "switch launcher alias failed: $id", error)
            }
        }
        if (!applied) return false
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_VARIANT, variantId)
            .apply()
        return true
    }
}
