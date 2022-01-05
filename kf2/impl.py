from .core import Fraktal as _Fractal

from PIL import Image

import trio

class Fractal(_Fractal):
    r_done = None

    def __init__(self):
        super().__init__()

    # This part does the actual rendering.
    # KF2 does this by signalling "WM_USER+199" and implementing the
    # clean-up work in the main thread, which is beyond ugly IMHO,
    # esp. since it duplicates code (interactive vs. batch).

    def _render_sync(self):
        self.add_references = 0

        super().renderFractal()

        if self.auto_solve_glitches and self.auto_glitch:
            for r in range(2,self.max_references):
                self.auto_glitch = r
                n = findCenterOfGlitch()
                if n is None:
                    break
                x,y,n = n
                self.log

        # 

    def render_sync(self, **kw):
        try:
            self._render_sync(**kw)
        finally:

    def _render(self, kw):
        try:
            self.render_sync(**kw)
        finally:
            self.r_done.set()
            self.r_done = None

    async def render(self, **kw):
        self.r_done = trio.Event()
        await trio.to_thread.run_sync(self._render, kw)

    async def stopRender(self):
        evt = self.r_done
        if evt is None:
            return
        self.stop_render()
        await evt.wait()
        self.r_done = None



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
            self.inhibit_colouring = False
            self.applyColors()
        if save_exr:
            self.saveEXR(fixname(save_exr))
        if save_tif:
            img.save(fixname(save_tif),format="tiff",compression="tiff_lzw")
        if save_png:
            img.save(fixname(save_png),format="png")
        if save_jpg:
            img.save(fixname(save_jpg),format="jpeg",quality=quality,optimize=True)
        if save_kfr:
            self.saveKFR(fixname(save_kfr))
        if save_map:
            self.saveKFR(fixname(save_map))

    async def render_frame(self, frame:int, only_kfr:bool, **save_args):
        self.inhibit_colouring = True
        self.interactive = False
        if frame > 0:
            if self.jitter_seed:
                self.jitter_seed += 1
            if not only_kfr:
                self.fixIterLimit()
            self.setPosition(self.center_re, self.center_im, self. self.radius * self.zoom_size)
        if not only_kfr:
            print("R")
            await self.render()
        print("RD")
        self.save_frame(frame, only_kfr, **save_args)


