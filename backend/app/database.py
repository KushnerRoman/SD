from __future__ import annotations

import os
from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    pass


def database_url() -> str:
    default_path = (Path(__file__).resolve().parents[1] / "security_depot.db").as_posix()
    return os.getenv(
        "DATABASE_URL",
        f"sqlite+pysqlite:///{default_path}",
    )


engine = create_engine(database_url(), pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_session() -> Generator[Session, None, None]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def create_schema() -> None:
    import app.models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    upgrade_sqlite_schema(engine)


def upgrade_sqlite_schema(bind: Engine) -> None:
    """Apply the small additive Gmail migration supported by legacy SQLite installs."""
    if bind.dialect.name != "sqlite":
        return
    additions = {
        "email_messages": {"provider_id": "VARCHAR(255)", "history_id": "VARCHAR(255) NOT NULL DEFAULT ''"},
        "google_credentials": {"gmail_history_id": "VARCHAR(255)"},
    }
    with bind.begin() as connection:
        table_names = set(inspect(connection).get_table_names())
        for table, columns in additions.items():
            if table not in table_names:
                continue
            present = {item["name"] for item in inspect(connection).get_columns(table)}
            for name, ddl in columns.items():
                if name not in present:
                    connection.exec_driver_sql(f'ALTER TABLE "{table}" ADD COLUMN "{name}" {ddl}')
        if "email_messages" in table_names:
            connection.exec_driver_sql(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_email_messages_provider_id ON email_messages (provider_id)"
            )
