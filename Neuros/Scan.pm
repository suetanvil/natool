# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module implements the 'scan' command, which constructs a new
# master list by searching the Neuros for audio files.  Playlists are
# preserved.


package Neuros::Scan;

use Exporter 'import';
our @EXPORT = qw{ScanForFiles};

use strict;
use warnings;

use File::Find;
use File::Basename;

use Neuros::State;
use Neuros::FileUtil;
use Neuros::Util;





# Scan the Neuros for audio files and add them to the current
# AudioInfo object.  If --full was given, clears the AudioObject
# first.
sub ScanForFiles {
  my ($flags, @args) = @_;
  _scanAudio($flags);
  _loadPlaylists();

  return;
}


# Scan the Neuros for audio files and add them to the current
# AudioInfo.
sub _scanAudio {
  my ($flags) = @_;

  my $neurosPath = GetNeurosPath();
  my $full = $flags->{full};
  my $verbose = isVerbose();

  # If --full, create a new, empty AudioInfo for GetAudio() to return.
  if ($full) {
    vsay "Discarding any existing master list.";
    NewAudio();
  }
  my $audio = GetAudio();

  # The 'wanted' function and associated state
  my $knownPaths = _getKnownPaths($audio, $neurosPath);
  my %seenFiles = ();
  my $wanted = sub {
    -d && vsay "Scanning '$File::Find::name";

    return unless (-f && IsAudioFile($_));

    my $relPath = RelToNeuros($File::Find::name, $neurosPath);

    $seenFiles{"C:/$relPath"} = 1;

    return if exists($knownPaths->{$File::Find::name});

    AddFileToAudio($neurosPath, $relPath, $File::Find::name);
  };

  # Do the scan
  vsay "Scanning for audio files in '$neurosPath'";
  find ($wanted, $neurosPath);

  # Prune entries if needed
  $audio->deleteTracksNotIn(\%seenFiles)
    unless $full;

  return;
}


sub _getKnownPaths {
  my ($audio, $neurosPath) = @_;

  my %seenIt =
    map { s{^C:}{$neurosPath}e; $_ => 1 } @{ $audio->keysUnsorted() };

  return \%seenIt;
}


sub _loadPlaylists {
  my $mldir = GetNeurosPath() . '/' . Neuros::State::NA_MLDIR;
  GetAudio()->readPlaylists($mldir, 1);

  return;
}


1;
