from datetime import datetime, timezone

import pytest
import yaml

from orange_red.okf import (
    ConformanceError,
    FrontmatterError,
    serialize_concept,
    validate_okf_markdown,
)


def test_serialize_concept_writes_required_frontmatter_and_microsecond_timestamp() -> None:
    concept = serialize_concept(
        {
            "type": "Documentation",
            "title": "Ops Guide",
            "description": "Runbook",
            "resource": "https://intranet.example/ops",
            "tags": ["ops"],
            "timestamp": datetime(2026, 7, 9, 12, 13, 14, tzinfo=timezone.utc),
        },
        "# Ops\n\nUse this runbook.",
    )

    frontmatter, body = concept.removeprefix("---\n").split("\n---\n\n", 1)
    metadata = yaml.safe_load(frontmatter)

    assert metadata == {
        "type": "Documentation",
        "title": "Ops Guide",
        "description": "Runbook",
        "resource": "https://intranet.example/ops",
        "tags": ["ops"],
        "timestamp": "2026-07-09T12:13:14.000000+00:00",
    }
    assert body == "# Ops\n\nUse this runbook.\n"


def test_serialize_concept_rejects_missing_required_fields() -> None:
    with pytest.raises(
        FrontmatterError,
        match="missing required frontmatter fields: resource",
    ):
        serialize_concept(
            {
                "type": "Documentation",
                "title": "Ops Guide",
                "description": "Runbook",
                "tags": ["ops"],
                "timestamp": "2026-07-09T12:13:14.000000+00:00",
            },
            "# Ops",
        )


def test_serialize_concept_rejects_timestamp_without_microseconds() -> None:
    with pytest.raises(
        FrontmatterError,
        match="timestamp must include microsecond precision",
    ):
        serialize_concept(
            {
                "type": "Documentation",
                "title": "Ops Guide",
                "description": "Runbook",
                "resource": "https://intranet.example/ops",
                "tags": ["ops"],
                "timestamp": "2026-07-09T12:13:14+00:00",
            },
            "# Ops",
        )


def test_validate_okf_markdown_accepts_conformant_concept() -> None:
    concept = serialize_concept(
        {
            "type": "Documentation",
            "title": "Ops Guide",
            "description": "Runbook",
            "resource": "https://intranet.example/ops",
            "tags": ["ops"],
            "timestamp": "2026-07-09T12:13:14.000000+00:00",
        },
        "# Ops",
    )

    validate_okf_markdown("example.test/ops.md", concept)


def test_validate_okf_markdown_rejects_missing_required_concept_field() -> None:
    with pytest.raises(
        ConformanceError,
        match="missing required frontmatter fields: resource",
    ):
        validate_okf_markdown(
            "example.test/ops.md",
            "---\n"
            "type: Documentation\n"
            "title: Ops Guide\n"
            "description: Runbook\n"
            "tags:\n"
            "  - ops\n"
            "timestamp: '2026-07-09T12:13:14.000000+00:00'\n"
            "---\n"
            "# Ops\n",
        )


def test_validate_okf_markdown_rejects_concept_frontmatter_on_reserved_index() -> None:
    with pytest.raises(ConformanceError, match="index.md reserved frontmatter fields"):
        validate_okf_markdown(
            "example.test/index.md",
            serialize_concept(
                {
                    "type": "Documentation",
                    "title": "Ops Guide",
                    "description": "Runbook",
                    "resource": "https://intranet.example/ops",
                    "tags": ["ops"],
                    "timestamp": "2026-07-09T12:13:14.000000+00:00",
                },
                "# Ops",
            ),
        )


def test_validate_okf_markdown_rejects_concept_frontmatter_on_reserved_log() -> None:
    with pytest.raises(
        ConformanceError,
        match="log.md must not use concept frontmatter",
    ):
        validate_okf_markdown(
            "example.test/log.md",
            serialize_concept(
                {
                    "type": "Documentation",
                    "title": "Ops Guide",
                    "description": "Runbook",
                    "resource": "https://intranet.example/ops",
                    "tags": ["ops"],
                    "timestamp": "2026-07-09T12:13:14.000000+00:00",
                },
                "# Ops",
            ),
        )


def test_validate_okf_markdown_accepts_reserved_index_and_log_shapes() -> None:
    validate_okf_markdown(
        "index.md",
        "---\nokf_version: '0.1'\n---\n\n# Index\n",
    )
    validate_okf_markdown(
        "example.test/log.md",
        "2026-07-09T12:13:14.000000+00:00 **Creation** example.test/ops.md\n",
    )
