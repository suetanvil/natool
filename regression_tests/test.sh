#!/bin/sh

#
# Run all tests.  Does some here and calls some externally.  (This is
# less elegant than it could be, I know.)
#

set -e

RUN=run.$$

cd `dirname $0`

mkdir $RUN
cd $RUN

SRCDIR=$1
if [ -z "$SRCDIR" ]; then
	SRCDIR=../orig
fi

echo "Creating database..."
time ../../bin/natool --alt-ml-dir "$SRCDIR/natooldat/" \
	--args ../test-sh-args.txt							\
	fix --dumb-artist-sort								\
	dbsync

failed=
echo "Comparing database files..."
for f in natooldat/* WOID_DB/*/*; do
	echo -n "$f "
	if cmp $f "$SRCDIR/$f"; then
		true
	else
		failed=1
	fi
done
echo
echo

if [ -z "$failed" ]; then
	echo "Doing 'fix' command tests:"
	cp natooldat/audio.mls natooldat/audio.mls.orig

	for t in ../fixtest/test-*; do
		echo "Testing '$t'"
		../../bin/natool --alt-ml-dir $t \
			--neuros-path "." \
			--no-check \
			--args $t/cmd.txt
		if cmp natooldat/audio.mls $t/audio.mls.result; then
			true
		else
			echo "Test $t failed."
			failed=1
			break
		fi
	done	
fi

echo
echo
echo


#
# Do the basic smoketest
#
if [ -z "$failed" ]; then

	mv natooldat natooldat-dbtest
	cd ..

	echo
	echo "Running basic smoketest."

	if sh smoketest.sh $RUN; then
		echo "Regression tests passed."
	else
		failed=1
	fi
fi


if [ -z "$failed" ]; then
	echo "All passed.  Cleaning up."
	rm -rf $RUN
else
	echo "Error found.  Leaving $RUN in place."
	exit 1
fi




#
# Do Perl unit tests
#
cd ../Neuros/
echo
echo
for i in t/*.t; do
	echo "Running 'perl $i'..."
	perl -I.. $i
	echo
done


