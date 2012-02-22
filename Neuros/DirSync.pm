# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module implements the dirsync subcommand.  This synchronizes
# the contents of a local directory and a matching directory on the
# Neuros.

package Neuros::DirSync;

use strict;
use warnings;

use Getopt::Long;
use File::Copy;
use File::Basename;
use File::Path;
use File::Spec;
use Cwd 'abs_path';

use Neuros::FileSet;
use Neuros::State;
use Neuros::Util;


# Flags.  (These get copied from the flags ref. filled by GetOptions()
# in CommandLine.  Really, we should just be passing the hash around
# as an argument but this code predates that design decision.)
my $fake    = 0;    # If set, do nothing--just print out commands
my $cleanup = 0;    # If set, delete orphaned files
my $adopt   = 0;    # If set, copy orphaned files to the PC
my $noUpdate= 0;    # If set, do not update the master list

# Copy the flags in $flagsRef to the (module)global flag variables.
sub setFlags {
  my ($flagsRef) = @_;

  $fake     = $flagsRef->{'fake'};
  $cleanup  = $flagsRef->{'cleanup'};
  $adopt    = $flagsRef->{'adopt'};
  $noUpdate = $fake || $flagsRef->{'no-update'};

  return;
}


# Copy the file at $_->[0] to $_->[1], making intermediate directories
# if necessary.
sub installFile {
  my ($src, $dest) = @{shift()};

  vsay "$src -> $dest";

  # First, ensure that the destination directory exists
  my $destDir = dirname($dest);
  if (! -d $destDir) {
    mkpath ($destDir)
      or die "Unable to create destination directory '$destDir'\n";
  }

  # Now, copy $src to $dest
  copy ($src, $dest)
    or die "Unable to copy '$src' to '$dest'\n";

  return;
}



# Copy the selected audio files to the Neuros
sub handleInstalls {
  my ($list, $comment) = @_;

  print "# $comment\n"
    if $fake;

  my $instFunc = $fake ? sub {print "cp \"$_->[0]\" \"$_->[1]\"\n"} :
    \&installFile;

  map { $instFunc->($_) } @{$list};

  return;
}


# Delete all files in @{$orphans}
sub handleCleanup {
  my ($orphans) = @_;

  print "\n\n#Deleting orphaned files from the Neuros\n"
    if $fake;

  my $dlFunc = $fake ?
    sub {print "rm \"$_\"\n"} :
    sub {
      print "Deleting $_\n";
      unlink $_
        or print "Unable to delete $_\n";
    };

  map { $dlFunc->() } @{$orphans};

  return;
}


# Copy files in $orphans from the Neuros to the PC
sub handleAdoptions {
  my ($fs, $orphans) = @_;

  my $pcRoot        = $fs->get_pcRoot();
  my $neurosRoot    = $fs->get_neurosRoot();

  my @orphanPairs = ();
  for my $src (@{$orphans}) {
    my $dest = $src;
    $dest =~ s/$neurosRoot/$pcRoot/e
      or die "Internal error: Failed to determine destination filename.\n";

    push @orphanPairs, [$src, $dest];
  }

  handleInstalls (\@orphanPairs, "Copying orphaned files to the PC side");

  return;
}


# Add entries to the current AudioInfo for all of the files in
# $listRef, then strip out all entries in @{$listRef} determined to be
# invalid by GetTags().
#
# $listRef is an array of pairs of filenames, one on the PC and the
# other on the Neuros.  The PC list is the one read for speed although
# it is assumed that the Neuros one exists and is identical.
sub updateMasterList {
  my ($listRef) = @_;

  my $neurosPrefix = GetNeurosPath();

  for my $filesRef (@{$listRef}) {
    my ($pcPath, $neurosPath) = @{$filesRef};

    my $relPath = $neurosPath;
    $relPath =~ s/^$neurosPrefix//;

    AddFileToAudio ($neurosPrefix, $relPath, $pcPath)
      or do {
        wsay "File '$pcPath' is not a valid audio file.  Skipping.";
        $filesRef = '';
      };
  }

  # Strip out invalid entries.
  @{$listRef} = grep { $_ } @{$listRef};

  return;
}



# Remove all files in $deletionListRef.
sub removeAllFiles {
  my ($deletionListRef) = @_;

  my $neurosPath = GetNeurosPath();
  my $audio = GetAudio();

  for my $file (@{$deletionListRef}) {
    my $key = $file;
    $key =~ s/^$neurosPath//;
    $key = "C:/$key";

    $audio->deleteTrack($key);
  }

  return;
}


# Convert $path to an absolute path with the worst wierdnesses
# removed.
sub cleanPath {
  my ($path) = @_;

  # Convert to absolute path.  This should always work, 'cuz the
  # caller's ensured that the paths exist.
  my $absPath = abs_path($path)
    or die "Unable to determine absolute path for '$path'.\n";

  return File::Spec->canonpath($absPath);
}


sub Go {
  my ($flagsRef, @paths) = @_;

  # Set the flag variables above.
  setFlags ($flagsRef);

  # Get the source directory.  Must be a real path.
  my $pcRoot = shift @paths;
  die "Invalid source directory.\n"
    unless ($pcRoot && -d $pcRoot);
  $pcRoot = cleanPath($pcRoot);

  # Get the dest. directory.  Must be relative to Neuros mount point.
  my $nRoot = shift @paths
    or die "You must specify a destination directory.\n";
  $nRoot = GetNeurosPath() . "/$nRoot";
  if (! -d $nRoot) {
    mkpath ($nRoot, 0, 0777)
      or die "Unable to create destination directory '$nRoot'.\n";
  }
  $nRoot = cleanPath($nRoot);

  # Make sure there are no more superfluous arguments
  die "Found trailing argument '$paths[0]'\n"
    if scalar @paths;

  # Create the file set
  my $fs = Neuros::FileSet->new({neurosRoot     => $nRoot,
                                 pcRoot         => $pcRoot});

  $fs->fillFromDisk(1);

  # First, fetch the file lists.  We get them both now so that we can
  # warn the user if the counts look suspicious
  my $install = $fs->installList();
  my $orphans = ($cleanup || $adopt) ? $fs->orphanedList() : [];

  # And do the sanity checks.  These only issue warnings so that the
  # user can hit CTRL+C in time.
  print "WARNING: installing @{[scalar @{$install}]} files.\n"
    if !$fake && scalar @{$install} > 200;

  print "WARNING: found @{[scalar @{$orphans}]} orphaned files.\n"
    if !$fake && scalar @{$orphans} > 200;

  # Add files to the master list, removing any that are not valid
  # audio files.
  updateMasterList ($install)
    unless $noUpdate;

  # Copy files to the Neuros
  handleInstalls ($install, "Installing files onto the Neuros")
    unless scalar @{$install} <= 0;

  # Copy orphaned files back to the PC
  handleAdoptions ($fs, $orphans)
    if $adopt;

  # Delete orphaned files
  handleCleanup ($orphans)
    if $cleanup;

  # Delete orphans from the master list
  removeAllFiles ($orphans)
    if (!$noUpdate && $cleanup);

  return;
}




1;
