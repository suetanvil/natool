# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

#
# This module contains routines for manipulating files in
# Neuros-specific ways.
#

package Neuros::FileUtil;

use Exporter 'import';
our @EXPORT = qw {IsAudioFile GetAudioExt UnixPathToNeuros RelToNeuros};

use strict;
use warnings;
use English;

use File::Basename;
use File::Spec::Functions qw{splitdir catdir};
use Cwd 'abs_path';

use Neuros::Asciify;

use constant NEUROS_MAX_PATH_LEN => 254;


# Test if $filename looks like the name of one of the supported file
# types (currently just mp3).
sub IsAudioFile {
  my ($filename) = @_;

  return !!GetAudioExt($filename);
}


# Return the extension of $filename, lowercased, if it is one of the
# supported file types. Otherwise, return false.
sub GetAudioExt {
  my ($filename) = @_;

  $filename =~ m/\.(mp3|ogg)$/i
    or return;

  return lc($1);
}





# Given relative Unix path $path, return the equivalent path on the
# Neuros filesystem.  The resulting path has all non-ASCII characters
# replaced with ASCII.  This function should be the ONLY routine that
# performs this transformation.
#
# Note: assumes that all of $path is on the Neuros filesystem.  If you
# pass it any part of the path before the mountpoint, it will "clean
# up" this path as well.  This is probably not what you want.
sub UnixPathToNeuros {
  my ($path) = @_;

  # Launder $path
  $path = toAsciiFilename ($path);

  # vfat gets unhappy when things end with periods. Causes duplicated
  # file names, at least under Linux.  rsync just removes these
  # trailing chars, so we'll do that too
  $path =~ s/ \.+ \z//gmx;

  # Truncate each path part to no more than NEUROS_MAX_PATH_LEN
  # characters
  $path = catdir(map { substr($_, 0, NEUROS_MAX_PATH_LEN) } splitdir ($path));

  return $path;
}


# Given a path to a directory and the absolute path to the Neuros,
# return the same path relative to the Neuros mountpoint.  $path must
# be an EXISTING file or directory on the Neuros.
sub RelToNeuros {
  my ($path, $neurosPath) = @_;

  # Make sure the file exists.  (We do this because abs_path() doesn't
  # always work if some part of the path isn't there).
  return
    unless -e $path;

  $path = abs_path($path)
    or return;

  my @pathParts = splitdir($path);
  my @npathParts = splitdir($neurosPath);

  my $filePart = pop @pathParts
    if -f $neurosPath;

  while (scalar @pathParts && scalar @npathParts
         && $pathParts[0] eq $npathParts[0]) {
    shift @pathParts;
    shift @npathParts;
  }

  # If there's still someof @npathParts left, it means that $path
  # isn't on the Neuros.
  return
    if scalar @npathParts;

  # Put back the filename
  push @pathParts, $filePart
    if $filePart;

  return catdir(@pathParts);
}


# Teh ENB
1;
