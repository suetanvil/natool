# Introduction

natool is a command-line synch manager for the Neuros II Digital Audio
Computer.


# Requirements

To run natool, you need:

1. A unix-ish workstation (e.g. a PC running Linux or *BSD).

2. A non-ancient version of Perl.  (I used 5.8.8, so you're unlikely
to find one that won't work.)

It *might* work under Cygwin but hasn't been tested.  natool assumes
that the workstation's filesystem is case-sensitive.  If this is not
the case, it could lead to audio files being duplicated or clobbered
in some rare circumstances.  natool also assumes Unix-style paths so
avoid using Windows-style paths under Cygwin.


# Running Without Installing

You can run natool from the source directory by typing

    bin/natool

This is safe if you just want to try it out.

Note, however, that you must invoke it with an explicit path.  Putting
the bin directory into your PATH will not work.  Neither will moving
natool to another directory.  This is because natool needs the leading
path to find its libraries.


# Installation

natool uses a non-standard installation scheme designed to make it as
self-contained as possible.  To install natool in /usr/local:

    sudo perl install.pl

from the top of the installation tarball.

(Actually, first take a look at install.pl to make sure it doesn't do
anything evil, *then* type the above command.  Because typing a
command AS ROOT because a stranger tells you to is bad security
practice.)

To install it elsewhere, use the "--prefix" option:

    perl install.pl --prefix ~/my_apps/

You must have permission to write to the destination directory for
this to work.


# Hacking Hints

The directory 'regression_tests contains a collection of regression
tests.  The script 'test.sh' runs those tests and also the unit tests
in 'Neuros/t'.

If you wish to extend natool, you will do well to read the detailed
description of the Neuros' database that is included with Positron,
another command-line Neuros sync tool.  This was invaluable to me
despite now being somewhat out of date.

If you read C, it may also be worthwhile to download the firmware
source code for the final reference on what is and is not allowed by
the Neuros.


# See also:

    natool.1.pod  -- the man page.
    Copyright.txt -- the copyright statement.
    LICENSE.GPL   -- the license under which natool is distributed.


