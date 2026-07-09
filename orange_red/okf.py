"""OKF markdown serialization helpers."""

from __future__ import annotations

import re
from collections.abc import Mapping, Sequence
from datetime import datetime
from pathlib import PurePath
from typing import Any

import yaml

REQUIRED_FRONTMATTER_FIELDS = (
    "type",
    "title",
    "description",
    "resource",
    "tags",
    "timestamp",
)
_TIMESTAMP_MICROSECOND_RE = re.compile(
    r"[T ]\d{2}:\d{2}:\d{2}\.\d{6}(?:$|Z$|[+-]\d{2}:\d{2}$)"
)
_LOG_TIMESTAMP_MICROSECOND_RE = re.compile(
    r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}\.\d{6}"
    r"(?:Z|[+-]\d{2}:\d{2})?"
)


class FrontmatterError(ValueError):
    """Frontmatter cannot be serialized as valid OKF metadata."""


class ConformanceError(ValueError):
    """Markdown document does not conform to orange-red OKF rules."""


def serialize_frontmatter(metadata: Mapping[str, Any]) -> str:
    """Serialize untrusted concept metadata as one safe YAML frontmatter block.

    PyYAML owns quoting/escaping. Values are normalized before dump so hostile
    strings containing `---`, newlines, colons, anchors, or YAML-looking syntax
    stay scalar data instead of document/key injection.
    """

    normalized = _normalize_metadata(metadata)
    _require_fields(normalized)
    dumped = yaml.safe_dump(
        normalized,
        allow_unicode=True,
        default_flow_style=False,
        sort_keys=False,
    ).strip()
    return f"---\n{dumped}\n---\n"


def serialize_concept(metadata: Mapping[str, Any], body: str) -> str:
    """Serialize OKF concept as frontmatter + markdown body."""

    if "<" in body and ">" in body:
        raise FrontmatterError("concept body must be markdown-only, no raw HTML")
    clean_body = body.strip()
    if not clean_body:
        raise FrontmatterError("concept body must be non-empty")
    return f"{serialize_frontmatter(metadata)}\n{clean_body}\n"


def validate_okf_markdown(path: str | PurePath, content: str) -> None:
    """Validate one OKF markdown document by bundle-relative path."""

    name = PurePath(path).name
    if name == "index.md":
        _validate_index_document(content)
        return
    if name == "log.md":
        _validate_log_document(content)
        return
    metadata, body = _parse_concept_document(content)
    _require_fields(metadata, error_type=ConformanceError)
    if not body.strip():
        raise ConformanceError("concept body must be non-empty")


def _normalize_metadata(metadata: Mapping[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for key, value in metadata.items():
        field = str(key)
        normalized[field] = (
            _normalize_timestamp(value)
            if field == "timestamp"
            else _normalize_value(value)
        )
    return normalized


def _normalize_timestamp(value: Any) -> str:
    if isinstance(value, datetime):
        return value.isoformat(timespec="microseconds")
    if isinstance(value, str):
        try:
            datetime.fromisoformat(value)
        except ValueError as exc:
            raise FrontmatterError("timestamp must be ISO 8601 datetime") from exc
        if not _TIMESTAMP_MICROSECOND_RE.search(value):
            raise FrontmatterError("timestamp must include microsecond precision")
        return value
    raise FrontmatterError("timestamp must be datetime or ISO 8601 string")


def _normalize_value(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat(timespec="microseconds")
    if isinstance(value, str):
        return value
    if isinstance(value, Mapping):
        return {str(k): _normalize_value(v) for k, v in value.items()}
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return [_normalize_value(item) for item in value]
    if value is None or isinstance(value, (bool, int, float)):
        return value
    return str(value)


def _parse_concept_document(content: str) -> tuple[dict[str, Any], str]:
    if not content.startswith("---\n"):
        raise ConformanceError("concept document must start with YAML frontmatter")
    try:
        frontmatter, body = content.removeprefix("---\n").split("\n---\n", 1)
    except ValueError as exc:
        raise ConformanceError("concept document must close YAML frontmatter") from exc
    try:
        metadata = yaml.safe_load(frontmatter)
    except yaml.YAMLError as exc:
        raise ConformanceError("concept frontmatter must parse as YAML") from exc
    if not isinstance(metadata, dict):
        raise ConformanceError("concept frontmatter must be a mapping")
    return metadata, body


def _validate_index_document(content: str) -> None:
    if not content.startswith("---\n"):
        return
    metadata, _body = _parse_concept_document(content)
    disallowed = sorted(set(metadata) - {"okf_version"})
    if disallowed:
        raise ConformanceError(
            f"index.md reserved frontmatter fields not allowed: {', '.join(disallowed)}"
        )


def _validate_log_document(content: str) -> None:
    if content.startswith("---\n"):
        raise ConformanceError("log.md must not use concept frontmatter")
    lines = [line for line in content.splitlines() if line.strip()]
    for line in lines:
        if "**Update**" in line or "**Creation**" in line:
            if not _LOG_TIMESTAMP_MICROSECOND_RE.search(line):
                raise ConformanceError("log.md entries must include microsecond timestamp")


def _require_fields(
    metadata: Mapping[str, Any],
    error_type: type[ValueError] = FrontmatterError,
) -> None:
    missing = [
        field
        for field in REQUIRED_FRONTMATTER_FIELDS
        if field not in metadata or metadata[field] in (None, "", [])
    ]
    if missing:
        raise error_type(f"missing required frontmatter fields: {', '.join(missing)}")
