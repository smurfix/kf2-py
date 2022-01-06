#
# KF2 batch methods

from PIL import Image

def save_frame(kf, frame:int, only_kfr:bool, quality:int = 100,
        save_exr=None, save_tif=None, save_png=None, save_jpg=None, save_kfr=None, save_map=None):

    def fixname(fn):
        if '%' in fn:
            fn = fn % (frame,)
        return fn
    x,y,s = kf.target_dimensions
    img = kf.pilImage.resize((x,y), Image.LANCZOS)
    if not only_kfr:
        kf.log("info","colouring final image")
        kf.inhibit_colouring = False
        kf.applyColors()
    if save_exr:
        kf.log("info", f"saving EXR {save_exr !r}")
        kf.saveEXR(fixname(save_exr))
    if save_tif:
        kf.log("info", f"saving TIFF {save_tif !r}")
        img.save(fixname(save_tif),format="tiff",compression="tiff_lzw")
    if save_png:
        kf.log("info", f"saving PNG {save_png !r}")
        img.save(fixname(save_png),format="png")
    if save_jpg:
        kf.log("info", f"saving JPG {save_jpg !r}")
        img.save(fixname(save_jpg),format="jpeg",quality=quality,optimize=True)
    if save_kfr:
        kf.log("info", f"saving KFR {save_kfr !r}")
        kf.saveKFR(fixname(save_kfr))
    if save_map:
        kf.log("info", f"saving KFB {save_map !r}")
        kf.saveKFR(fixname(save_map))

def render_frame(kf, frame:int, only_kfr:bool, **save_args):
    kf.inhibit_colouring = True
    kf.interactive = False
    if not only_kfr:
        kf.log("info", "reference 1")
    if frame > 0:
        if kf.jitter_seed:
            kf.jitter_seed += 1
        if not only_kfr:
            kf.fixIterLimit()
        kf.setPosition(kf.center_re, kf.center_im, kf. kf.radius * kf.zoom_size)

    if not only_kfr:
        kf.render(False,True)
        for r in range(2, kf.max_references):
            kf.auto_glitch = r
            n = kf.findCenterOfGlitch()
            if n:
                n,x,y = n
                print(f"reference {r} at ({x},{y}) size {n-1}", file=sys.stderr)
                kf.addReference(x,y)
            else:
                kf.log("info", "no more glitches")
                break
    save_frame(kf, frame, only_kfr, **save_args)


