#!/usr/bin/env python3
import os
import sys
os.environ["LD_LIBRARY_PATH"] = ".."

try:
	import kf2
except ImportError:
	sys.path[0:0] = (".",)
	import kf2

import click

@click.command(context_settings={"help_option_names":['-h','-H','-?','--help']})
@click.option("-o","--load-map",type=click.Path(exists=True, dir_okay=False), help="load map file (EXR or KFB)")
@click.option("-c","--load-palette",type=click.Path(exists=True, dir_okay=False), help="load palette file")
@click.option("-l","--load-location",type=click.Path(exists=True, dir_okay=False), help="load location file (KFR)")
@click.option("-s","--load-settings",type=click.Path(exists=True, dir_okay=False), help="load settings file (KFS)")
@click.option("-x","--save-exr",type=click.Path(dir_okay=False, readable=False,writable=True), help="save EXR")
@click.option("-t","--save-tif",type=click.Path(dir_okay=False, readable=False,writable=True), help="save TIFF")
@click.option("-p","--save-png",type=click.Path(dir_okay=False, readable=False,writable=True), help="save PNG")
@click.option("-j","--save-jpg",type=click.Path(dir_okay=False, readable=False,writable=True), help="save JPEG")
@click.option("-J","--jpg-quality",type=int,help="JPEG quality")
@click.option("-m","--save-map",type=click.Path(dir_okay=False, readable=False,writable=True), help="save KFB")
@click.option("--save-kfr",type=click.Path(dir_okay=False, readable=False,writable=True), help="save KFR")
@click.option("-z","--zoom-out",type=int,help="zoom sequence")
@click.option("-L","--log",type=str,help="logging verbosity")
@click.option("-v","-V","--version",is_flag=True,help="show version")
def main(load_map,load_palette,load_location,load_settings,save_exr,save_tif,save_png,save_jpg,jpg_quality,save_map,save_kfr,zoom_out,log,version):
	if version:
		print(kf2.__version__)
		sys.exit(0)

	kf = kf2.Fractal()

	batch = save_exr or save_tif or save_png or save_jpg or save_map or save_kfr
	if load_settings:
		kf.openSettings(load_settings)
	if load_location:
		kf.openFile(load_location)
	if load_map:
		try:
			kf.openMapB(load_map)
		except RuntimeError:
			try:
				kf.openMapEXR(load_map)
			except RuntimeError:
				print(f"{load_map :r}: File format not recognized", file=sys.stderr)
				sys.exit(1)
	if load_palette:
		kf.inhibit_colouring = True
		kf.openFile(load_palette)
		kf.inhibit_colouring = False
	only_kfr = bool(save_kfr) and not bool(save_exr or save_pg or save_map or save_png or save_tif)
	if batch:
		kf.setImageSize(*kf.target_dimensions[0:2])
		save_args = dict(save_exr=save_exr, save_tif=save_tif, save_jpg=save_jpg,
				save_png=save_png, save_map=save_map, save_kfr=save_kfr,
				quality=jpg_quality)
		from kf2.batch import render_frame,save_frame
		if load_map:
			save_frame(0, only_kfr, **save_args)
		else:
			if zoom_out:
				for frame in range(zoom_out):
					render_frame(kf, frame, only_kfr, **save_args)
					if kf.zoom < .001:
						break
			else:
				render_frame(kf, 0, only_kfr, **save_args)
	else:
		from kf2.ui import UI
		ui=UI(kf)
		ui.run()

if __name__ == "__main__":
	main()
