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
        self.kf.log("debug","DRAW")
        img = cairo.ImageSurface.create_for_data(self.kf.image_bytes, cairo.FORMAT_RGB24, self.kf.image_width, self.kf.image_height)
        ctx.set_source_surface(img, 0, 0)

        r = self["TheImage"].get_allocation()
        ctx.scale(self.kf.image_width/r.width, self.kf.image_height/r.height)

        ctx.paint()

    def on_quit_button_clicked(self,x):
        self.done.set()

    def draw_fractal(self):
        img = self["TheImage"]
        self["TheImage"].queue_draw_area(0,0,self.kf.image_width, self.kf.image_height)


    def on_imgsize_changed(self,*x):
        self.update_image_size()

    def update_image_size(self):
        self.kf.log("debug","UPD_SZ")
        """update image size from on-screen window"""
        # XXX test code, ideally should not do this
        img = self["TheImage"]

        r = img.get_allocation()
        self.kf.n.start_soon(self._resize,r.width,r.height)

    async def _resize(self,w,h):
        self.kf.log("debug","RESZ")
        async with self.kf.render_lock(kill=True, run=True, name="UI resize"):
            self.kf.log("debug","RESZ B")
            self.kf.setImageSize(w,h)
        self.start_render_updater()
        self.kf.log("debug","RESZ D")

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
            self.kf.log("debug","IDLE P")
            self.draw_fractal()
        return True

    def start_render(self):
        self.kf.log("debug","SR")
        self.skip_update = 2
        self.kf.render_start(kill=True, ignore_stop=True)
        self.start_render_updater()

    def start_render_updater(self):
        if self.render_updater is None:
            self.render_updater = glib.timeout_add(100, self.render_idle)

    async def run(self):
        self.done = trio.Event()
        self['main'].show_all()
        self.update_image_size()
        await self.done.wait()

