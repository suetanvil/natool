# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module provides various simple commands generally consisting of
# one or two functions' worth of code.


package Neuros::SimpleCmd;

use strict;
use warnings;

use File::Basename;
use File::Path;
use File::Copy;
use Cwd 'abs_path';

use Neuros::FileUtil;
use Neuros::AudioInfo;
use Neuros::NdbWriter;
use Neuros::State;
use Neuros::Util;
use Neuros::Asciify;

# Convert a local path to the Neuros path.
sub ConvertPath {
  my ($flags, @paths) = @_;

  my $lpath;
  while ($lpath = shift @paths) {
    $lpath = basename($lpath)
      if $flags->{'basename'};

    print UnixPathToNeuros($lpath);

    if (scalar @paths > 0) {
      print $flags->{'no-newline'} ? " " : "\n";
    } else {
      print "\n"
        unless $flags->{'no-newline'};
    }
  }

  return;
}


# Write out the AudioInfo (i.e. the master list) as a Neuros database.
sub WriteNeurosDb {
  my ($flags, @args) = @_;

  die "Unknown arguments: '@args'\n"
    if scalar @args;

  my $neurosDir = GetNeurosPath();

  # Get a copy of the AudioInfo object
  my $audio = GetAudio();

  # Write out the Neuros database.
  vsay "Creating WOID_DB database:";
  my $dbw = Neuros::NdbWriter->new({audio       => $audio,
                                    neurosDir   => $neurosDir});
  $dbw->createNAM();

  return;
}



# Command to copy a file onto the Neuros.
sub InstallFile {
  my ($flags, @args) = @_;

  die "Not enough arguments.\n"
    unless scalar @args >= 2;

  # Get the Neuros path.  We use it later.
  my $neurosPath = GetNeurosPath();

  # Get the destination directory.
  my $destDir = pop @args;
  die "Invalid destination directory: '$destDir'\n"
    unless -d $destDir;

  my $relDestDir = RelToNeuros($destDir, $neurosPath);
  die "Destination directory '$destDir' is not on the Neuros.\n"
    unless $relDestDir;

  # Ensure the source files exist and are valid.
  for my $file (@args) {
    die "File '$file' does not exist.\n"
      unless -f $file;

    die "File '$file' is not a supported audio file.\n"
      unless IsAudioFile($file);
  }

  # Copy the files.
  for my $srcFile (@args) {
    my $baseFile = basename($srcFile);
    my $destPath = "$neurosPath/$relDestDir/" . UnixPathToNeuros($baseFile);

    # Add the metadata first.
    if (!$flags->{'no-update'}) {
      AddFileToAudio($neurosPath, "$relDestDir/$baseFile", $srcFile)
        or do {
          wsay "'$srcFile' is not a valid audio file.  Skipping.";
          next;
        };
    }

    copy ($srcFile, $destPath)
      or die "Error copying '$srcFile' to '$destPath': $!\n";
  }

  return;
}

# Remove the named file(s) from the master list.  Also delete them if
# --delete is given.
sub RemoveFile {
  my ($flags, @args) = @_;

  my $audio = GetAudio();
  my $neurosPath = GetNeurosPath();

  for my $file (@args) {

    # The file needs to be present for RelToNeuros to work.
    if (! -e $file) {
      wsay "File '$file' not present on Neuros.  Skipping.";
      next;
    }

    my $relPath = RelToNeuros ($file, $neurosPath);

    $audio->deleteTrack ("C:/$relPath")
      or wsay "No entry for '$relPath' in master list.";

    if (! $flags->{'keep'}) {
      unlink ($file)
        or wsay "Unable to delete '$file' from Neuros.";
    }
  }

  return;
}



# Print out the named artists (defaulting to all if no args are given)
# and their albums and possibly songs if --albums, --files or --titles
# are given.
sub ListTracks {
  my ($flags, @artists) = @_;

  my $audio = GetAudio();

  # --tracks implies --albums
  $flags->{'albums'} ||= ($flags->{'files'} || $flags->{'titles'});

  # Default to all artists unless one or more is given.
  @artists = @{ $audio->valuesSorted('artist') }
    unless scalar @artists;

  # Get the Big Hash o' Details but only if we need it.
  my $infoHash = $audio->getArtistAlbumTrackHash()
    if $flags->{'albums'};

  # Print out the information
  for my $artist (@artists) {
    print "$artist\n";

    # Print albums if requested.
    next unless $flags->{'albums'};
    for my $album (sort keys %{$infoHash->{$artist}}) {
      print "    $album\n";

      # Print tracks or titles if requested.
      next unless $flags->{'files'} || $flags->{'titles'};

      for my $file ( @{$infoHash->{$artist}->{$album}} ) {
        print "        ";
        if ($flags->{'titles'}) {
          print $audio->getTrack($file)->{title};
        } else {
          $file =~ s{^C:/}{};
          print $file;
        }
        print "\n";
      }
    }
  }

  return;
}


# Implement the "drop" command (which discards the current audio
# object).
sub DropCmd {
  my ($flags, @args) = @_;

  die "Unknown arguments given to 'drop'.\n"
    if scalar @args > 0;

  DiscardAudio();

  return;
}


# Implement the 'save' command (which immediately writes out the
# current audio object (if present)).
sub SaveCmd {
  my ($flags, @args) = @_;

  die "Unknown arguments given to 'save'.\n"
    if scalar @args > 0;

  WriteAudio();

  return;
}


# Perform various misc. in-place transformations on the AudioInfo
# object.  The actual heavy lifting is done by AudioInfo.
sub FixCmd {
  my ($flags, @args) = @_;

  die "Unexpected arguments to 'fix'.\n"
    if scalar @args;

  my $audio = GetAudio();

  if ($flags->{'dumb-artist-sort'}) {
    $audio->setArtistSort('dumb');
  }

  if ($flags->{'smart-artist-sort'}) {
    $audio->setArtistSort('smart');
  }

  if (defined($flags->{'count-sort'})) {
    $flags->{'count-sort'} ||= 5;   # Set to a default if no value given

    die "Threshold for '--count-sort' must be greater than 1.\n"
      unless $flags->{'count-sort'} > 1;

    $audio->setSortMinCount($flags->{'count-sort'});
  }

  $flags->{'album-artist'} ||= $flags->{'album-artist-dir'};
  if ($flags->{'album-artist'}) {
    $audio->makeAlbumsUnique($flags->{'album-artist-dir'});
  }

  return;
}



1;

