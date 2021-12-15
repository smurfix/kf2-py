#!/bin/sh

S="$1"; shift
P="$1"; shift
for f ; do
    test -f "$P$f" || ln -sf "$S$f" "$P$f"
done
