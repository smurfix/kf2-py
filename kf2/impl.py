from .core import Fraktal as _Fractal
from threading import Lock
from contextlib import asynccontextmanager
from functools import partial
import sys

from PIL import Image

import trio

class RenderStoppedError(RuntimeError):
    pass

class Fractal(_Fractal):
    r_done:trio.Event = None
    r_working:bool = False

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

    def _render(self, reset_old_glitch=True, name="_render", color=True):
        """
        The actual rendering code. Takes care of de-glitching and display.
        """
        self.log("info", f"Start render {name}")
        self.add_references = 0
        if reset_old_glitch:
            self.resetGlitches()

        super().renderFractal()

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
        else:
            self.log("info", "No glitch fixing")
        if color:
            self.applyColors()
        self.log("info", f"Stop render {name}" if self.stop_render else f"End render {name}")


    @asynccontextmanager
    async def render_lock(self, kill=False, run=False, stop_ok=False, **kw):
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
        name = kw.setdefault("name","render_lock")

        self.log("debug",f"lock {name}")

        if kill is None and self.r_done is not None:
            raise RuntimeError("already rendering, {name}")
        if kill:
            self.stop_render = True
        evt2 = trio.Event()
        evt,self.r_done = self.r_done,evt2

        if evt is not None:
            await evt.wait()
        try:
            if self.r_working:
                raise RuntimeError(f"Locked by {name} but WORKING is on")

            self.stop_render = True
            yield self

            if run:
                self.r_working = True
                self.stop_render = False
                await trio.to_thread.run_sync(partial(self._render, **kw))
                if self.stop_render and not stop_ok:
                    raise RenderStoppedError()
        finally:
            self.r_working = False
            self.stop_render = False
            if self.r_done is evt2:
                self.r_done = None
            evt2.set()

    @property
    def is_locked(self):
        return self.r_done is not None

    @property
    def is_rendering(self):
        return self.r_working

    def not_rendering(self):
        """
        Check whether we are properly locked.
        """
        if self.r_done is None:
            raise RuntimeError("don't do this without a lock")
        if self.r_working:
            raise RuntimeError("don't do this while rendering")
        # TODO check whether the correct thread has the lock

    async def wait_render_done(self):
        if self.r_done is not None:
            await self.r_done.wait()

    async def render(self, **kw):
        """
        Parameters:
            name: a unique str that IDs the calling code, for tracing.
            reset_old_glitch: call resetGlitches
            stop_ok: silently terminate this renderer if it is killed.
            color: run applyColors afterwards.
            kill: if False, silently return if a renderer is already running.
                  if True (the default), kill the other renderer.
                  if None, raises RuntimeError.
        """
        kw.setdefault("name","render")
        kw.setdefault("kill",True)
        kw.setdefault("stop_ok",False)
        async with self.render_lock(run=True,**kw):
            pass

    def render_start(self, **kw):
        """Start rendering in the background.

        Used from the user interface.

        Since it's a background task, don't die if it is stopped.
        """
        kw.setdefault("name","render_start")
        kw.setdefault("stop_ok",True)
        self.n.start_soon(partial(self._render,**kw))



    def save_frame(self, frame:int, only_kfr:bool, quality:int = 100,
            save_exr=None, save_tif=None, save_png=None, save_jpg=None, save_kfr=None, save_map=None):

        def fixname(fn):
            if '%' in fn:
                fn = fn % (frame,)
            return fn
        import pdb;pdb.set_trace()
        x,y,s = self.target_dimensions
        img = self.pilImage # .resize((x,y), Image.LANCZOS)
        if not only_kfr:
            self.log("info","colouring final image")
            self.inhibit_colouring = False
            self.applyColors()
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


