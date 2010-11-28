#!/bin/bash

export RELEASE_TESTING=1

make clean

perl Makefile.PL || exit 1

make manifest || exit 2
rm MANIFEST.bak

make || exit 3

make test || exit 4

