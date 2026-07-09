"""initial pgvector schema."""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0001_initial_pgvector_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")
    op.create_table(
        "concept",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("path", sa.Text(), nullable=False),
        sa.Column("type", sa.Text(), nullable=False),
        sa.Column("resource_url", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("content_hash", sa.Text(), nullable=False),
        sa.UniqueConstraint("path", name="uq_concept_path"),
    )
    op.create_table(
        "run",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("start_url", sa.Text(), nullable=True),
        sa.Column("bundle_ref", sa.Text(), nullable=True),
        sa.Column("git_commit_sha", sa.Text(), nullable=True),
        sa.CheckConstraint("kind IN ('crawl', 'index')", name="ck_run_kind"),
    )
    op.execute(
        """
        CREATE TABLE chunk (
            concept_id bigint NOT NULL REFERENCES concept(id) ON DELETE CASCADE,
            ord integer NOT NULL,
            text text NOT NULL,
            embedding vector(3072) NOT NULL,
            PRIMARY KEY (concept_id, ord)
        )
        """
    )
    op.create_table(
        "error",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("run_id", sa.BigInteger(), sa.ForeignKey("run.id", ondelete="CASCADE"), nullable=False),
        sa.Column("url", sa.Text(), nullable=True),
        sa.Column("path", sa.Text(), nullable=True),
        sa.Column("stage", sa.Text(), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("error")
    op.drop_table("chunk")
    op.drop_table("run")
    op.drop_table("concept")
    op.execute("DROP EXTENSION IF EXISTS vector")