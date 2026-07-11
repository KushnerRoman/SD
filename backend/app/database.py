from __future__ import annotations

import os
from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine
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
