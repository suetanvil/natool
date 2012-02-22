# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module implements the 'addpl', 'rmpl' and 'lspl' commands for
# playlist manipulation.

package Neuros::PlaylistCmd;

use Exporter 'import';
our @EXPORT = qw{};

use strict;
use warnings;

use Neuros::State;
use Neuros::AudioInfo;
use Neuros::Util;
use Neuros::FileUtil;



# Delete the given playlists(s).
sub RemovePlaylist {
  my ($flags, @args) = @_;

  die "No playlist name given to 'rmpl'.\n"
    unless scalar @args > 0;

  my $audio = GetAudio();

  for my $playlist (@args) {
    $audio->deletePlaylist($playlist)
      or asay "No playlist named '$playlist'.";
  }

  return;
}


# Add a file to the given playlist.
sub AddToPlaylist {
  my ($flags, $playlist, @tracks) = @_;
  my $audio = GetAudio();
  my $neurosPath = GetNeurosPath();

  for my $file (@tracks) {
    # Get the relative path.
    my $relFile = RelToNeuros($file, $neurosPath)
      or die "File '$file' not present on the Neuros.\n";

    # Now, try to add it to the playlist.
    $audio->addPlaylistTrack($playlist, $relFile);
  }

  return;
}


sub ListPlaylists {
  my ($flags, @playlists) = @_;

  my $audio = GetAudio();

  # If no playlists are specified, default to all.
  @playlists = $audio->getPlaylistNames()
    unless scalar @playlists;

  for my $playlist (@playlists) {

    # Print the playlist
    print "$playlist\n";

    # Print the contents (if requested).
    next unless $flags->{'contents'};

    for my $track ($audio->getPlaylistContents($playlist)) {
      print "    $track\n";
    }
    print "\n";
  }

  return;
}



1;


