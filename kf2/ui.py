import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GLib', '2.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk as gtk
from gi.repository import Gdk as gdk
from gi.repository import GObject as gobject
from gi.repository import GLib as glib

import cairo
import trio

from PIL import Image

class UI:
    render_updater = None
    skip_update = 2
    resized = None

    def __init__(self, kf):
        self.kf = kf
        self.widgets = gtk.Builder()
        self.widgets.add_from_file("kf2/kf2.glade")

        d = {}
        for k in dir(type(self)):
            if k[0] == "_":
                continue
            d[k] = getattr(self,k)
        self.widgets.connect_signals(d)

        img = self["TheImage"]
        signal_id = gobject.signal_lookup("draw",img)
        self.draw_handler_id = gobject.signal_handler_find(img, gobject.SignalMatchType.ID, signal_id, 0, None, 0, 0)

    def __getitem__(self,name):
        return self.widgets.get_object(name)

    def on_test(self, *x):
        print("TEST")
        breakpoint()

    def on_activate(self, *x):
        self.kf.log("debug","RUN",x)

    def on_main_destroy(self,window):
        # main window goes away
        self.done.set()

    def on_main_delete(self,window,event):
        # True if the window should not be deleted
        return False

    def on_img_scroll(self, *x):
        self.kf.log("debug","SCROLL",x)

    def on_img_ptrmove(self, area, evt):
        # self.kf.log("debug","MOVE",evt.x,evt.y)
        pass

    def on_fractal_draw(self, area, ctx):
        if self.skip_update:
            self.kf.log("debug","NODRAW")
            return True
        img = cairo.ImageSurface.create_for_data(self.kf.image_bytes, cairo.FORMAT_RGB24, self.kf.image_width, self.kf.image_height)

        r = self["TheImage"].get_allocation()
        m = cairo.Matrix()
        m.yy = -1.0
        rr=area.get_allocated_size()[0]
        m.y0 = r.height
        m.translate(rr.x,-rr.y)
        m.scale(r.width/self.kf.image_width, r.height/self.kf.image_height)
        self.kf.log("debug","DRAW %r", m)
        ctx.set_matrix(m)
        ctx.set_source_surface(img, 0, 0)
        ctx.paint()

    def on_quit_button_clicked(self,x):
        self.done.set()

    def draw_fractal(self):
        img = self["TheImage"]
        self["TheImage"].queue_draw_area(0,0,self.kf.image_width, self.kf.image_height)

    def on_imgsize_changed(self,*x):
        self.update_image_size()

    def update_image_size(self, resize=None):
        """update image size from on-screen window"""
        # XXX test code, ideally should not do this

        img = self["TheImage"]
        r = img.get_allocation()
        if not resize:
            self["TheImage"].queue_draw_area(0,0,r.width, r.height)
            return

        self.resize_image_to(r.width,r.height)

    def resize_image_to(self, w,h):
        self.kf.log("debug","resize to %d %d",w,h)
        r = self.resized
        if r is None:
            self.resized = r = [trio.Event(),0,0]
            self.kf.n.start_soon(self._resize_task)
        r[1:] = w,h
        r[0].set()

    async def _resize_task(self):
        while self.resized is not None:
            self.kf.log("debug","RESZ")
            try:
                while self.resized is not None:
                    with trio.fail_after(0.2):
                        await self.resized[0].wait()
                    self.resized[0] = trio.Event()
            except trio.TooSlowError:
                pass
            if self.resized is None:
                self.kf.log("debug","RESZ Y")
                return
            e,w,h = self.resized
            if self.kf.getImageSize() == (w,h):
                break

            self.kf.log("debug","RESZ A %r %r", self.kf.getImageSize(), (w,h))
            async with self.kf.render_lock(kill=True, run=False, name="UI resize"):
                self.kf.log("debug","RESZ B %d %d", w,h)
                self.kf.setImageSize(*self.resized[1:3])
                self.start_render_updater()
                await self.kf.render_locked(stop_ok=True,name="Resizer")
        self.kf.log("debug","RESZ X")
        self.resized = None

    def render_idle(self):
        if not self.kf.is_rendering:
            if self.kf.is_locked:
                return True
            self.kf.log("debug","IDLE E")
            self.skip_update = 0
            self.draw_fractal()
            self.render_updater = None
            return False

        if self.skip_update:
            self.kf.log("debug","IDLE S")
            self.skip_update -= 1
        else:
            #self.kf.log("debug","IDLE P")
            self.draw_fractal()
        return True

    def start_render_updater(self):
        if self.render_updater is None:
            self.render_updater = glib.timeout_add(100, self.render_idle)

    async def run(self):
        self.done = trio.Event()
        self['main'].show_all()
        self.update_image_size(True)
        self.start_render_updater()
        await self.done.wait()

