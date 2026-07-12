from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.cleanup import operational_snapshot
from app.database import SessionLocal


def main() -> int:
    if len(sys.argv) != 1:
        print("Usage: print_counts.py", file=sys.stderr)
        return 2
    with SessionLocal() as session:
        print(json.dumps(operational_snapshot(session), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
