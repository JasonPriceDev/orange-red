"""Canonical URL identity and OKF concept path mapping."""

from __future__ import annotations

import hashlib
import re
from pathlib import PurePosixPath
from urllib.parse import parse_qsl, quote, unquote, urlencode, urlsplit, urlunsplit

_SAFE_SEGMENT = re.compile(r"[^A-Za-z0-9._-]+")


def canonicalize_url(url: str) -> str:
    """Return normalized absolute URL identity; fragment ignored."""

    parts = urlsplit(url)
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()
    if not scheme or not host:
        raise ValueError("url must be absolute")
    netloc = host
    if parts.port and not _default_port(scheme, parts.port):
        netloc = f"{host}:{parts.port}"

    path = quote(unquote(parts.path or "/"), safe="/-._~")
    query_pairs = parse_qsl(parts.query, keep_blank_values=True)
    query = urlencode(sorted(query_pairs), doseq=True)
    return urlunsplit((scheme, netloc, path, query, ""))


def concept_path_for_url(url: str) -> PurePosixPath:
    """Map canonical URL to deterministic, collision-resistant bundle path."""

    canonical = canonicalize_url(url)
    parts = urlsplit(canonical)
    host = parts.netloc
    raw_segments = [segment for segment in parts.path.split("/") if segment]
    segments = [_safe_segment(unquote(segment)) for segment in raw_segments]
    if not segments:
        segments = ["index"]

    last = segments[-1]
    if last in {"index", "index.html", "index.htm"}:
        segments[-1] = "index"
    elif "." not in last:
        segments[-1] = f"{last}.md"
    elif not last.endswith(".md"):
        segments[-1] = f"{last}.md"

    if parts.query:
        digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:12]
        stem = segments[-1][:-3] if segments[-1].endswith(".md") else segments[-1]
        segments[-1] = f"{stem}--q-{digest}.md"
    elif not segments[-1].endswith(".md"):
        segments[-1] = f"{segments[-1]}.md"

    return PurePosixPath(host, *segments)


def _safe_segment(segment: str) -> str:
    safe = _SAFE_SEGMENT.sub("-", segment).strip(".-_")
    return safe or "_"


def _default_port(scheme: str, port: int) -> bool:
    return (scheme == "http" and port == 80) or (scheme == "https" and port == 443)