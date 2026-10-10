#!/usr/bin/env python3
"""Omnibot 本地聊天记录搜索工具。

用法：
    python3 search_chat.py search <关键词> [--limit 20] [--conv-id <id>]
    python3 search_chat.py conv <会话ID> [--limit 50]
    python3 search_chat.py recent [--limit 20]
    python3 search_chat.py stats

示例：
    python3 search_chat.py search "markdown table"
    python3 search_chat.py conv 297
    python3 search_chat.py recent --limit 10
    python3 search_chat.py stats
"""

import sqlite3
import json
import sys
import argparse

DB_PATH = "/data/data/cn.com.omnimind.bot/databases/omnibot_cache_databaseoss"


def get_conn():
    return sqlite3.connect(DB_PATH)


def search_messages(keyword: str, limit: int = 20, conv_id: int = None):
    """按关键词搜索消息。"""
    conn = get_conn()
    cur = conn.cursor()
    like_kw = f"%{keyword}%"

    if conv_id:
        cur.execute(
            """SELECT id, conversationId, entryType, summary,
            datetime(createdAt/1000,'unixepoch','localtime') as time
            FROM agent_conversation_entries
            WHERE (summary LIKE ? OR payloadJson LIKE ?) AND conversationId=?
            ORDER BY id DESC LIMIT ?""",
            (like_kw, like_kw, conv_id, limit),
        )
    else:
        cur.execute(
            """SELECT id, conversationId, entryType, summary,
            datetime(createdAt/1000,'unixepoch','localtime') as time
            FROM agent_conversation_entries
            WHERE summary LIKE ? OR payloadJson LIKE ?
            ORDER BY id DESC LIMIT ?""",
            (like_kw, like_kw, limit),
        )

    results = cur.fetchall()
    conn.close()
    return results


def get_conversation(conv_id: int, limit: int = 200):
    """获取某会话的所有消息。"""
    conn = get_conn()
    cur = conn.cursor()

    # 会话信息
    cur.execute(
        "SELECT id, title, mode, messageCount,"
        "datetime(createdAt/1000,'unixepoch','localtime') FROM conversations WHERE id=?",
        (conv_id,),
    )
    conv = cur.fetchone()

    # 消息列表
    cur.execute(
        """SELECT id, entryType, summary, payloadJson,
        datetime(createdAt/1000,'unixepoch','localtime') as time
        FROM agent_conversation_entries
        WHERE conversationId=? ORDER BY id LIMIT ?""",
        (conv_id, limit),
    )
    entries = cur.fetchall()
    conn.close()
    return conv, entries


def list_recent_conversations(limit: int = 20):
    """列出最近会话。"""
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        """SELECT id, title, mode, messageCount,
        datetime(createdAt/1000,'unixepoch','localtime') as created
        FROM conversations ORDER BY id DESC LIMIT ?""",
        (limit,),
    )
    results = cur.fetchall()
    conn.close()
    return results


def get_stats():
    """获取数据库统计信息。"""
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM agent_conversation_entries")
    total_entries = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM conversations")
    total_convs = cur.fetchone()[0]
    cur.execute(
        "SELECT entryType, COUNT(*) FROM agent_conversation_entries GROUP BY entryType"
    )
    type_counts = cur.fetchall()
    cur.execute(
        "SELECT MIN(datetime(createdAt/1000,'unixepoch','localtime')),"
        "MAX(datetime(createdAt/1000,'unixepoch','localtime')) FROM conversations"
    )
    time_range = cur.fetchone()
    conn.close()
    return total_entries, total_convs, type_counts, time_range


def format_entry(entry, show_payload_text=False):
    """格式化单条消息。"""
    eid, entry_type, summary, payload_json, time_str = entry
    text_preview = ""
    if show_payload_text and payload_json:
        try:
            payload = json.loads(payload_json)
            if isinstance(payload, dict):
                text = payload.get("content", {}).get("text", "")
                text_preview = text[:200]
        except (json.JSONDecodeError, TypeError):
            pass
    marker = "📤" if entry_type == "user_message" else "🤖" if entry_type == "assistant_message" else "🔧" if entry_type == "tool_event" else "📋"
    line = f"[{eid}] {marker} {time_str} | {summary[:100]}"
    if text_preview:
        line += f"\n       ↳ {text_preview}"
    return line


def main():
    parser = argparse.ArgumentParser(description="Omnibot 聊天记录搜索")
    sub = parser.add_subparsers(dest="cmd")

    sp_search = sub.add_parser("search", help="按关键词搜索消息")
    sp_search.add_argument("keyword", help="搜索关键词")
    sp_search.add_argument("--limit", type=int, default=20, help="返回条数上限")
    sp_search.add_argument("--conv-id", type=int, help="限定会话ID")

    sp_conv = sub.add_parser("conv", help="查看某会话完整记录")
    sp_conv.add_argument("conv_id", type=int, help="会话ID")
    sp_conv.add_argument("--limit", type=int, default=200, help="消息条数上限")
    sp_conv.add_argument("--text", action="store_true", help="显示 payload 中的文本内容")

    sp_recent = sub.add_parser("recent", help="列出最近会话")
    sp_recent.add_argument("--limit", type=int, default=20, help="返回条数上限")

    sp_stats = sub.add_parser("stats", help="数据库统计信息")

    args = parser.parse_args()

    if args.cmd == "search":
        results = search_messages(args.keyword, args.limit, args.conv_id)
        print(f"🔍 搜索 '{args.keyword}' 命中 {len(results)} 条：\n")
        for r in results:
            print(f"  [{r[0]}] 会话{r[1]} | {r[2]} | {r[4]}")
            print(f"         {r[3][:150]}")
            print()

    elif args.cmd == "conv":
        conv, entries = get_conversation(args.conv_id, args.limit)
        if conv:
            print(f"📁 会话 #{conv[0]}: {conv[1]}")
            print(f"   模式: {conv[2]} | 消息数: {conv[3]} | 创建: {conv[4]}\n")
        else:
            print(f"❌ 会话 #{args.conv_id} 不存在")
            return
        for e in entries:
            print(format_entry(e, show_payload_text=args.text))

    elif args.cmd == "recent":
        results = list_recent_conversations(args.limit)
        print(f"📋 最近 {len(results)} 个会话：\n")
        for r in results:
            print(f"  [#{r[0]}] {r[1]} | {r[2]} | {r[3]}条消息 | {r[4]}")

    elif args.cmd == "stats":
        total_e, total_c, type_counts, time_range = get_stats()
        print(f"📊 数据库统计：\n")
        print(f"  总条目数: {total_e:,}")
        print(f"  总会话数: {total_c:,}")
        print(f"  时间范围: {time_range[0]} ~ {time_range[1]}")
        print(f"  类型分布:")
        for t, c in type_counts:
            print(f"    {t}: {c:,}")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
