package cn.com.omnimind.bot.agent.conversation

/**
 * Requirement 3 — 对话记录不显示 AI key.
 *
 * Strips credential-shaped substrings out of a conversation payload before it
 * is persisted to Room, so a raw API key / bearer token that leaked into a tool
 * result, tool args or an assistant message never becomes part of the stored
 * chat history.
 *
 * Two complementary layers:
 *  1. [KEYED_VALUE] — JSON string values whose key name looks credential-ish
 *     (`apiKey`, `authorization`, `token`, `password`, ...), including nested
 *     values that Gson escaped as `\"apiKey\":\"...\"`.
 *  2. [BARE_TOKENS] / [BEARER] — bare token shapes such as `sk-...`, `ghp_...`,
 *     `AKIA...`, `AIza...`, a JWT, or `Bearer <token>`, wherever they appear.
 *
 * Every replacement is a plain literal without quotes, backslashes or control
 * characters, so a redacted [AgentConversationEntry.payloadJson] stays valid
 * JSON and can still be replayed to the model.
 *
 * This mirrors its runtime sibling `CredentialsRedaction`, which masks keys on
 * the *display* surface (config read payloads); here the goal is stronger —
 * total removal from anything that could be persisted or shown in history.
 */
internal object ConversationSecretRedactor {

    private const val MASK = "**REDACTED**"

    /**
     * A JSON string value whose key name looks like a credential.
     * `\\?` tolerates the optional escaping Gson applies to nested JSON strings.
     */
    private val KEYED_VALUE = Regex(
        """(\\?"(?:api[_-]?key|apikey|api[_-]?secret|authorization|auth[_-]?token|access[_-]?token|refresh[_-]?token|client[_-]?secret|secret|password|passwd|pwd|token)\\?"\s*:\s*\\?")([^"\\]{6,})(\\?")""",
        RegexOption.IGNORE_CASE,
    )

    /** Well known secret prefixes followed by an opaque body. */
    private val BARE_TOKENS = listOf(
        Regex("""sk_(?:live|test)_[A-Za-z0-9]{12,}"""),
        Regex("""sk-[A-Za-z0-9_\-]{12,}"""),
        Regex("""AKIA[0-9A-Z]{16}"""),
        Regex("""ASIA[0-9A-Z]{16}"""),
        Regex("""github_pat_[A-Za-z0-9_]{20,}"""),
        Regex("""gh[pousr]_[A-Za-z0-9]{20,}"""),
        Regex("""xox[baprs]-[A-Za-z0-9\-]{10,}"""),
        Regex("""AIza[0-9A-Za-z_\-]{30,}"""),
        // JWT: three base64url segments.
        Regex("""eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}"""),
    )

    private val BEARER = Regex("""(Bearer\s+)[A-Za-z0-9\-._~+/=]{16,}""", RegexOption.IGNORE_CASE)

    /**
     * Returns [text] with credential-shaped substrings replaced by a mask.
     * Null/blank input is returned unchanged so callers keep their semantics.
     */
    fun redact(text: String?): String? {
        if (text.isNullOrEmpty()) return text
        var result = KEYED_VALUE.replace(text) { match ->
            match.groupValues[1] + MASK + match.groupValues[3]
        }
        for (pattern in BARE_TOKENS) {
            result = pattern.replace(result, MASK)
        }
        result = BEARER.replace(result) { match -> match.groupValues[1] + MASK }
        return result
    }
}
