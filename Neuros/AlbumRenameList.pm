# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Instances create a list of files and the new album names they must
# receive in order to guarantee unique album names.

package Neuros::AlbumRenameList;

use strict;
use warnings;

use Class::Std;

use File::Basename;

use Neuros::Util;


{
  my %albumHash     :ATTR;  # Hash of albums to artists to tracks.  See below.
  my %newAlbumNames :ATTR;  # Hash mapping artist => album => new name
  my %isByDir       :ATTR;  # Flag. If true, album is expected to be in one dir


=pod

Data structures:

$albumHash:

This is a hash mapping album titles to another hash, this one mapping
artists to an array reference of audio files (actually, Neuros paths,
specifically keys into $musicDbRef) belonging to that artist and
album.

For example, suppose the artists U2 and U3 (name still available
as of this writing) both have an album called "War".  The
resulting hash would look like:

    {...
     "War" => {"U2" => ['C:/U2/War/1.mp3', 'C:/U2/War/2.mp3', ...],
               "U3" => ['C:/U3/War/1.mp3', 'C:/U3/War/2.mp3', ...],
              },
    ...
    }

If $isByDir is set, a path ID is prepended to the album name.  This
consists of a number followed by a comma (","):

    {...
     "War" => {"23,U2" => ['C:/U2/War/1.mp3', 'C:/U2/War/2.mp3', ...],
               "542,U3" => ['C:/U3/War/1.mp3', 'C:/U3/War/2.mp3', ...],
              },
    ...
    }

Each number corresponds to the path to the audio files containing this
album.  The ID is used to force the album to be unique to its
containing directory.


$newAlbumNames

This is a hash of hashes mapping artist to album to new name.  For the
above data, this will end up looking something like this:

    {...
     "U2"   => {"War"   => "War (U2)",
                ...},
     ...
    }


$isByDir

If $isByDir is true, artist names are mangled with the path to the
album dir.  Otherwise, paths are ignored and we only distinguish
between them by album name.

=cut



  ######################################################################
  #
  # Initialization
  #

  sub BUILD {
    my ($self, $ident, $args) = @_;

    $albumHash{$ident}      = {};
    $newAlbumNames{$ident}  = {};
    $isByDir{$ident}        = $args->{isByDir};
  }





  ######################################################################
  #
  # Public interface
  #

  # Go through $audio (an AudioInfo) and create the data structures
  # used to get the change list created by toDo().
  sub scan {
    my ($self, $audio) = @_;

    $self->_initAlbumHash($audio);
    $self->_initNewAlbumNames();
    $self->_computeNewNames();
    $self->_makeNewNamesUnique();

    return;
  }


  # Return a list of array references, each containing a track and the
  # new album field to give it.
  sub toDo {
    my ($self) = @_;

    my $newAlbumNames   = $newAlbumNames{ident $self};
    my $albumHash       = $albumHash{ident $self};

    my @result = ();
    for my $artist (sort keys %{$newAlbumNames}) {
      for my $album (sort keys %{$newAlbumNames->{$artist}}) {
        for my $track (@{ $albumHash->{$album}->{$artist} }) {
          push @result, [$track, $newAlbumNames->{$artist}->{$album}];
        }
      }
    }

    return @result;
  }


  # Return the artist name as it appears in the master list and the
  # Neuros display.  If $isByDir is set, this means stripping off the
  # leading directory ID.
  sub _properArtistName {
    my ($self, $artistName) = @_;

    $artistName =~ s/^\d+\,//g
      if $isByDir{ident $self};

    return $artistName;
  }


  # Initialize $albumHash from the contents of $audio.  If $isByDir is
  # true, prepends a number representing the parent directory path to
  # the album name in order to make it unique.
  sub _initAlbumHash {
    my ($self, $audio) = @_;

    # Hash to assign a unique number to each path.
    my %seenPaths = ();
    my $pathCount = 0;

    my $hash = {};

    for my $file (@{ $audio->keysSorted() }) {
      my $trk = $audio->getTrack($file);

      my $artistKey = $trk->{artist};

      if ($isByDir{ident $self}) {
        my $dir = dirname($file);
        $seenPaths{$dir} = $pathCount++
          unless exists($seenPaths{$dir});

        $artistKey = "$seenPaths{$dir},$artistKey";
      }

      push @{ $hash->{$trk->{album}}->{$artistKey} }, $file;
    }

    $albumHash{ident $self} = $hash;

    return;
  }


  # Initialize $newAlbumNames from $albumHash using the original album
  # names.
  sub _initNewAlbumNames {
    my ($self) = @_;
    my $albumHash = $albumHash{ident $self};

    my $nan = {};
    for my $album (keys %{ $albumHash }) {
      for my $artist (keys %{ $albumHash->{$album} }) {
        $nan->{$artist}->{$album} = $album;
      }
    }

    $newAlbumNames{ident $self} = $nan;

    return;
  }


  # Go through $albumHash and for each duplicated album name, create a
  # unique name for it and put it in $newAlbumNames.
  sub _computeNewNames {
    my ($self) = @_;
    my $albumHash = $albumHash{ident $self};

    # Create set of albums already seen.  We start with $albumHash but
    # add the new ones as well so there's no duplication possible.
    my %seenAlbums = map { $_ => 1 } keys %{$albumHash};

    my $result = {};
    for my $album (sort keys %{$albumHash}) {

      # Skip the singletons
      next if scalar keys %{$albumHash->{$album}} == 1;

      # If we're differentiating by dir. as well as artist, we need to
      # keep track of the number of times each artist appears so we
      # know when to just tack a number to the end.  We also delete
      # the artist from %seenAlbums so that the first instance doesn't
      # become "$artist [2]".
      my %artistCount = ();
      if ($isByDir{ident $self}) {

        for my $artist (keys %{$albumHash->{$album}}) {
          my $pname = $self->_properArtistName($artist);
          $artistCount{$pname}++;

          delete ($seenAlbums{$album})
            if $artistCount{$pname} > 1;
        }
      }

      # And add artist name to the modifiers
      my $newAlbumNames = $newAlbumNames{ident $self};
      for my $artist (keys %{$albumHash->{$album}} ) {
        my $realArtist = $self->_properArtistName($artist);

        my $newName = $newAlbumNames->{$artist}->{$album};

        # If we're differentiating by directory and not artist, we
        # just let uniqueKey handle this.
        $newName = "$newName ($realArtist)"
          unless ($isByDir{ident $self} && $artistCount{$realArtist} > 1);

        $newName = uniqueKey ($newName, \%seenAlbums);

        $newAlbumNames->{$artist}->{$album} = $newName;
        $seenAlbums{$newAlbumNames} = 1;
      }
    }

    return;
  }


  # Go through $newAlbumNames and ensure that none of the names are
  # duplicated.
  sub _makeNewNamesUnique {
    my ($self) = @_;
    my $newAlbumNames = $newAlbumNames{ident $self};

    my $albumSet = {};

    for my $artist (keys %{$newAlbumNames}) {
      for my $album (keys %{ $newAlbumNames->{$artist} }) {
        my $newName = uniqueKey($newAlbumNames->{$artist}->{$album},
                                $albumSet);
        $newAlbumNames->{$artist}->{$album} = $newName;
        $albumSet->{$newName} = 1;
      }
    }

    return;
  }


}


1;
