# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module holds various global objects and provides them on
# demand, creating them lazily as needed.  Specifically, it holds the
# master list as a Neuros::AudioInfo and the path to the Neuros'
# mountpoint.

package Neuros::State;

use Exporter 'import';
our @EXPORT = qw{SetToplevelArgs GetNeurosPath GetAudio WriteAudio
                 AddFileToAudio NewAudio DiscardAudio};

use strict;
use warnings;

use File::Path;
use Cwd 'abs_path';

use constant NA_MLDIR => 'natooldat';

use Neuros::CommandLine;
use Neuros::FileUtil;
use Neuros::Util;
use Neuros::AudioInfo;
use Neuros::MetaData;



my $neurosArgs;     # Global reference to the toplevel argument hash


# Store $args in $neurosArgs for when computeNeurosPath gets called.
# Can only be called once.
sub SetToplevelArgs {
  my ($args) = @_;

  die "Internal error: Toplevel args already initialized.\n"
    if $neurosArgs;

  $neurosArgs = $args;

  return;
}


# Neuros file path handling
{
  my $neurosPath;           # Path to the Neuros

  # Return the path to the Neuros as stored in $neurosPath.  The first
  # time this is called, $neurosPath is undefined and we call
  # computeNeurosPath() first to set it.  We do this because some
  # commands (e.g. 'convert') don't need the Neuros directory and I'd
  # like natool to work without it for those.
  sub GetNeurosPath {
    computeNeurosPath()
      unless defined ($neurosPath);

    return $neurosPath;
  }

  # Attempt to determine the path to the Neuros from the environment
  # or $neurosArgs.  This gets called by GetNeurosPath to initialize
  # $neurosPath the first time the value is needed.
  sub computeNeurosPath {
    $neurosPath = $neurosArgs->{'neuros-path'} || $ENV{NATOOL_NEUROS_PATH}||'';

    die "No path to Neuros device given.\n"
      unless $neurosPath;

    die "Neuros path '$neurosPath' does not exist.\n"
      unless -d $neurosPath;

    $neurosPath = abs_path ($neurosPath);
    $neurosPath =~ s{/*$}{};

    return if $neurosArgs->{'no-check'};

    for my $file (qw{sn.txt version.txt WOID_DB WOID_RECORD WOID_SYNC}) {
      -e "$neurosPath/$file"
        or die "Path '$neurosPath' doesn't look like a Neuros: missing '$file'\n";
    }

    return;
  }
}



# Return the default AudioInfo object, creating it if necessary.  It
# *must* be possible to find the Neuros path for this to work.
{
  my $audio;

  sub GetAudio {
    createAudio() unless $audio;

    return $audio;
  }

  # Create the audio object and load the master list if present.  Also
  # create the data dir if not present.
  sub createAudio {
    NewAudio();

    # Figure out the master list path
    my $mlPath = $neurosArgs->{'alt-ml-dir'};
    $mlPath ||= GetNeurosPath() . '/' . NA_MLDIR;
    $mlPath =~ s{/$}{};

    # Special case if the user gives a file instead of a dir. for
    # alt-ml-dir.
    die "Neuros metadata path '$mlPath' is a file. Expecting directory.\n"
      if (-f $mlPath);

    # Create the master list directory if it's not present.
    # (readDbFrom assumes it'll be there, so this is simpler).
    if (!-d $mlPath) {
      vsay "Creating $mlPath";
      mkdir $mlPath
        or die "Unable to create '$mlPath' on Neuros.\n";
    }

    $audio->readDbFrom($mlPath);

    return;
  }


  # Save $audio if it was loaded.
  sub WriteAudio {
    return unless $audio;

    my $destDir = GetNeurosPath() . '/' . NA_MLDIR;

    -d $destDir or
      mkpath ($destDir, 0, 0777) or
        die "Unable to create '$destDir'.\n";

    $audio->writeMlTo($destDir);

    return;
  }

  # Add the given file to the master list, creating the ML if
  # necessary.  The arguments are the same as those for GetTags:
  # $mountPoint is the path to the Neuros, $relPath is the location
  # below $mountPoint and $localPath is optional and points to a
  # (possibly different copy of) the file itself.
  sub AddFileToAudio {
    my ($mountPoint, $relPath, $localPath) = @_;

    my $a = GetAudio();
    my @track = GetTags($mountPoint, $relPath, $localPath);

    if (! scalar @track) {
      return;
    }

    vsay "Adding metadata for '$track[0]'";
    $a->addTrack(@track);

    return 1;
  }


  # Create a new AudioInfo object and store it.  This discards the
  # existing Audio object if present.
  sub NewAudio {
    $audio = Neuros::AudioInfo->new();
    return $audio;
  }

  # Throw away the current audio object (if present).
  sub DiscardAudio {
    $audio = undef;

    return;
  }
}




1;
