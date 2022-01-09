from .core import Fraktal as _Fractal
from threading import Lock
from contextlib import asynccontextmanager
from functools import partial
import sys
from dataclasses import dataclass
from typing import Callable
from inspect import iscoroutine

from PIL import Image

import trio

class RenderStoppedError(RuntimeError):
    pass

##
# The Fractal class implements a work queue, to sync between a render task,
# the GUI, and any changes the latter wants to apply to the former.
#
# Theory of operation:
# 
# the GUI calls do_work(subclass-of-_Apply())
#
# Workers are accumulated until the's a (short) timeout, or an ApplyNow
# subclass is queued.
#
# If any workers' `breaks` flag is set, the current render (if any) will be
# halted; otherwise the system waits for it to end.
#
# With rendering blocked, each worker's `apply` method is called. If any
# of these returns True, rendering will start.
#
# A Render process is started.
#
# Last, every worker's `done` method is called, asynchronously, with a flag
# stating whether the render completed (True), didn't happen (None) or was
# cancelled by subsequent work (False). In the latter case
# `wait_render_done` may be used to delay until a 
##

class _Apply:
    renders:bool = False
    # Flag whether the worker requires rendering
    # also set by `apply` method

    breaks:bool = False
    # Flag whether to interrupt an ongoing render

    delay:float = 0.2
    # Max time to wait for new commands before we go ahead

    def apply(self,kf):
        """
        Called to do actual work.

        Returns a flag whether to trigger a re-render.
        """
        return False

    def trigger(self,ok):
        """
        Trigger further activities.

        Called directly after rendering stops. `ok` states whether the render finished.
        Obviously may not sleep (might cause deadlocks).
        """
        pass

    async def done(self,ok):
        """
        Activity completed.

        Called after rendering stops, in a separate task.
        """
        pass

class ApplyNow(_Apply):
    """trigger the workqueue immediately"""
    delay=0

class ApplyWork(ApplyNow):
    """run a job after rendering"""
    def __init__(self, name="?", work=None, trigger=None, done=None):
        self._worker = work
        self._trigger = trigger
        self._done = done
        self._name = name

    def __repr__(self):
        return f"ApplyWork:{self._name}"

    def apply(self, kf):
        if self._worker is not None:
            self._worker

    def trigger(self,ok):
        if self._trigger is not None:
            self._trigger()

    async def done(self,ok):
        if self._done is not None:
            res = self._done()
            if iscoroutine(res):
                res = await res

class ApplyRendered(ApplyNow):
    """wait for render to finish"""
    ok = None

    def __init__(self):
        self.evt = trio.Event()

    def trigger(self,ok):
        self.evt.set()
        self.ok = ok

    async def wait(self):
        await self.evt.wait()


@dataclass
class ApplySize(_Apply):
    """change the image size"""
    w:int
    h:int
    s:int

    breaks = True
    def apply(self, kf):
        if kf.getImageSize() == (self.w*self.s, self.h*self.s):
            return False
        kf.target_dimensions = (self.w,self.h,self.s)
        return True

@dataclass
class ApplyZoom(_Apply):
    x: int
    y: int
    size: float
    reuseCenter:bool = False
    centerView:bool = False

    breaks=True
    renders=True

    def apply(self,kf):
        kf.zoom(self.x,self.y,self.size)
        return True
         

class Fractal(_Fractal):
    r_done:trio.Event = None
    r_stopped:bool = None
    r_trigger:trio.Event = None
    r_working:trio.Event = None
    q_work = None
    q_render = None
    q_finish = None

    # four states:
    # - idle (r_done is None)
    # - rendering (r_working is set)
    # - rendering but waiting for stop
    # - locked doing something else

