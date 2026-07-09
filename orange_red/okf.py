"""OKF markdown serialization helpers."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from datetime import datetime
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


class FrontmatterError(ValueError):
    """Frontmatter cannot be serialized as valid OKF metadata."""


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


def _normalize_metadata(metadata: Mapping[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for key, value in metadata.items():
        normalized[str(key)] = _normalize_value(value)
    return normalized


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


def _require_fields(metadata: Mapping[str, Any]) -> None:
    missing = [
        field
        for field in REQUIRED_FRONTMATTER_FIELDS
        if field not in metadata or metadata[field] in (None, "", [])
    ]
    if missing:
        raise FrontmatterError(f"missing required frontmatter fields: {', '.join(missing)}")