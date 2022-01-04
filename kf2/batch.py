#
# KF2 batch methods

def save_frame(kf, frame:int, only_kfr:bool, quality:int = 100,
        save_exr=None, save_tif=None, save_png=None, save_jpg=None, save_kfr=None, save_map=None):

    def fixname(fn):
        if '%' in fn:
            fn = fn % (frame,)
        return fn

    if not only_kfr:
        kf.inhibit_colouring = False
        kf.applyColors()
    if save_exr:
        kf.saveEXR(fixname(save_exr))
    if save_tif:
        kf.pilImage.save(fixname(save_tif),format="tiff",compression="tiff_lzw")
    if save_png:
        kf.pilImage.save(fixname(save_png),format="png")
    if save_jpg:
        kf.pilImage.save(fixname(save_jpg),format="jpeg",quality=quality,optimize=True)
    if save_kfr:
        kf.saveKFR(fixname(save_kfr))
    if save_map:
        kf.saveKFR(fixname(save_map))

def render_frame(kf, frame:int, only_kfr:bool, **save_args):
    kf.inhibit_colouring = True
    kf.interactive = False
    if frame > 0:
        if kf.jitter_seed:
            kf.jitter_seed += 1
        if not only_kfr:
            kf.fixIterLimit()
        kf.setPosition(kf.center_re, kf.center_im, kf. kf.radius * kf.zoom_size)
    if not only_kfr:
        kf.render(False,True)
    save_frame(kf, frame, only_kfr, **save_args)


