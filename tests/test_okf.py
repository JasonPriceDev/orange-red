from datetime import datetime, timezone

import pytest
import yaml

from orange_red.okf import FrontmatterError, serialize_concept


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
