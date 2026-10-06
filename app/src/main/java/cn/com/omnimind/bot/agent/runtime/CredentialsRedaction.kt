package cn.com.omnimind.bot.agent.runtime

/**
 * Redacts secrets from values that may be surfaced to the agent conversation
 * (tool results, config payloads) so raw API keys never persist into chat history.
 *
 * Runtime credential paths (launch environment variables, on-disk harness config)
 * purposely keep the raw key; only the human/agent-facing read surfaces are
 * redacted here.
 */
internal object CredentialsRedaction {

    private const val REDACTED = "••••••••"

    /**
     * Returns a masked form of [apiKey] suitable for tool/config payloads.
     * Empty keys stay empty so callers can keep their `.orEmpty()` semantics.
     */
    fun apiKeyMask(apiKey: String?): String {
        val key = apiKey?.trim().orEmpty()
        if (key.isEmpty()) return ""
        if (key.length <= 6) return REDACTED
        return key.take(3) + REDACTED + key.takeLast(3)
    }
}