import asyncio

from app.google.scheduler import GoogleSyncScheduler


def test_scheduler_runs_immediately_then_every_interval_and_cancels_cleanly():
    asyncio.run(_cadence_case())


async def _cadence_case():
    calls = 0
    sleeps = []
    release = asyncio.Event()

    async def sync():
        nonlocal calls
        calls += 1

    async def sleep(seconds):
        sleeps.append(seconds)
        if len(sleeps) == 1:
            return
        await release.wait()

    scheduler = GoogleSyncScheduler(sync, interval=90, sleep=sleep)
    scheduler.start()
    await asyncio.sleep(0)
    await asyncio.sleep(0)
    assert calls == 2
    assert sleeps == [90, 90]
    await scheduler.stop()
    assert scheduler.task is None


def test_run_once_never_overlaps():
    asyncio.run(_overlap_case())


async def _overlap_case():
    entered = asyncio.Event()
    release = asyncio.Event()
    calls = 0

    async def sync():
        nonlocal calls
        calls += 1
        entered.set()
        await release.wait()

    scheduler = GoogleSyncScheduler(sync)
    first = asyncio.create_task(scheduler.run_once())
    await entered.wait()
    assert await scheduler.run_once() is False
    release.set()
    assert await first is True
    assert calls == 1
