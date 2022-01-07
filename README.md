# Introduction

Kalles Fraktaler, meet Python.
Python, meet Kalles Fraktaler.

You're very welcome.

Warning: this is the development branch of a work in progress. Things may
look funky, break, crash, and/or eat your CPU for breakfast. Don't YET use
this in production. We'll get there.

# Building

Get, build and install the embedded library:

    git clone https://github.com/smurfix/kf2
    cd kf2
    sudo apt install $(igrep -v '#' REQUIREMENTS)
    make OPENCL=0 embed -j$(nproc)

    sudo ln -s $(pwd)/libkf2-embed.so /usr/local/lib/
    sudo ldconfig
    cd ..

    git clone https://github.com/smurfix/kf2-py.git
    cd kf2-py
    sudo apt install $(igrep -v '#' REQUIREMENTS)
    make

You can build the regular KF2 `.exe` along with the embedded library. Just
run "make clean" in between. KF2's Makefile is hand-written and doesn't
support separate object directories; sorry about that.

## OpenCL?

You need this for building with OpenCL (which is otherwise untested):

    sudo apt install git build-essential devscripts
    git clone https://github.com/smurfix/clew.git
    cd clew
    debuild -b -us -uc
    cd ..
    sudo dpkg -i libclew-dev_*.deb

# Running

    cd kf2-py  # if you're not there anyway

    ./KF

All options of the Windows KF2 are accepted. They even might do
something sensible.

# Status

I want to establish feature parity with the Windows binary – with a nice
GTK front-end, and programmability in Python.

We're not there yet.

Help with re-implementing all those dialogs, menus and whatnots is gladly
accepted. Please co-ordinate via https://github.com/smurfix/kf2-py/discussions
as we don't want three people to work on Newton-Raphson zooming while
nobody thinks about the Color dialog.

## What's working

- basic batch mode
- loading of settings and parameters
- generating and saving images and EXR files
- basic zooming (no animation, no preview)
- window resizing

## TODOs

- autoload/save default settings
- fix window title
- display info below the image
- implement target and viewport scaling
- change window-resize modes between resizing the original and keeping the viewport
- write the magic lines that the benchmarks script wants
- implement panning
- implement instant zoom preview
- implement animated zoom
- when zooming in, start calculating at half block size
  instead of going back to all-blocky
- when zooming out, scale the old data matrices instead of recalculating
  (doesn't work for zooming in because of jitter)
- implement all those menus
- implement load+save from the UI
- implement all those dialogs
- implement all those options
- test OpenCL
- test OpenGL
- implement Mapping-based storage for settings and params

# Future Work

Fix panning: copy data instead of recalculating the world.

Write an efficient framework for movies that do more than zoom in or out.

Think about an async batch workflow (anyio).

The ability to write the Fractal equation in Python (gmpy2 and/or numpy) would be a very nice addition.

