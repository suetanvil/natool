# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Instances represent the contents of the master list in an internal
# format.  Can be read or written to text files.

package Neuros::AudioInfo;

use strict;
use warnings;

use Scalar::Util qw{looks_like_number};
use Class::Std;
use File::Basename;
use File::Copy;
use File::Spec::Functions;

use Neuros::AlbumRenameList;
use Neuros::FilePair;
use Neuros::Asciify;
use Neuros::Util;

use constant ML_NAME => 'audio.mls';

# Allowed fields of $musicDbRef.  ('playlist' is also sometimes
# tolerated.)  Note that order is important.
use constant FIELDS
  => qw {date size genre album artist length tracknumber title};
use constant NUM_FIELDS
  => qw {size length tracknumber};
use constant TEXT_FIELDS
  => qw {date genre album artist title};


{
  my %musicDbRef    : ATTR;                     # Big Hash o' audio metadata
  my %playlistDbRef : ATTR;                     # Playlists (name=>track list)
  my %artistSort    : ATTR(get<artistSort>);    # mode of artist list sort
  my %artistCntThr  : ATTR;                     # Threshold for sort-by-count

  my %artistTrkCount: ATTR;                     # Number of tracks per artist
  my %sortCache     : ATTR;                     # Hash of cached 'valuesSorted'

  # Class variables:
  my %allowedFields = map { $_ => 1 } FIELDS;

  ######################################################################
  #
  # Initialization
  #

  sub BUILD {
    my ($self, $ident, $args) = @_;

    $musicDbRef{$ident} = {};
    $playlistDbRef{$ident} = {};
    $artistCntThr{$ident} = -1;

    $artistTrkCount{$ident} = {};
    $sortCache{$ident} = {};

    $self->setArtistSort('smart');

    return;
  }



  ######################################################################
  #
  # Adding and removing entries
  #

  # Add a track.  Note that the argument order matches FIELDS.  This
  # should be the ONLY way to add a track.  Everything else should
  # call this method.
  sub addTrack {
    my ($self, $fileName, $date, $size, $genre, $album, $artist, $length,
        $trackNumber, $title) = @_;

    # Ensure all arguments are defined.
    defined($title)
      or die "Invalid number of arguments or undefined title.\n";

    # Normalize the filename a bit
    $fileName = $self->_cleanKey($fileName);

    # Ensure that $fileName is acceptible for the Neuros (i.e. is in
    # the pseudo-DOS format, is ASCII and does not contain a tab
    # character.  The latter is needed for the master list file.)
    die "Filename '$fileName' contains illegal character(s)\n"
      unless isValidNeurosPath ($fileName);
    die "Filename '$fileName' contains a tab character.\n"
      if $fileName =~ /\t/;
    die "Invalid filename format.\n"
      unless $fileName =~ m{^C:/};

    # Create the record, ensuring that all arguments are defined and
    # have a reasonable value.
    my $record = {};

    $record->{date}         = $date         || '0';
    $record->{size}         = $size         || 0;
    $record->{genre}        = $genre        || '';
    $record->{album}        = $album        || '';
    $record->{artist}       = $artist       || '';
    $record->{length}       = $length       || 0;
    $record->{tracknumber}  = $trackNumber  || 0;
    $record->{title}        = $title        || '';

    # Remove tabs and suspicious characters from the string entries
    for my $key (TEXT_FIELDS) {
      die "Invalid character in '$key' field.\n"
        if $record->{$key} =~ /[[:^ascii:]\r\n\f]/;

      $record->{$key} =~ s/\t/qq{ }x4/g;        # Replace tabs w/ 4 spaces

      # Remove nulls.  (This almost never happens but it means I don't
      # need to escape metacharacters when creating the database.)
      $record->{$key} =~ s/\x00//g;
    }

    for my $key (NUM_FIELDS) {
      die "Non-numeric value for field '$key'\n"
        unless looks_like_number($record->{$key});
    }

    # Store the record in the Big Hash.
    $musicDbRef{ident $self}->{$fileName} = $record;

    # And purge the caches.
    $self->_purgeCachedQueries();

    return;
  }


  # Remove unnecessary elements from a key.  This should (hopefully)
  # make it easier to map a file to a key.  Also ensures that the
  # leading 'C:/' is present.
  sub _cleanKey {
    my ($self, $key) = @_;

    # Initial cleanup with canonpath
    $key =~ s{^C:/*}{}i;
    $key = "C:" . canonpath("/$key");

    # Clean up /../ sequences since canonpath doesn't do that.
    while ($key =~ s{ / [^/]+ / \.\. / }{/}xg) {};

    return $key;
  }



  # Add $track to the playlist named $plName, creating it if
  # necessary.
  sub addPlaylistTrack {
    my ($self, $plName, $track) = @_;
    my $musicDbRef = $musicDbRef{ident $self};
    my $pldRef = $playlistDbRef{ident $self};

    # Ensure that the playlist name is legal.  (We don't need to check
    # $track because addTrack will have done that already.)
    die "Illegal character in playlist name '$plName'\n"
      unless (isValidNeurosPath($plName) && $plName !~ m{\W});
    die "Playlist name '$plName' is more than 63 characters long.\n"
      unless length($plName) <= 63;

    # First, launder the track names.
    $track = $self->_cleanKey($track);

    # Ensure $track is valid
    return unless exists($musicDbRef->{$track});

    # Create this playlist if it doesn't already exist
    $pldRef->{$plName} = []
      unless exists($pldRef->{$plName});

    # Append the tracks to it
    push @{$pldRef->{$plName}}, $track;

    return;
  }


  # Delete the playlist named by $name.  Return true on success, false
  # if it's missing.
  sub deletePlaylist {
    my ($self, $name) = @_;
    my $playlistDbRef = $playlistDbRef{ident $self};

    return 0 unless exists($playlistDbRef->{$name});

    delete $playlistDbRef->{$name};
    return 1;
  }


  # Remove the track with key $key.  Return true if deleted, false if
  # not present.
  sub deleteTrack {
    my ($self, $key) = @_;

    $key = $self->_cleanKey($key);
    my $mdb = $musicDbRef{ident $self};

    return 0 unless exists($mdb->{$key});

    delete $mdb->{$key};

    $self->_purgeCachedQueries();

    return 1;
  }


  # Delete all tracks whose keys are not also keys of the hash at
  # $keysHashRef.  (Presumably, $keysHashRef will have been built up
  # by a find() on the Neuros' hard drive, in which case this removes
  # entries for all missing files.)
  sub deleteTracksNotIn {
    my ($self, $keysHashRef) = @_;

    for my $key (@{ $self->keysUnsorted() }) {
      $self->deleteTrack($key)
        unless defined($keysHashRef->{$key});
    }

    return;
  }


  # Delete any cached queries we may have.  Currently, only track
  # add/remove operations affect this, but it could easily be
  # extended.
  sub _purgeCachedQueries {
    my ($self) = @_;

    $sortCache{ident $self} = {};
    $artistTrkCount{ident $self} = {};

    return;
  }




  ######################################################################
  #
  # Content queries
  #

  # Return the values of $keyField, which must be one of a known
  # list of field names, in a list ref.
  sub valuesOf {
    my ($self, $keyField) = @_;

    die "Invalid sort field '$keyField'\n"
      unless $allowedFields{$keyField} || $keyField eq 'playlist';

    my @values;

    if ($keyField eq 'playlist') {
      @values = keys %{ $playlistDbRef{ident $self} };
    } else {
      my $mdbRef = $musicDbRef{ident $self};
      @values = map { $mdbRef->{$_}{$keyField} } keys %{$mdbRef};
    }

    return \@values;
  }

  # Like valuesOf but makes sure each entry appears only once.
  sub uniqueValuesOf {
    my ($self, $keyField) = @_;

    my %uniqueValues = map { $_ => 1 } @{$self->valuesOf($keyField)};
    delete $uniqueValues{''};   # sigh
    return [keys %uniqueValues];
  }


  # Return a reference to the list of keys sorted into the canonical
  # order.
  sub keysSorted {
    my ($self) = @_;

    return [sort keys %{ $musicDbRef{ident $self} } ];
  }


  # Return a reference to the list of keys unsorted.
  sub keysUnsorted {
    my ($self) = @_;

    return [keys %{ $musicDbRef{ident $self} } ];
  }


  # Return the list of keys (filenames) in $self sorted by the
  # values of subfield $keyField.  For example, if $keyField is
  # 'title', it will return the list of all tracks sorted by title.
  sub keysSortedBy {
    my ($self, $keyField) = @_;

    my $mdb = $musicDbRef{ident $self}; # Convenience

    die "Invalid sort field '$keyField'\n"
      unless $allowedFields{$keyField} && $keyField ne 'playlist';

    # Get the comparison function:
    my $cmp = $self->_getFieldCmp($keyField);

    # And sort by the values of $keyField
    my @keys = sort { $cmp->($mdb->{$a}{$keyField}, $mdb->{$b}{$keyField}) }
      keys %{$mdb};
    return \@keys;
  }


  # Like valuesSorted but does a simple dumb string comparison sort.
  # This is here to work around Sorune behaviour and should be
  # removed.
  sub uniqueDumbSortedValuesOf {
    my ($self, $keyField) = @_;

    my %values = map { $_ => 1 } @{ $self->valuesOf($keyField) };

    $values{'0'} = 1 if ($keyField eq 'date' && exists $values{''});
    delete $values{''};

    my @sortedValues = sort keys %values;

    return \@sortedValues;
  }


  # Return the values of all entries of the field named by $keyField,
  # sorted and made unique.
  sub valuesSorted {
    my ($self, $keyField) = @_;

    $sortCache{ident $self}->{$keyField}
      ||= $self->_computeValuesSorted($keyField);

    return  $sortCache{ident $self}->{$keyField};
  }

  # Does the actual computation of valuesSorted.
  sub _computeValuesSorted {
    my ($self, $keyField) = @_;

    # First, get the values we care about
    my $valRef = $self->valuesOf ($keyField);

    # Next, strip out duplicates
    my %seenIt = map { $_ => 1} @{$valRef};
    my @values = keys %seenIt; # To do: merge this step with the next one

    # Finally, sort the values.
    my $cmp = $self->_getFieldCmp($keyField);
    @values = sort { $cmp->($a, $b) } @values;

    #Teh enb
    return \@values;
  }


  # Return the number of unique values for field $dbField. $dbField
  # 'title' is a special case--we use keys (i.e. filenames) instead.
  # This is a holdover from Sorune.  Callers must take this into
  # account.
  sub numUniqueValuesOf {
    my ($self, $dbField) = @_;

    # If it's the playlist, we handle that separately.
    return scalar keys %{ $playlistDbRef{ident $self} }
      if $dbField eq 'playlist';

    my $mdbRef = $musicDbRef{ident $self};

    return scalar keys %{$mdbRef}
      if ($dbField eq "title");

    return scalar @{$self->uniqueValuesOf ($dbField)};
  }



  # Return a hash keyed by all possible values of $dbField mapped to
  # arrays of filenames for files whose $dbField field equals the key
  # AND each value of the $selectorField field is unique.  If
  # $selectorField is false (empty or undefined), returns all values,
  # not just the unique ones.
  #
  # So if $dbField is 'genre' and $selectorField is 'artist', returns a
  # hash where keys are all genres and values are lists of files belonging
  # to that genre where each file has a different artist.
  #
  # If $selectorField is NOT one of 'artist' or 'album', all values
  # are returned, not just one for each value of $selectorField.
  sub getSortedQueryResults {
    my ($self, $dbField, $selectorField) = @_;

    my $bigHash = $self->_getUniqueQueryResults($dbField, $selectorField);
    $self->_sortQueryResults ($bigHash, $selectorField);

    return $bigHash;
  }


  # Sort the values of $bigHash in place.  $bigHash is a list of keys
  # into $musicDbRef{} and $dbField determines the sort critera
  sub _sortQueryResults {
    my ($self, $bigHash, $dbField) = @_;
    my $mdb = $musicDbRef{ident $self};

    # Get the comparison function
    my $cmp = $self->_getFieldCmp($dbField);
    my $sortFn = sub { $cmp->($mdb->{$a}{$dbField}, $mdb->{$b}{$dbField}) };

    # Sort the values.
    for my $fileList (values %{$bigHash}) {
      @{$fileList} = sort $sortFn @{$fileList};
    }

    return;
  }



  # Compute the Big Hash o' Results
  sub _getUniqueQueryResults {
    my ($self, $dbField, $selectorField) = @_;

    my $mdb = $musicDbRef{ident $self};

    # Only artist and album require unique values
    $selectorField = ''
      unless ($selectorField =~ /^(album|artist)$/);

    my $result = {};
    my $seenItFor = {};
    for my $filename (keys %{$mdb}) {
      my $resultKey = $mdb->{$filename}{$dbField};

      # Skip the empty value (but not 0)
      next if !defined($resultKey) || $resultKey eq '';

      # Skip the duplicates
      if ($selectorField) {
        my $selectorValue = $mdb->{$filename}{$selectorField};
        next if exists($seenItFor->{$resultKey}{$selectorValue});
        $seenItFor->{$resultKey}{$selectorValue} = 1;
      }

      # Stash the values as we find them
      $result->{$resultKey} = []
        unless exists ($result->{$resultKey});

      push @{ $result->{$resultKey} }, $filename;
    }

    return $result;
  }

  # Return a list of playlist names
  sub getPlaylistNames {
    my ($self) = @_;

    return sort keys %{ $playlistDbRef{ident $self} };
  }

  # Return the files in the named playlist
  sub getPlaylistContents {
    my ($self, $playlistName) = @_;

    my $filesRef = $playlistDbRef{ident $self}->{$playlistName}
      or die "Invalid playlist name '$playlistName'\n";

    return @{$filesRef};
  }


  # Get the metadata about the file at $key, the mdb key value.
  sub getTrack {
    my ($self, $key) = @_;

    $key = $self->_cleanKey($key);

    my $entry = $musicDbRef{ident $self}->{$key}
      or die "Unknown audio file '$key'.\n";

    # Copy the hash (so the caller can't modify the original).
    my $result = { %{$entry} };

    return $result;
  }


  # Return a hash of hashes of hashes.  The outer hash is keyed by
  # artist and thevalues are hashes keyed by albums.  The album hashes
  # map album titles to lists of tracks contained in the album.
  sub getArtistAlbumTrackHash {
    my ($self) = @_;
    my $mdb = $musicDbRef{ident $self};

    my $aatHash = {};

    for my $trackName (keys %{$mdb}) {
      my $trackInfo = $self->getTrack($trackName);

      my $artist = $trackInfo->{artist};
      my $album = $trackInfo->{album};

      push @{$aatHash->{$artist}->{$album}}, $trackName;
    }

    # Now, sort all tracks
    my $cmp = $self->_getFieldCmp('tracknumber');
    for my $artist (keys %{$aatHash}) {
      for my $album (keys %{$aatHash->{$artist}}) {
        my $tracksRef = $aatHash->{$artist}->{$album};

        @{$tracksRef} =
          sort { $cmp->($mdb->{$a}{tracknumber}, $mdb->{$b}{tracknumber}) }
            @{$tracksRef};
      }
    }

    return $aatHash;
  }



  ######################################################################
  #
  # Storing and retrieving
  #

  # Store contents in the directory "$destDir" as the master list
  # file.
  sub writeMlTo {
    my ($self, $destDir) = @_;

    $self->_writeAudioMl("$destDir/" . ML_NAME);
    $self->_writePlaylists($destDir);

    return;
  }

  # Write out the contents of $audioDbRef to the given filename as a
  # file of tab-delimited fields.
  sub _writeAudioMl {
    my ($self, $destFile) = @_;
    my $music = $musicDbRef{ident $self};

    vsay "Writing $destFile";

    open my $fh, ">", $destFile
      or die "Unable to open file '$destFile' for writing.\n";

    for my $key (@{ $self->keysSorted() }) {
      print {$fh} join ("\t", $key, map { $music->{$key}{$_} } FIELDS ), "\n"
        or die "Error printing output line to '$destFile'.\n";
    }

    close $fh;

    return;
  }


  # Write out the playlists as .npl files (i.e. Neuros playlists).
  sub _writePlaylists {
    my ($self, $destDir) = @_;

    $self->cleanPlaylists();

    $self->_backupPlaylistFiles($destDir);

    for my $plName ( $self->getPlaylistNames() ) {
      $self->_writeOnePlaylist($destDir, $plName);
    }

    return;
  }


  # Delete all playlist files in $destDir.  Only, don't delete
  # them--just rename them to a backup file (i.e. the same name but
  # with a tilde ("~") at the end).
  sub _backupPlaylistFiles {
    my ($self, $destDir) = @_;

    # Fetch the natools directory's contents.  (I use opendir because
    # I'm paranoid about glob and the value of $destDir).
    opendir my $dh, $destDir
      or return;
    my @files = readdir $dh;
    close $dh;

    for my $basename (@files) {
      my $file = "$destDir/$basename";
      next unless (-f $file && $file =~ /\.npl$/);

      move ($file, "$file~")
        or asay "Unable to backup playlist file '$file'\n";
    }

    return;
  }



  # Write out the playlist named by $plName to $destDir after first
  # backing up the original (if present).  Skips saving (but not
  # renaming/backing up) if the playlist is empty.
  sub _writeOnePlaylist {
    my ($self, $destDir, $plName) = @_;

    my $fname = "$destDir/$plName.npl";

    # Back up the old version.
    if (-f $fname) {
      move ($fname, "$fname~")
        or die "Unable to back up '$fname'.\n";
    }

    # Get the playlist contents so we can see if it's empty and bail.
    my @plContents = $self->getPlaylistContents ($plName);
    return if scalar @plContents == 0;

    # Now, do the actual write.
    open my $fh, ">", $fname
      or die "Unable to open '$fname' for writing.\n";

    print {$fh} join ("\n", @plContents), "\n"
      or die "Error writing to file '$fname'\n";

    close $fh;

    return;
  }



  # Fetch contents from the directory "$srcDir".
  sub readDbFrom {
    my ($self, $srcDir) = @_;

    die "Internal error: expecting load into an empty object.\n"
      if scalar keys %{ $musicDbRef{ident $self} };

    my $srcFile = "$srcDir/" . ML_NAME;

    $self->_readAudioDb($srcFile) if -f $srcFile;
    $self->readPlaylists($srcDir, 0);

    return;
  }


  # Read in the audio DB.
  sub _readAudioDb {
    my ($self, $srcFile) = @_;

    vsay "Reading $srcFile";

    open my $fh, "<", $srcFile
      or die "Unable to open '$srcFile' for reading.\n";

    while (my $rec = <$fh>) {
      chomp $rec;

      my @tracks = split (/\t/, $rec);

      die "Invalid record in '$srcFile'\n"
        if scalar @tracks != scalar (FIELDS) + 1;

      $self->addTrack(@tracks);
    }

    close $fh;

    return;
  }


  # Read in all playlists in $srcDir
  sub readPlaylists {
    my ($self, $srcDir, $allowMissing) = @_;

    # Clear the playlist hash
    %{ $playlistDbRef{ident $self} } = ();

    # Add the new playlists
    for my $file (listFiles ($srcDir, "npl")) {
      vsay "Reading playlist '@{[basename($file)]}'.";
      $self->_readOnePlaylist($file, $allowMissing);
    }

    return;
  }


  # Read the playlist at $playlistFile into the playlist hash.
  sub _readOnePlaylist {
    my ($self, $playlistFile, $allowMissing) = @_;

    # Create the playlist name
    my $plName = basename($playlistFile);
    $plName =~ s/\.npl$//;

    # Read in the playlist
    open my $fh, "<", $playlistFile
      or die "Unable to open '$playlistFile' for reading.\n";

    while (my $entry = <$fh>) {
      chomp $entry;
      $self->addPlaylistTrack($plName, $entry);
    }

    close $fh;
  }


  # Return $artistTrkCount, filling it first if necessary.
  # $artistTrkCount is a histogram of tracks for each artist in
  # $musicDbRef.
  sub _tracksPerArtist {
    my ($self) = @_;

    if (! %{ $artistTrkCount{ident $self} }) {
      my $mdb = $musicDbRef{ident $self};
      my %counts;

      for my $track (keys %{$mdb}) {
        $counts{$mdb->{$track}->{artist}}++
      }

      $artistTrkCount{ident $self} = \%counts;
    }

    return $artistTrkCount{ident $self}
  }




  ######################################################################
  #
  # Data manipulation
  #

  # Go through the list of playlists and remove all entries which no
  # longer exist in the musicDbRef.  If this leaves a playlist empty,
  # also remove the playlist.
  sub cleanPlaylists {
    my ($self) = @_;
    my $playlistDbRef = $playlistDbRef{ident $self};
    my $musicDbRef = $musicDbRef{ident $self};

    for my $plName (keys %{$playlistDbRef}) {
      $playlistDbRef->{$plName}
        = [grep { defined($musicDbRef->{$_}) } @{$playlistDbRef->{$plName}}];

      delete ($playlistDbRef->{$plName})
        unless scalar @{$playlistDbRef->{$plName}};
    }

    return;
  }


  # Set the sort mode for sorting artist names
  sub setArtistSort {
    my ($self, $sortName) = @_;

    die "Internal error: Sort type must be either 'smart' or 'dumb'.\n"
      unless ($sortName eq 'smart' || $sortName eq 'dumb');

    $artistSort{ident $self} = $sortName;

    return;
  }


  # Set $artistCntThr, the threshold at which an artist is considered
  # common enough to be sorted to the front of the list.
  sub setSortMinCount {
    my ($self, $min) = @_;

    $artistCntThr{ident $self} = $min;

    return;
  }


  # Return a sort function suitable for comparing values of field type
  # $field.  Note that the resulting function is not expected to
  # survive past the end of the actual sort operation.
  sub _getFieldCmp {
    my ($self, $field) = @_;

    my $dumbSort = sub {my ($a, $b) = @_; $a cmp $b};

    my $sortfn;
    if ($field eq 'artist') {
      # Artists are sorted specially, depending on %artistSort.

      my $sortName = $artistSort{ident $self};

      if ($sortName eq 'smart') {
        my $threshold = $artistCntThr{ident $self};
        my $counts = $self->_tracksPerArtist();

        $sortfn = sub {
          my ($a, $b) = @_;

          # If count-sort is enabled, artists with more than
          # $threshold tracks get grouped together first.
          if ($threshold > 0) {
            my $la = $counts->{$a} >= $threshold ? 0 : 1;
            my $lb = $counts->{$b} >= $threshold ? 0 : 1;
            my $cmp = $la <=> $lb;

            return $cmp
              unless $cmp == 0;
          }

          for my $nm ($a, $b) {
            $nm = lc($nm);
            $nm =~ s/^the\s//;
            $nm =~ s/^\s*//;
          }

          return $a cmp $b;
        };
      } else {  # Default to 'dumb' if not set to 'smart'
        $sortfn = $dumbSort;
      }

    } elsif ($field eq 'date') {
      # Dates are sorted backward
      $sortfn = sub {my ($a, $b) = @_; $b cmp $a};

    } elsif ($field eq 'tracknumber') {
      # Track numbers are sorted numerically
      $sortfn = sub {my ($a, $b) = @_; $a <=> $b};

    } else {
      # Everything else gets sorted lexically
      $sortfn = $dumbSort;
    }

    return $sortfn;
  }



  # Go through the Big Hash and if necessary, change the names of some
  # albums to ensure that each album name is unique within the Big
  # Hash.  If $uniqueByDir is true, also ensures that they are unique
  # to the directory they occupy.
  sub makeAlbumsUnique {
    my ($self, $uniqueByDir) = @_;
    my $mdb = $musicDbRef{ident $self};

    my $renameList = Neuros::AlbumRenameList->new({isByDir => $uniqueByDir});

    $renameList->scan($self);

    for my $renameRef ($renameList->toDo()) {
      $mdb->{$renameRef->[0]}->{album} = $renameRef->[1];
    }

    # And since we've changed the mdb, we need to purge the cache
    $self->_purgeCachedQueries();

    return;
  }


}#End AudioInfo


1;
