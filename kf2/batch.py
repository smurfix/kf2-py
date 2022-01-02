#
# KF2 batch methods

from kf.core import UNEVALUATED

def save_frame(kf, frame:int, only_kfr:bool, quality:int = 100,
        save_exr=None, save_tif=None, save_png=None, save_jpg=None, save=kfr=None):

    def fixname(fn):
        if '%' in fn:
            fn = fn % (frame,)
        return fn

    if not only_kfr:
        kf.inhibitColouring = False
        kf.applyColors()
    if save_exr:
        kf.saveEXR(fixname(save_exr))
    if save_tif:
        kf.saveTIFF(fixname(save_tif))
    if save_png:
        kf.savePNG(fixname(save_png))
    if save_jpg:
        kf.saveJPG(fixname(save_jpg), quality)
    if save_kfr:
        kf.saveKFR(fixname(save_kfr))
    if save_map:
        kf.saveKFR(fixname(save_map))

def render_frame(kf, frame:int, only_kfr:bool, **save_args):
    kf.inhibitColouring = True
    kf.interactive = False
    if frame >= 0:
        if kf.jitter_seed:
            kf.jitter_seed += 1
        if not only_kfr:
            kf.fixIterLimit()
        kf.setPosition(kf.center_re, kf.center_im, kf. kf.radius * kf.zoom_size)
    if not only_kfr:
        kf.render(False,True)
    save_frame(kf, frame, only_kfr, **save_args)


