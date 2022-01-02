# Introduction

Kalles Fraktaler, meet Python.
Python, meet Kalles Fraktaler.

You're very welcome.

Warning: this is the development branch of a work in progress. Things may
look funky, break, crash, and/or eat your CPU for breakfast. Don't YET use
this in production. We'll get there.

# Building

Prerequisites:

    sudo apt install git build-essential devscripts
    git clone https://github.com/smurfix/clew.git
    cd clew
    debuild -b -us -uc
    cd ..
    sudo dpkg -i libclew-dev_*.deb

    git clone https://github.com/smurfix/kf2
    cd kf2
    sudo apt install $(igrep -v '#' REQUIREMENTS)
    make embed -j9

    git clone https://github.com/smurfix/kf2-py.git python
    cd python
    sudo apt install $(igrep -v '#' REQUIREMENTS)
    make

You can build the regular KF2 `.exe` along with the embedded library. Just
run "make clean" in between. KF2's Makefile is hand-written and doesn't
support separate object directories; sorry about that.

# Running

    cd kf2/python # if you're not there anyway

    LD_LIBRARY_PATH=.. PYTHONPATH=. scripts/kf2

All options of the Windows KF2 are accepted. They probably won't do
anything sensible yet, but that's a different problem. :-P

# Status

I want to establish feature parity with the Windows binary – with a nice
GTK front-end, and programmability in Python.

We're not there yet.

Help with re-implementing all those dialogs, menus and whatnots is gladly
accepted. Please co-ordinate via https://github.com/smurfix/kf2-py/discussions .

# Future Work

The ability to write the Fractal equation in Python/gmpy2 would be a very nice addition.

