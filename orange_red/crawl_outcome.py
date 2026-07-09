"""Crawler URL outcome taxonomy."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class CrawlOutcomeKind(StrEnum):
    """Meaning of a URL outcome for crawl exit behavior."""

    IGNORED = "ignored"
    SKIPPED = "skipped"
    REQUIRED_FAILED = "required-failed"
    SUCCEEDED = "succeeded"


@dataclass(frozen=True, slots=True)
class CrawlOutcome:
    url: str
    kind: CrawlOutcomeKind
    stage: str
    message: str

    @property
    def exits_nonzero(self) -> bool:
        return self.kind is CrawlOutcomeKind.REQUIRED_FAILED