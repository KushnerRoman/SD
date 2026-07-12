from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.cleanup import cleanup_operational_data
from app.database import SessionLocal


CONFIRMATION_FLAG = "--confirm-delete-operational-data"


def main() -> int:
    if sys.argv[1:] != [CONFIRMATION_FLAG]:
        print(f"Refusing cleanup: pass exactly {CONFIRMATION_FLAG}.", file=sys.stderr)
        return 2

    with SessionLocal() as session:
        result = cleanup_operational_data(session, commit=True)
    print(json.dumps(result.model_dump(), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
