from __future__ import annotations

import asyncio
import contextlib
from collections.abc import Awaitable, Callable


class AsyncioClock:
    async def sleep(self, seconds: float) -> None:
        await asyncio.sleep(seconds)


class GoogleSyncScheduler:
    """One local periodic worker with skip-on-overlap semantics."""

    def __init__(
        self,
        sync: Callable[[], Awaitable[None]],
        *,
        interval: float = 90,
        clock: AsyncioClock | None = None,
    ) -> None:
        self._sync = sync
        self._interval = interval
        self._clock = clock or AsyncioClock()
        self._claimed = False
        self._stopping = False
        self.task: asyncio.Task[None] | None = None

    async def run_once(self) -> bool:
        # No await occurs between checking and setting this event-loop-owned
        # flag, so claiming a run is atomic with respect to other tasks.
        if self._claimed or self._stopping:
            return False
        self._claimed = True
        try:
            await self._sync()
            return True
        finally:
            self._claimed = False

    async def _run(self) -> None:
        while not self._stopping:
            try:
                await self.run_once()
            except asyncio.CancelledError:
                raise
            except Exception:
                # A provider outage must not kill future sync attempts.
                pass
            if not self._stopping:
                await self._clock.sleep(self._interval)

    def start(self) -> None:
        if self.task is None or self.task.done():
            self._stopping = False
            self.task = asyncio.create_task(self._run(), name="google-sync")

    async def stop(self) -> None:
        task = self.task
        if task is None:
            return
        self._stopping = True
        if not self._claimed:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
        else:
            await task
        self.task = None
