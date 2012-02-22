# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This class writes the Neuros databases.
#
# (This code is derived from the equivalent module in Sorune by Darren
# Smith.)

package Neuros::NdbWriter;

use strict;

use Class::Std;

use File::Basename;
use File::Path;

use Neuros::BinFileWriter;
use Neuros::UnusedDb;
use Neuros::Util;
use Neuros::AudioInfo;


# Main menu text values
use constant {
  NEUROS_AUDIO  => "Neuros Audio",
  SONGS         => "Songs",
  PLAYLISTS     => "Playlists",
  ARTISTS       => "Artists",
  ALBUMS        => "Albums",
  GENRES        => "Genres",
  YEARS         => "Years",
  RECORDINGS    => "Recordings"
};



{
  # Instance vars go here.
  my %audio         : ATTR(:get<audio>);        # The Audio object
  my %neurosDir     : ATTR(:get<neurosDir>);    # The dest. dir
  my %audioLocRef   : ATTR;                     # Hash of audio file positions
  my %paiLocRef     : ATTR;                     # Hash of PAI entries

  sub BUILD {
    my ($self, $ident, $args) = @_;

    $self->_resetLocHash();

    $audio{$ident}      = $args->{audio};
    $neurosDir{$ident}  = $args->{neurosDir};

    return;
  }

  # Return full path to file named $filename in the WOID_DB/audio
  # directory
  sub audioPath {
    my ($self, $filename) = @_;

    return $neurosDir{ident $self} . "/WOID_DB/audio/$filename";
  }


  sub _resetLocHash {
    my ($self) = @_;

    $paiLocRef{ident $self}  = {};
    $audioLocRef{ident $self}  = {x => 1};

    return;
  }


  # Create the Neuros Audio Menu
  sub createNAM {
    my ($self) = @_;

    my $audio = $self->get_audio();
    my $neurosDbHome = $neurosDir{ident $self} . "/WOID_DB/audio";

    # Clear the location hashes.
    $self->_resetLocHash();

    # create the directory
    mkpath $neurosDbHome, 0, 0700;

    # Create the mdbs
    my $artistsHL = $self->_createChildMDB("artist.mdb", "Artist", "audio.mdb",
                                           ARTISTS, "", "artist");

    my $albumsHL = $self->_createMultiMDB("albums.mdb", "Albums", "audio.mdb",
                                         "album", ARTISTS, "artistalbum.mdb");


    my $genresHL = $self->_createChildMDB("genre.mdb", "Genre", "audio.mdb",
                                          GENRES, "", "genre");
    my $yearsHL = $self->_createChildMDB("year.mdb", "Year", "audio.mdb",
                                         YEARS, "", "date");
    my $playlistsHL = $self->_createChildMDB("playlist.mdb", "Playlists",
                                             "audio.mdb", PLAYLISTS, "",
                                             "playlist");
    my $audioHL = $self->_createAudioMDB("audio.mdb", NEUROS_AUDIO, SONGS,
                                         PLAYLISTS, ARTISTS, ALBUMS, GENRES,
                                         YEARS, RECORDINGS);


    # Create the standard PAIs
    $self->_createPAI("artist.pai", "artist", "title");
    $self->_createPAI("albums.pai", "album", "tracknumber");
    $self->_createPAI("genre.pai", "genre", "title");
    $self->_createPAI("year.pai", "date", "title");
    $self->_createPAIplaylist("playlist.pai");


    # Create the standard SAIs
    $self->_createSAI("artist.sai", "artist", $artistsHL);
    $self->_createSAI("albums.sai", "album", $albumsHL);
    $self->_createSAI("genre.sai", "genre", $genresHL);
    $self->_createSAI("year.sai", "date", $yearsHL);
    $self->_createSAIplaylist("playlist.sai", $playlistsHL);
    $self->_createSAI("audio.sai", "title", $audioHL);

    # Create the submenus for 2.14+
    my $artistsAlbumsHL
      = $self->_createChildMDB("artistalbum.mdb", "ArtistAlbum", "albums.mdb",
                              ARTISTS, "", "artist");
    $self->_createPAI("artistalbum.pai", "artist", "album");
    $self->_createSAI("artistalbum.sai", "artist", $artistsAlbumsHL);

    # Create misc databases
    $self->_createMiscDbs();

    return;
  }


  # Creates the albums.mdb database (and could be used for others, of
  # course).  This is different from the others in that it somehow
  # connects to the artistalbums database (so that you can search
  # artists->albums) but I (CR) don't know precisely what's going on
  # here.
  sub _createMultiMDB {
    my ($self, $file, $xref, $xrefFile, $dbKey, @menuItems) = @_;
    my $audio = $audio{ident $self};

    vsay "    Creating $file";

    my $buf = Neuros::BinFileWriter->new();

    # Append the header.
    my $count = scalar (@menuItems) / 2 + 1;
    $buf->word(0);          # Length of header (filled in later)
    $buf->word(4);          # Bit 0 child/root, Bit 1 non-removable/removable
    $buf->word(0);          # Bit 0 modified/non-modified
    $buf->word($count);     # Number of keys per record
    $buf->word(1);          # Number of fields per record
    $buf->dword(0);         # Pointer to record start (filled in later)
    $buf->dword(0);         # Pointer to XIM start (filled in later)
    $buf->dword(0);         # Reserved
    $buf->dword(0);         # Reserved
    $buf->dword(0);         # Reserved
    $buf->word(0);          # Database ID

    $buf->createMenu ($xref => $xrefFile,
                      'All'    => '',
                      @menuItems,
                     );
    $buf->woid();

    # And fixup the header length field.
    my $headerLength = $buf->wsize();
    $buf->wordOverwrite(0, $headerLength);
    $buf->wordOverwrite(12, $headerLength);

    # Append the null record:
    $buf->word(0x8000);
    $buf->word(0x0025);

    # Now write the actual body.
    $self->_childDbRecords ($buf, $dbKey, $audio);

    # And write the record to disk.
    $buf->write($self->audioPath ($file));

    return $headerLength;
  }


  # Create the main audio database (audio.mdb, natch).  The arguments
  # from $neurosAudio on are strings that appear in the menu.
  sub _createAudioMDB {
    my ($self, $file, $neurosAudio, $songs, $playlists,
        $artists, $albums, $genres, $years, $recordings) = @_;
    my $audioLocRef = $audioLocRef{ident $self};
    my $audio = $audio{ident $self};

    vsay "    Creating $file";

    my $buf = Neuros::BinFileWriter->new();

    $buf->word (0,          # Length of header (filled in later)
                1,          # Bit 0 child/root, Bit 1 non-removable/removable
                0,          # Bit 0 modified/non-modified
                6,          # Number of keys
                9);         # Number of fields per record
    $buf->dword(0,          # Pointer to record start (filled in later)
                0,          # Pointer to XIM start (filled in later)
                0,          # Reserved
                0,          # Reserved
                0);         # Reserved
    $buf->word (0);         # Database ID


    $buf->createMenu($neurosAudio => "",
                     $songs     => "",
                     $playlists     => "playlist.mdb",
                     $artists       => "artist.mdb",
                     $albums        => "albums.mdb",
                     $genres        => "genre.mdb",
                     $recordings    => "recordings.mdb");

    my $ximStart = $buf->wsize();
    $buf->wordOverwrite(16, $ximStart);

    # XIM
    $buf->dword(0x00600008,     # HEADER (XIM LENGTH, CMD COUNT)
                0x00200000,              0x00000032,  # CMD1, TEXT OFFSET1
                0x00000000,
                0x00240000,              0x00000036,
                0x00000000,
                0x00230000,              0x0000003A,
                0x00000000,
                0x00030000,              0x00000043,
                0x00000000,
                0x00040000,              0x00000049,
                0x00000000,
                0x00210000,              0x0000004E,
                0x00000000,
                0x80020000,              0x00000053,
                0x00000000,
                0x3FFF0000,              0x0000005C,
                0x00000000);
    $buf->display("Play");
    $buf->display("Info");
    $buf->display("Add To My Mix");
    $buf->display("Shuffle");
    $buf->display("Repeat");
    $buf->display("Delete");
    $buf->display("Delete on Sync");
    $buf->display("Exit");

    $buf->woid();

    my $headerLength = $buf->wsize();
    $buf->wordOverwrite(0, $headerLength);
    $buf->wordOverwrite(12, $headerLength);

    # Add the null record
    $buf->word(0x8000);
    $buf->word(0x0025);

    foreach my $key (@{ $audio->keysSortedBy('title') }) {

      # Save the start position in $audioLocRef.
      my $location = $buf->wsize();
      $audioLocRef->{title}{$key} = $location;
      $audioLocRef->{tracknumber}{$key} = $location;

      # Fetch the mdb record for this track.
      my $info = $audio->getTrack($key);

      #
      # Write the record.
      #

      # Flags
      $buf->word(0x8000);

      # Primary record: the title
      $buf->stringField ($info->{title});

      # Now, the access keys:

      # Playlist field: Point to the null record.  (0x2e is the
      # position of the first record (in words) in a child MDB
      # file.)
      $buf->dwordField (0x2E);

      # Artist
      $buf->dwordField ($audioLocRef->{artist}{$info->{artist}});

      # Album
      $buf->dwordField ($audioLocRef->{album}{$info->{album}});

      # Genre
      $buf->dwordField($audioLocRef->{genre}{$info->{genre}});

      # Recording (unused, points to null record)
      $buf->dwordField(0x2E);


      # Extra info records:

      # Length (i.e. playing time)
      $buf->dwordField($info->{length});

      # Size (in k(?))
      $buf->dwordField($info->{size}/1024);

      # The absolute filename
      $buf->string($key);
#      $buf->dword(0x25);       # FIX should be "word" or "recordDelim"
      $buf->recordDelim();
    }

    $buf->write($self->audioPath ($file));

    return $headerLength;
  }



  sub _createChildMDB {
    my ($self, $file, $xref, $xrefFile, $title, $titleFile,
        $dbKey) = @_;

    vsay "    Creating $file";

    my $audio = $audio{ident $self};

    my $buf = Neuros::BinFileWriter->new();

    $buf->word(0);      # Length of header (filled in later)
    $buf->word(0);      # Bit 0 child/root, Bit 1 non-removable/removable
    $buf->word(0);      # Bit 0 modified/non-modified
    $buf->word(1);      # Number of keys per record
    $buf->word(1);      # Number of fields per record
    $buf->dword(0);     # Pointer to record start (filled in later)
    $buf->dword(0);     # Pointer to XIM start (filled in later)
    $buf->dword(0);     # Reserved
    $buf->dword(0);     # Reserved
    $buf->dword(0);     # Reserved
    $buf->word(0);      # Database ID

    $buf->createMenu($xref  => $xrefFile,
                     $title => $titleFile);
    $buf->woid();

    my $headerLength = $buf->wsize();
    $buf->wordOverwrite(0, $headerLength);
    $buf->wordOverwrite(12, $headerLength);

    # Creat e the null record.
    $buf->word(0x8000);
    $buf->recordDelim();

    $self->_childDbRecords ($buf, $dbKey, $audio);

    $buf->write($self->audioPath($file));

    return $headerLength;
  }


  # Append MDB records for the strings in $recordListRef to $buf, adding
  # locations to $audioLocRef.
  sub _childDbRecords {
    my ($self, $buf, $dbKey, $audio) = @_;
    my $audioLocRef = $audioLocRef{ident $self};

    my $recordListRef = $audio->valuesSorted($dbKey);

    foreach my $record (@{$recordListRef}) {

      # First, store the location of this record for indexing later
      $audioLocRef->{$dbKey}{$record} = $buf->wsize();

      # Next, write out the record.
      $buf->word(0x8000);
      $buf->string($record);
      $buf->recordDelim();
    }

    return;
  }


  # Create the PAI file
  sub _createPAI {
    my ($self, $file, $dbKey, $pdbKey) = @_;
    my $audio = $audio{ident $self};

    vsay "    Creating $file";

    my $buf = Neuros::BinFileWriter->new();

    $self->_createPAIheader($buf);

    my $queryResults = $audio->getSortedQueryResults ($dbKey, $pdbKey);

    foreach my $dbValue (@{ $audio->uniqueDumbSortedValuesOf ($dbKey) }) {
      my $files = $queryResults->{$dbValue};

      $self->_createPAImodule ($buf, $files, $dbKey, $pdbKey);
    }

    $buf->write($self->audioPath($file));
    return 0;
  }


  # Create an individual PAI module.  $dbKey is the field and $files
  # is the list of files that reference this entry.
  sub _createPAImodule {
    my ($self, $buf, $files, $dbKey, $pdbKey) = @_;

    my $audio       = $audio{ident $self};
    my $paiLocRef   = $paiLocRef{ident $self};
    my $audioLocRef = $audioLocRef{ident $self};

    # Work out the data and padding sizes.  (The module must be padded
    # out to the nearest 16 words (32 bytes)).
    my $fileCount = scalar @{$files};
    my $noPadSize = ($fileCount * 2) + 8;
    my $padSize = ($noPadSize % 32) ? 32 - ($noPadSize % 32) : 0;


    # Write out the module header
    $buf->word($noPadSize+$padSize);    # Size of module in words
    $buf->word($fileCount ? 0 : 1);     # State: 1 if empty, otw 0
    $buf->word($fileCount);             # Number of record entries
    $buf->word(0,                       # Reserved
               0,                       # Reserved
               0);                      # Reserved

    # Write out the module entries
    my $paiLocation = $buf->wsize();
    foreach my $key (@{$files}) {
      my $info = $audio->getTrack($key);

      # Store this location for the PAI file
      my $locKey = $info->{$dbKey};
      $paiLocRef->{$dbKey}{$locKey} = $paiLocation;

      # Append this location to the module
      my $paiLoc = $audioLocRef->{$pdbKey};
      my $loc = ($pdbKey eq 'tracknumber' or $pdbKey eq 'title') ?
        $paiLoc->{$key} :
          $paiLoc->{$info->{$pdbKey}};

      $buf->dword($loc);

    }

    # Write out end of module
    $buf->word( (0) x $padSize );   # Write out trailing padding
    $buf->dword(0);                 # Marks end of module

    return;
  }



  # Create the PAI file for the playlist.  This is different from the
  # other PAIs because the Neuros uses the PAI list to determine the
  # contents of the playlist.  That is, the playlist database just
  # holds the names--the actual contents come from the back-pointers in
  # the PAI file.
  sub _createPAIplaylist {
    my ($self, $file) = @_;
    my $audio       = $audio{ident $self};
    my $paiLocRef   = $paiLocRef{ident $self};
    my $audioLocRef = $audioLocRef{ident $self};

    vsay "    Creating $file";

    my $buf = Neuros::BinFileWriter->new();
    $self->_createPAIheader($buf);



    foreach my $playlistName ( $audio->getPlaylistNames() ) {
      my @files = $audio->getPlaylistContents($playlistName);

      # Compute various values that we'll need
      my $fileCount = scalar(@files);
      my $noPadSize = ($fileCount * 2) + 8;
      my $padSize = ($noPadSize % 32) ? 32 - ($noPadSize % 32) : 0;

      # Write out the module header.
      $buf->word ($noPadSize+$padSize, # Size of module in words
                  $fileCount ? 0 : 1, # State: 1 if empty, otw 0
                  $fileCount,   # Number of record entries
                  0);           # Reserved
      $buf->dword (0);          # Reserved

      # Store the start of the header in $audioLocRef for SAI
      # creation later on.
      $paiLocRef->{playlist}{$playlistName} = $buf->wsize();

      # Write out the entries.  The playlist actually consists of
      # these, the PAI pointers.
      foreach my $file (@files) {
        $buf->dword($audioLocRef->{title}{$file});
      }

      # Write end of module
      $buf->word( (0) x $padSize ); # Pad out to 32 bytes
      $buf->dword(0);           # Marks end of module
    }

    $buf->write ($self->audioPath ($file));
    return 0;
  }


  # Write out the header for a PAI database to $buf.
  sub _createPAIheader {
    my ($self, $buf) = @_;

    # The PAI header.
    $buf->dword(0x01162002);        # Signature
    $buf->dword(0);                 # Reserved
    $buf->dword(0);                 # Reserved
    $buf->dword(0);                 # Reserved

    return;
  }



  sub _createSAI {
    my ($self, $file, $dbKey, $headerLength) = @_;
    my $audio = $audio{ident $self};
    my $paiLocRef = $paiLocRef{ident $self};
    my $audioLocRef = $audioLocRef{ident $self};

    vsay "    Creating $file";

    my $buf = Neuros::BinFileWriter->new();

    my $count = $audio->numUniqueValuesOf($dbKey);

    # Write out SAI header.
    $buf->dword(0x05181971);    # Signature
    $buf->dword(0);             # Reserved
    $buf->word($count + 1);     # Number of entries (including empty)
    $buf->word(0);              # Reserved
    $buf->dword(0);             # Reserved
    $buf->dword(0);             # Reserved
    $buf->dword(0);             # Reserved

    # Write out the null record
    $buf->dword($headerLength); # MDB pointer for record 1
    $buf->dword(0);             # PAI pointer for record 1 ???

    # Write out the modules.  The SAI for audio.mdb ($dbKey eq 'title')
    # is special since it doesn't have a PAI (plus, locations are keyed by
    # filename instead of $dbKey).
    my @keys = ($dbKey eq 'title')
      ? @{ $audio->keysSortedBy($dbKey) }
        : @{ $audio->valuesSorted($dbKey) };

    foreach my $value (@keys) {
      my $mdbPointer = $audioLocRef->{$dbKey}{$value};
      my $paiPointer = ($dbKey eq 'title') ? 0 :
        $paiLocRef->{$dbKey}{$value};

      $buf->dword($mdbPointer,
                  $paiPointer);
    }

    # Write out the trailer.
    $buf->dword(0);             # Reserved
    $buf->dword(0);             # Reserved
    $buf->write ($self->audioPath ($file));

    return 0;
  }


  sub _createSAIplaylist {
    my ($self, $file, $headerLength) = @_;
    my $audio = $audio{ident $self};
    my $paiLocRef = $paiLocRef{ident $self};
    my $audioLocRef = $audioLocRef{ident $self};

    my $buf = Neuros::BinFileWriter->new();

    vsay "    Creating $file";

    my $playlists = $audio->valuesSorted('playlist');
    my $count = scalar @{$playlists};

    # Write out the header
    $buf->dword (0x05181971,    # Signature
                 0);            # Reserved
    $buf->word  ($count + 1,    # Number of entries plus the null
                 0);            # Reserved
    $buf->dword (0,             # Reserved
                 0,             # Reserved
                 0,             # Reserved
                 $headerLength, # MDB pointer for record 1
                 0);            # PAI pointer for record 1

    # Write out the locations
    foreach my $list (@{$playlists}) {
      $buf->dword($audioLocRef->{playlist}{$list},
                  $paiLocRef->{playlist}{$list});
    }

    # And, the trailer.
    $buf->dword (0,             # Reserved
                 0);            # Reserved

    $buf->write($self->audioPath ($file));
    return 0;
  }


  # Create the unused databases.
  sub _createMiscDbs {
    my ($self) = @_;
    my $home = $neurosDir{ident $self} . '/WOID_DB/';

    vsay "    Creating dummy databases";

    my $buf = Neuros::BinFileWriter->new();

    for my $fileEntry (@EmptyDBs) {
      my ($name, $value) = @{$fileEntry};

      $name = "$home/$name";

      my $dir = dirname ($name);
      mkpath $dir
        unless -d $dir;

      my $binValue = unpack ('u*', $value);
      $buf->byteString($binValue);
      $buf->write ($name);
      $buf->reset();
    }

    return;
  }

}


1;