#   def __init__(self):
#       super().__init__()

    # This part does the actual rendering.
    # KF2 does this by signalling "WM_USER+199" and implementing the
    # clean-up work in the main thread, which is beyond ugly IMHO,
    # esp. since it duplicates code (interactive vs. batch).

    def _render_(self, reset_old_glitch=True, name="_render", color=True, **kw):
        """
        The actual rendering code. Takes care of de-glitching and display.
        """
        if self.stop_render:
            return
        self.log("info", f"Start render {name}")
        self.add_references = 0
        if reset_old_glitch:
            self.resetGlitches()

        super().fixIterLimit()
        super().renderFractal()
        super().fixIterLimit()

        if self.auto_solve_glitches and self.auto_glitch:
            for r in range(2,self.max_references):
                if self.stop_render:
                    break
                self.auto_glitch = r
                n = self.findCenterOfGlitch()
                if n is None:
                    self.log("info", "No more glitches")
                    break
                x,y,n = n
                self.log("info", f"reference {r} at ({x},{y}) size {n-1}")
                self.addReference(x,y)
                super().renderFractal()
                super().fixIterLimit()
        else:
            self.log("info", "No glitch fixing")
        if color:
            self.applyColors()
        self.log("info", f"Stop render {name}" if self.stop_render else f"End render {name}")

    def _render(self, **kw):
        try:
            self._render_(**kw)
        finally:
            trio.from_thread.run_sync(self.r_working.set)


    i=1
    @asynccontextmanager
    async def render_lock(self, kill=False, run=False, **kw):
        """
        Lock out rendering.
        Use this context manager to ensure that the renderer is not running
        while you modify its internals.

        Params:
            kill: if True, terminate a render in progress.
                  if False (the default), wait.
                  if None, die.
            run: start a render job after unlocking.
        """
        i=self.i; self.i+=1
        name = kw.setdefault("name","render_lock")

        self.log("debug",f"lock {i} {name}")

        if kill is None and self.r_done is not None:
            raise RuntimeError(f"already locked, {name}")
        if kill:
            self.stop_render = True
        evt2 = trio.Event()
        evt,self.r_done = self.r_done,evt2

        if evt is not None:
            await evt.wait()
            self.log("debug",f"locked {i} {name}")
        else:
            self.log("debug",f"locked {i} {name} NOWAIT")
        try:

            self.stop_render = False
            yield self

            if run:
                kw["name"] = name+" RUN"
                kw["kill"] = True
                self.n.start_soon(partial(self.render, **kw))
        finally:
            self.log("debug",f"done {i} {name}")
            self.stop_render = False
            if self.r_done is evt2:
                self.r_done = None
            evt2.set()

    @property
    def is_locked(self):
        return self.r_done is not None

    @property
    def is_rendering(self):
        return self.r_working is not None

    def not_rendering(self):
        """
        Check whether we are properly locked.
        """
        if self.r_done is None:
            raise RuntimeError("don't do this without a lock")
        if self.r_working is not None:
            raise RuntimeError("don't do this while rendering")
        # TODO check whether the correct thread has the lock

    _waitdone = None
    async def wait_render_done(self):
        """wait until a successful render"""
        if self._waitdone is not None:
            await self._waitdone.wait()
            return
        self._waitdone = trio.Event()
        w = ApplyRendered()
        while True:
            self.do_work(w)
            await w.wait()
            if w.ok is not False:
                self._waitdone.set()
                self._waitdone = None
                return w.ok

    async def render(self, **kw):
        """
        Render an image.

        This method takes the render lock.

        Parameters:
            name: a unique str that IDs the calling code, for tracing.
            reset_old_glitch: call resetGlitches
            stop_ok: silently terminate this renderer if it is killed.
            color: run applyColors afterwards.
            kill: if False, silently return if a renderer is already running.
                  if True, kill the other renderer.
                  if None (the default), raises RuntimeError.
        """
        kw.setdefault("name","render")
        kw.setdefault("kill",None)
        self.log("debug",f"render locking {kw}")
        async with self.render_lock(run=False, **kw):
            await self.render_locked(**kw)

    async def render_locked(self, stop_ok=False, **kw):
        """
        See `render`.

        The render lock must already have been taken.
        """
        self.log("debug","render locked")
        if self.r_working is not None:
            raise RuntimeError(f"Locked for render but WORKING is on")

        self.r_working = trio.Event()
        try:
            await trio.to_thread.run_sync(partial(self._render, **kw), cancellable=True)
        except BaseException as exc:
            self.stop_render = True
            raise
        finally:
            with trio.CancelScope(shield=True):
                await self.r_working.wait()
            self.r_working = None

        if self.stop_render and not stop_ok:
            raise RenderStoppedError()

    def do_work(self, task):
        """Enqueue this work item"""
        self.log("debug","WorkA %r", task)
        if not self.q_work:
            self.q_work,rq = trio.open_memory_channel(1000)
            self.n.start_soon(self._mgr,"work",rq,self._work_task)
        self.q_work.send_nowait(task) 
        if task.breaks:
            self.stop_render = True

