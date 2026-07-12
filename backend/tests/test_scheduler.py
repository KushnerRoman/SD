import asyncio
import threading
from fastapi.testclient import TestClient
from app.main import app, get_calendar_provider, get_google_sync_coordinator

from app.google.scheduler import GoogleSyncScheduler


class FakeClock:
    def __init__(self):
        self.now = 0.0
        self.waiters = []

    async def sleep(self, seconds):
        loop = asyncio.get_running_loop()
        future = loop.create_future()
        self.waiters.append((self.now + seconds, future))
        await future

    async def advance(self, seconds):
        self.now += seconds
        due = [item for item in self.waiters if item[0] <= self.now]
        self.waiters = [item for item in self.waiters if item[0] > self.now]
        for _, future in due:
            future.set_result(None)
        await asyncio.sleep(0)


def test_manual_sync_runs_gmail_and_calendar_as_one_composite(monkeypatch):
    calls = []
    class Gmail:
        def sync_gmail(self, session):
            calls.append("gmail")
            return type("Counts", (), {"added": 1, "updated": 2, "deleted": 3})()
    app.dependency_overrides[get_google_sync_coordinator] = lambda: Gmail()
    app.dependency_overrides[get_calendar_provider] = lambda: object()
    monkeypatch.setattr("app.main.process_calendar_outbox", lambda session, provider: calls.append("calendar") or 4)
    try:
        response = TestClient(app).post("/google/sync")
    finally:
        app.dependency_overrides.clear()
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "added": 1, "updated": 2, "deleted": 3, "calendar_delivered": 4}
    assert calls == ["gmail", "calendar"]


def test_manual_sync_cannot_overlap_scheduled_composite():
    from app import main
    class Gmail:
        def sync_gmail(self, session):
            raise AssertionError("busy composite must not start")
    app.dependency_overrides[get_google_sync_coordinator] = lambda: Gmail()
    app.dependency_overrides[get_calendar_provider] = lambda: object()
    main._google_sync_lock.acquire()
    try:
        response = TestClient(app).post("/google/sync")
        assert response.status_code == 409
    finally:
        main._google_sync_lock.release()
        app.dependency_overrides.clear()


def test_lifespan_owns_exactly_one_scheduler_task():
    with TestClient(app):
        scheduler = app.state.google_sync_scheduler
        task = scheduler.task
        assert task is not None
        scheduler.start()
        assert scheduler.task is task
    assert scheduler.task is None


def test_scheduler_runs_immediately_then_every_interval_and_cancels_cleanly():
    asyncio.run(_cadence_case())


async def _cadence_case():
    calls = 0
    clock = FakeClock()

    async def sync():
        nonlocal calls
        calls += 1

    scheduler = GoogleSyncScheduler(sync, interval=90, clock=clock)
    scheduler.start()
    await asyncio.sleep(0)
    assert calls == 1
    await scheduler.stop()
    assert scheduler.task is None


def test_fake_clock_requires_full_ninety_seconds_before_second_run():
    async def case():
        calls = 0; clock = FakeClock()
        async def sync():
            nonlocal calls
            calls += 1
        scheduler = GoogleSyncScheduler(sync, interval=90, clock=clock)
        scheduler.start(); await asyncio.sleep(0)
        assert calls == 1
        await clock.advance(89)
        assert calls == 1
        await clock.advance(1); await asyncio.sleep(0)
        assert calls == 2
        await scheduler.stop()
    asyncio.run(case())


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


def test_scheduler_survives_exception_and_runs_next_cadence():
    async def case():
        calls = 0
        clock = FakeClock()
        async def sync():
            nonlocal calls
            calls += 1
            if calls == 1: raise RuntimeError("provider down")
        scheduler = GoogleSyncScheduler(sync, interval=90, clock=clock)
        scheduler.start()
        await asyncio.sleep(0); await clock.advance(90); await asyncio.sleep(0)
        assert calls == 2
        await scheduler.stop()
    asyncio.run(case())


def test_shutdown_waits_for_inflight_sync_and_no_work_runs_after_exit():
    async def case():
        entered = asyncio.Event(); release = asyncio.Event(); calls = 0; completed = False
        async def sync():
            nonlocal calls, completed
            calls += 1; entered.set(); await release.wait(); completed = True
        scheduler = GoogleSyncScheduler(sync)
        scheduler.start(); await entered.wait()
        stopping = asyncio.create_task(scheduler.stop())
        await asyncio.sleep(0)
        assert not stopping.done()
        release.set(); await stopping; await asyncio.sleep(0)
        assert calls == 1
        assert completed is True
    asyncio.run(case())


def test_start_is_idempotent_and_owns_exactly_one_task():
    async def case():
        async def sync(): await asyncio.Event().wait()
        scheduler = GoogleSyncScheduler(sync)
        scheduler.start(); task = scheduler.task; scheduler.start()
        assert scheduler.task is task
        await scheduler.stop()
    asyncio.run(case())


def test_shutdown_joins_inflight_threaded_work():
    async def case():
        entered = threading.Event(); release = threading.Event(); completed = threading.Event()
        def blocking():
            entered.set(); release.wait(); completed.set()
        async def sync(): await asyncio.to_thread(blocking)
        scheduler = GoogleSyncScheduler(sync); scheduler.start()
        await asyncio.to_thread(entered.wait)
        stopping = asyncio.create_task(scheduler.stop()); await asyncio.sleep(0)
        assert not stopping.done()
        release.set(); await stopping
        assert completed.is_set()
    asyncio.run(case())
