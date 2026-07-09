"""Command line entry point for orange-red."""

from __future__ import annotations

import argparse


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="orange-red",
        description="Crawl intranet pages into OKF markdown and query pgvector index.",
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    crawl = subcommands.add_parser("crawl", help="crawl configured intranet host")
    crawl.add_argument("url")

    subcommands.add_parser("index", help="rebuild pgvector index from bundle")

    query = subcommands.add_parser("query", help="semantic search indexed concepts")
    query.add_argument("text")

    chat = subcommands.add_parser("chat", help="answer with OpenAI using citations")
    chat.add_argument("question")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    parser.parse_args(argv)
    parser.error("command implementation pending; run /build for SPEC.md tasks")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())