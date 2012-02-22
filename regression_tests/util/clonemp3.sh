#!/bin/sh

set -e

SRC=$1
DESTDIR=$2

mkdir -p "$DESTDIR"

DEST="$DESTDIR"/`basename "$SRC"`

datadir=`dirname "$0"`
if [ "$datadir" = "" ]; then
	datadir=`which "$0"`
	datadir=`dirname "$datadir"`
fi

if [ -f "$DEST" ]; then
	echo "'$DEST' already exists.  Quitting."
	exit 1
fi

cp "$datadir/simple.mp3" "$DEST"
chmod u+w "$DEST"
id3cp "$SRC" "$DEST"

