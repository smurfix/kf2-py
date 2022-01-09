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

from .impl import ApplySize, ApplyZoom, ApplyWork

class UI:
    render_updater = None
    skip_update = 2
    work = None

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

    def on_debug(self, *x):
        print("DEBUG",x)
        breakpoint()

    def on_activate(self, *x):
        self.kf.log("debug","RUN",x)

    def on_main_destroy(self,window):
        # main window goes away
        self.done.set()

    def on_main_delete(self,window,event):
        # True if the window should not be deleted
        return False

    def on_img_scroll(self, area, btn):
        t = btn.get_scroll_direction()
        #if not t[0]:  # XXX unnamed? relevant?
        #    return
        if t.direction == gdk.ScrollDirection.UP:  # zoom in
            self.kf.log("debug","SCROLL %r %r",btn.get_scroll_direction(),btn.get_coords())
            x,y = btn.get_coords()
            
            r = area.get_allocation()
            self.kf.do_work(ApplyZoom(x*self.kf.nX/r.width, y*self.kf.nY/r.height, self.kf.zoom_size))
            self.start_render_updater()
            pass
        elif t.direction == gdk.ScrollDirection.DOWN:  # zoom out
            self.kf.log("debug","SCROLL %r %r",btn.get_scroll_direction(),btn.get_coords())
            x,y = btn.get_coords()
            
            r = area.get_allocation()
            self.kf.do_work(ApplyZoom(x*self.kf.nX/r.width, y*self.kf.nY/r.height, 1/self.kf.zoom_size))
            self.start_render_updater()
        else:
            self.kf.log("debug","SCROLL %r %r",btn.get_scroll_direction(),btn.get_coords())

    def on_menu_quit(self, item):
        self.done.set()
        pass
    def on_menu_settings_save(self, item):
        pass
    def on_menu_settings_open(self, item):
        pass
    def on_menu_export_kfb(self, item):
        pass
    def on_menu_set_exr_channels(self, item):
        pass
    def on_menu_export_exr(self, item):
        pass
    def on_menu_export_tiff(self, item):
        pass
    def on_menu_export_jpeg(self, item):
        pass
    def on_menu_export_png(self, item):
        pass
    def on_menu_export_kfr(self, item):
        pass
    def on_menu_save(self, item):
        pass
    def on_menu_open_map(self, item):
        pass
    def on_menu_open(self, item):
        pass

    def on_img_ptrmove(self, area, evt):
        # self.kf.log("debug","MOVE",evt.x,evt.y)
        pass

    def on_img_button(self, area, btn):
        self.kf.log("debug","BTN %r",btn.button)

    def on_img_button_release(self, area, btn):
        self.kf.log("debug","!BTN %r",btn)

    def on_img_draw(self, area, ctx):
        if self.skip_update or not self.kf.nX or not self.kf.nY:
            self.kf.log("debug","NODRAW %s",self.skip_update)
            return True
        self.kf.log("debug","DRAW")
        img = cairo.ImageSurface.create_for_data(self.kf.image_bytes, cairo.FORMAT_RGB24, self.kf.image_width, self.kf.image_height)

        r = area.get_allocation()
        m = cairo.Matrix()
        m.yy = -1.0
        rr = area.get_allocated_size()[0]
        m.y0 = r.height
        m.translate(rr.x,-rr.y)
        sx = r.width/self.kf.image_width
        sy = r.height/self.kf.image_height

        if sx > sy:
            m.scale(sy,sy)
            m.x0 += (sx-sy)*self.kf.image_width/2
        else:
            m.scale(sx,sx)
            if sx < sy:
                m.y0 -= (sy-sx)*self.kf.image_height/2
        # self.kf.log("debug","DRAW %r", m)
        ctx.set_matrix(m)
        ctx.set_source_surface(img, 0, 0)
        ctx.paint()

    def on_quit_button_clicked(self,x):
        self.done.set()

    def draw_fractal(self):
        self.kf.log("debug","Draw")
        img = self["TheImage"]
        img.queue_draw()

    def on_imgsize_changed(self,*x):
        self.resize_redisplay() # works
        #self.resize_fractal_to_viewport() # works somewhat

    def resize_viewport_to_fractal(self):
        """
        Set the viewport size to whatever the fractal is, possibly downscaled.
        """
        self.kf.log("debug","Resize View>F")
        w,h,s = self.kf.target_dimensions
        img = self["TheImage"]
        img.set_size_request(w,h)
        self.kf.do_work(ApplySize(w,h,s))
        self.kf.do_work(ApplyWork(done=self._minsize))

    def resize_fractal_to_viewport(self):
        """
        Set the fractal size to whatever the viewport is, possibly upscaled.
        """
        self.kf.log("debug","Resize F>View")
        img = self["TheImage"]
        r = img.get_allocation()
        w,h,s = self.kf.target_dimensions
        self.kf.do_work(ApplySize(r.width, r.height, s))
        self.start_render_updater()

    def resize_redisplay(self):
        """
        Recsale the fractal into the viewport, possibly distorting it.
        """
        self.kf.log("debug","Resize")

        img = self["TheImage"]
        img.queue_draw()

    async def _resize_task(self):
        while self.resized is not None:
            self.kf.log("debug","RESZ")
            work = []
            try:
                while self.resized is not None:
                    with trio.fail_after(0.2):
                        work.append(await self.resized.get())
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

    _show_render_lock = 0

    def show_render(self):
        if not self._show_render_lock:
            self.skip_update = 0
            self.render_updater = None
            self.kf.log("debug","IDLE E")
            self.draw_fractal()
            return False
        
        if self.skip_update:
            self.kf.log("debug","IDLE S")
            self.skip_update -= 1
        else:
            self.kf.log("debug","IDLE P")
            self.draw_fractal()
        return True

    def _dec_render_lock(self):
        assert self._show_render_lock > 0
        self._show_render_lock -= 1

    def start_render_updater(self):
        self.kf.log("debug","Idle Q")
        self.skip_update = 2
        if self.render_updater is None:
            self.render_updater = glib.timeout_add(100, self.show_render)
        self._show_render_lock += 1
        self.kf.do_work(ApplyWork("update_display", done=self._dec_render_lock))

    def _minsize(self):
        img = self["TheImage"]
        img.set_size_request(100,100)

    async def run(self):
        self.done = trio.Event()
        self['main'].show_all()
        self.resize_viewport_to_fractal()
        self.start_render_updater()
        #self.kf.do_work(ApplyWork("Startup", done=self.draw_fractal))
        await self.done.wait()

