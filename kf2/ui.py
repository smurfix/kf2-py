import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GLib', '2.0')
from gi.repository import Gtk as gtk
from gi.repository import GObject as gobject
from gi.repository import GLib as glib

class UI:
    render_update = None

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

    def __getitem__(self,name):
        return self.widgets.get_object(name)

    def on_test(self, *x):
        print("TEST")

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

    def on_img_ptrmove(self, *x):
        print("MOVE",x)

    def on_fractal_draw(self, *x):
        print("DRAW",x)

    def on_quit_button_clicked(self,x):
        gtk.main_quit()

    def render_idle(self):
        if not self.kf.render_running:
            self.render_update = None
            return False
        return True

    def render(self):
        self.kf.stop()

        self.kf.render(True)
        if self.render_update is None:
            self.render_update = glib.timeout_add(60*1000, self.render_idle)

    def stop_render(self):
        self.kf.stop()

    def run(self):
        self['main'].show_all()

        gtk.main()

