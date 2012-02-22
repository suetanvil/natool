
# This script is a simple regression test for basic natool operations
# that don't create the database.

set -e

export NATOOL_NEUROS_PATH="$1"

if [[ ! -d $NATOOL_NEUROS_PATH ]]; then
	echo "Invalid neuros path: '$NATOOL_NEUROS_PATH'"
	exit 1
fi


if [[ ! -x ../bin/natool ]]; then
	echo "Unable to find 'natool'."
	exit 1
fi

export PATH="../bin:$PATH"

REF=orig-ml
VERBOSE=
NAF="$NATOOL_NEUROS_PATH"

function run {
	echo "Running: '$*'"
	eval $*
}

function die {
	echo -n "Error: "
	echo $*
	exit 1
}

function check {
	while [ -n "$1" ]; do
		cmp "$NAF/$1" "$REF/$1" \
			|| die "File '$1' does not match reference."
		echo "$1 passed."
		shift
	done
}


# Force the creation of an empty playlist
run natool --no-check $VERBOSE lsartists
[ -f "$NAF/natooldat/audio.mls" ] || die "Did not create master list."


# Add the audio files
run natool --no-check $VERBOSE dirsync audio dest_audio
check natooldat/audio.mls
echo ===

# Various scan configurations
run natool --no-check $VERBOSE scan
check natooldat/audio.mls
echo ===

run natool --no-check $VERBOSE scan
check natooldat/audio.mls
echo ===

run natool --no-check $VERBOSE scan --full
check natooldat/audio.mls
echo ===

run rm "$NAF/natooldat/audio.mls"
run natool --no-check $VERBOSE scan
check natooldat/audio.mls
echo ===

# Basic playlist creation
[ -s "$NAF/natooldat/test1.npl" ] \
	&& die "Reference playlist already exists."

run natool --no-check $VERBOSE addpl test1 "$NAF"/dest_audio/misc/*.mp3
check natooldat/test1.npl
echo ===

run natool --no-check $VERBOSE rmpl test1
[ ! -f $NAF/natool/test1.npl ] \
	|| die "Failed to remove playlist."
echo ===


