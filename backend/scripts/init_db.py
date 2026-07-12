from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.database import create_schema


def main() -> None:
    create_schema()
    print("Schema ready; operational data unchanged.")


if __name__ == "__main__":
    main()