### Task management details

    async def _work_task(self, work, rq):
        breaks = False
        for w in work:
            self.log("debug","WorkB %r %s", w,w.breaks)
            if w.breaks:
                breaks = True
                break

        self.log("debug","WorkC %s",breaks)
        async with self.render_lock(kill=breaks, run=False, name="mgr"):
            for w in work:
                self.log("debug","WorkD %r", w)
                w.renders = w.apply(self) or w.renders
            while True:
                try:
                    with trio.fail_after(0.01):
                        w = await rq.receive()
                    w.renders = w.apply(self) or w.renders
                    work.append(w)
                except trio.TooSlowError:
                    break

        if not self.q_render:
            self.log("debug","WorkE")
            self.q_render,rq = trio.open_memory_channel(100)
            self.n.start_soon(self._mgr,"render",rq,self._render_task)
        for w in work:
            self.log("debug","WorkF %r", w)
            await self.q_render.send(w) 
        self.log("debug","WorkG")

    async def _render_task(self, work, rq):
        render = False
        for w in work:
            self.log("debug","RenderB %r %s", w,w.renders)
            render |= w.renders
        if render:
            try:
                await self.render(stop_ok=False)
            except RenderStoppedError:
                done = False
            else:
                done = True
        else:
            done = None

        for w in work:
            self.log("debug","WorkD %r %s", w,done)
            w.trigger(done)

        if self.q_finish is None:
            self.q_finish,rq= trio.open_memory_channel(10)
            self.n.start_soon(self._done_task,rq)
        await self.q_finish.send((done,work))

    async def _done_task(self, rq):
        async for done,work in rq:
            for w in work:
                if w.renders and done is False:
                    self.log("debug","WorkE %r", w)
                    await self.wait_render_done()
                    done = True
                self.log("debug","WorkF %r %s", w,done)
                await w.done(done)

    async def _mgr(self, name, queue, worker, init_run=False):
        while True:
            work = []
            self.log("debug", f"mgr {name} A")
            try:
                delay = 99999
                while True:
                    with trio.fail_after(delay):
                        w = await queue.receive()
                        work.append(w)
                        self.log("debug", "mgr %s B %r %s", name,w,w.delay)
                        delay = min(w.delay,delay)
            except trio.TooSlowError:
                pass

            self.log("debug", f"mgr {name} C {len(work)}")
            await worker(work,queue)
            init_run = False

### Saving pretty pictures

    def save_frame(self, frame:int, only_kfr:bool, quality:int = 100,
            save_exr=None, save_tif=None, save_png=None, save_jpg=None, save_kfr=None, save_map=None):

        def fixname(fn):
            if '%' in fn:
                fn = fn % (frame,)
            return fn
        x,y,s = self.target_dimensions
        if not only_kfr:
            self.log("info","colouring final image")
            self.inhibit_colouring = False
            self.applyColors()
            img = self.pilImage # .resize((x,y), Image.LANCZOS)
        if save_exr:
            self.log("info", f"saving EXR {save_exr !r}")
            self.saveEXR(fixname(save_exr))
        if save_tif:
            self.log("info", f"saving TIFF {save_tif !r}")
            img.save(fixname(save_tif),format="tiff",compression="tiff_lzw")
        if save_png:
            self.log("info", f"saving PNG {save_png !r}")
            img.save(fixname(save_png),format="png")
        if save_jpg:
            self.log("info", f"saving JPG {save_jpg !r}")
            img.save(fixname(save_jpg),format="jpeg",quality=quality,optimize=True)
        if save_kfr:
            self.log("info", f"saving KFR {save_kfr !r}")
            self.saveKFR(fixname(save_kfr))
        if save_map:
            self.log("info", f"saving KFB {save_map !r}")
            self.saveKFR(fixname(save_map))

    async def render_frame(self, frame:int, only_kfr:bool, **save_args):
        self.inhibit_colouring = True
        self.interactive = False
        if not only_kfr:
            self.log("info", "reference 1 at center")
        if frame > 0:
            if self.jitter_seed:
                self.jitter_seed += 1
            if not only_kfr:
                self.fixIterLimit()
            self.setPosition(self.center_re, self.center_im, self. self.radius * self.zoom_size)
        if not only_kfr:
            await self.render()
        self.save_frame(frame, only_kfr, **save_args)


