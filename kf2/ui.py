import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GLib', '2.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk as gtk
from gi.repository import Gdk as gdk
from gi.repository import GObject as gobject
from gi.repository import GLib as glib

import cairo

from PIL import Image

class UI:
    render_update = None
    skip_update = 2
    draw_blocked = False

    def __init__(self, kf):
        self.kf = kf
        self.widgets = gtk.Builder()
        self.widgets.add_from_file("kf2/ui.glade")

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
        print("RUN",x)

    def on_main_destroy(self,window):
        # main window goes away
        gtk.main_quit()

    def on_main_delete(self,window,event):
        # True if the window should not be deleted
        return False

    def on_img_scroll(self, *x):
        print("SCROLL",x)

    def on_img_ptrmove(self, area, evt):
        # print("MOVE",evt.x,evt.y)
        pass

    def on_fractal_draw(self, area, ctx):
        # print("DRAW")
        if self.skip_update:
            return True
        img = cairo.ImageSurface.create_for_data(self.kf.image_bytes, cairo.FORMAT_RGB24, self.kf.image_width, self.kf.image_height)
        ctx.set_source_surface(img, 0, 0)
        ctx.paint()

    def on_quit_button_clicked(self,x):
        gtk.main_quit()

    def draw_fractal(self):
        img = self["TheImage"]
        if self.draw_blocked:
            self.draw_blocked = False
            gobject.signal_handler_unblock(img, self.draw_handler_id)
        self["TheImage"].queue_draw_area(0,0,self.kf.image_width, self.kf.image_height)


    def on_imgsize_changed(self,*x):
        self.update_image_size()

    def update_image_size(self):
        """update image size from on-screen window"""
        # XXX test code, ideally should not do this
        img = self["TheImage"]
        if not self.draw_blocked:
            self.draw_blocked = True
            gobject.signal_handler_block(img, self.draw_handler_id)

        r = img.get_allocation()
        self.kf.setImageSize(r.width,r.height)
        self.render()

    def render_idle(self):
        if not self.kf.render_running:
            self.render_update = None
            return False

        if not self.kf.render_done:
            if self.skip_update:
                self.skip_update -= 1
            else:
                self.draw_fractal()
            return True
        self.skip_update = 0
        self.kf.render_join()
        self.render_update = None
        self.draw_fractal()
        return False

    def render(self):
        self.kf.stop()

        self.skip_update = 2
        self.kf.render(True)
        if self.render_update is None:
            self.render_update = glib.timeout_add(100, self.render_idle)

    def stop_render(self):
        self.kf.stop()

    def run(self):
        self['main'].show_all()
        self.update_image_size()

        gtk.main()

