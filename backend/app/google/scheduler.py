from __future__ import annotations

import asyncio
import contextlib
from collections.abc import Awaitable, Callable


class GoogleSyncScheduler:
    """One local periodic worker with skip-on-overlap semantics."""

    def __init__(
        self,
        sync: Callable[[], Awaitable[None]],
        *,
        interval: float = 90,
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        self._sync = sync
        self._interval = interval
        self._sleep = sleep
        self._lock = asyncio.Lock()
        self.task: asyncio.Task[None] | None = None

    async def run_once(self) -> bool:
        if self._lock.locked():
            return False
        async with self._lock:
            await self._sync()
        return True

    async def _run(self) -> None:
        while True:
            try:
                await self.run_once()
            except asyncio.CancelledError:
                raise
            except Exception:
                # A provider outage must not kill future sync attempts.
                pass
            await self._sleep(self._interval)

    def start(self) -> None:
        if self.task is None or self.task.done():
            self.task = asyncio.create_task(self._run(), name="google-sync")

    async def stop(self) -> None:
        task, self.task = self.task, None
        if task is None:
            return
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
