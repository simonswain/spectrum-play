#!/bin/bash
../z80asm-1.8/z80asm $1.asm
../util/bin2tap a.bin $1.tap
fuse --auto-load --tape $1.tap