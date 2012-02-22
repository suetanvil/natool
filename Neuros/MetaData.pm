# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

#
# This module reads the metadata from an audio file and returns it.
#

package Neuros::MetaData;

use Exporter 'import';
our @EXPORT = qw{GetTags};

use strict;
use warnings;

use Scalar::Util 'looks_like_number';
use File::Basename;

use MP3::Info qw{:all};
use Ogg::Vorbis::Header::PurePerl;

use Neuros::Asciify;
use Neuros::AudioInfo;  # Needed for the constants
use Neuros::Util;
use Neuros::FileUtil;

# Enable winamp genres for mp3 support.
use_winamp_genres();



# Extract the metadata from the given audio file and return a list
# containing the tags (plus filename) in the order specified by
# RETURN_KEYS.  This order matches the argument order of
# AudioInfo::addTrack.  Arguments are cleaned up for entry into the
# master list.  Errors result in the return of an empty list.
#
# $mountPoint is the path to the Neuros.  $relInstPath is the path,
# relative to the mountpoint, to the file being read and must be pure
# 7-bit ASCII.  If $localPath is also given, it must the absolute path
# to a local copy of the file.  If it is not given,
# "$mountPoint/$relInstPath" is used instead. (Think of the case where
# a file is being copied from the PC to the Neuros.  It may not yet be
# present on the Neuros but that's where it's going to be when the
# Neuros plays it.  Also, reading the local disk is faster.)
{
  my %typeHandlers
    = (ogg              => \&handleOgg,
       mp3              => \&handleMp3);

  sub GetTags {
    my ($mountPoint, $relInstPath, $localCopy) = @_;

    # Sanity check.  If this fails, it probably means that the user
    # has used some other program to copy files to the Neuros.
    die "Filename '$relInstPath' on Neuros contains illegal characters.\n"
      unless isValidNeurosPath($relInstPath);

    my $fullPath = $localCopy || "$mountPoint/$relInstPath";

    # Find the handler for this file type (or nothing, if it's wrong.)
    my $ext = GetAudioExt($fullPath);
    return unless defined($typeHandlers{$ext});

    my $tags = $typeHandlers{$ext}->($fullPath)
      or return;

    return cleanTags ($relInstPath, $tags);
  }
}



# Given a hash of tags and a filename, ensure that all values are in a
# format suitable for storage in the master list and the Neuros
# database.  $filename is expected to be a valid Neuros path.
sub cleanTags {
  my ($filename, $tagsRef) = @_;

  # Ensure that the ID3 tags all have meaningful values.
  $tagsRef->{title}         ||= basename($filename);
  $tagsRef->{artist}        ||= "UnknownArtist";
  $tagsRef->{album}         ||= "UnknownAlbum";
  $tagsRef->{date}          ||= '0';
  $tagsRef->{genre}         ||= "Other";
  $tagsRef->{tracknumber}   ||= 0;

  # Remove/fix all non-ASCII characters
  for my $tag (Neuros::AudioInfo::TEXT_FIELDS) {
    $tagsRef->{$tag} = toAscii($tagsRef->{$tag});
  }

  # Remove any non-numerics from fields which expect numeric values
  for my $tag (Neuros::AudioInfo::NUM_FIELDS) {
    $tagsRef->{$tag} = 0
      unless looks_like_number($tagsRef->{$tag});
  }

  # Convert the filename to something suitable for the Neuros
  $filename =~ s{^/*}{};    # Strip off leading slash
  $filename = "C:/$filename";

  # Return the tags as a list suitable for passing to
  # AudioInfo::addTrack().
  my @result = ($filename);
  push @result, map { $tagsRef->{$_} } Neuros::AudioInfo::FIELDS;

  return @result;
}



# Extract the metadata from Ogg file $filename.
sub handleOgg {
  my ($filename) = @_;

  my $result = {};;

  # Return unless we can find the filename and it has non-zero length
  return undef unless (-r $filename && -s $filename);

  # Ogg::Vorbis::Header::PurePerl has this annoying habit of issuing
  # warnings when it should really just keep its mouth shut and return
  # undef.  So, we trap them here.
  local $SIG{__WARN__} = sub{};

  # Create the ogg reader and load $filename.
  my $ogg = Ogg::Vorbis::Header::PurePerl->load($filename)
    or return undef;

  # Fetch the tags
  for my $key (qw{title artist album tracknumber genre date}) {
    $result->{$key} = join(" ", $ogg->comment($key));   # returns a list?!
  }

  # And the other stuff we need to know.
  $result->{size}   = -s $filename;
  $result->{length} = $ogg->info('length') || 0;

  return $result;
}





# Extract the metadata from an MP3 file and return it as a hash.
# Tolerates the case where there are no ID3 tags--that gets handled by
# cleanTags.
sub handleMp3 {
  my ($filename) = @_;

  my $tags = get_mp3tag($filename) || {};

  # Merge multi-value tags.
  for my $key (keys %{$tags}) {
    if (ref($tags->{$key}) eq 'ARRAY') {
      $tags->{$key} = join(" ", @{$tags->{$key}});
    }
  }


  my $info = get_mp3info($filename)
    or return undef;

  my $result
    = {
       title        => $tags->{TITLE},
       artist       => $tags->{ARTIST},
       album        => $tags->{ALBUM},
       date         => $tags->{YEAR},
       genre        => $tags->{GENRE},
       tracknumber  => $tags->{TRACKNUM},

       size         => -s $filename,
       length       => int($info->{SECS}|| 0),
      };

  return $result;
}


1;
