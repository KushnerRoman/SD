from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database import SessionLocal, create_schema
from app.seed_loader import load_seed_file, reset_and_load_seed


def main() -> None:
    create_schema()
    with SessionLocal() as session:
        counts = reset_and_load_seed(session, load_seed_file())
    print(counts)


if __name__ == "__main__":
    main()
