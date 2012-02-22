# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

#
# This module converts internationalized strings (e.g. Unicode, UTF8,
# etc.) into boring ASCII of the sort that a Neuros can use.
#
# Warning: this hasn't been tested very thoroughly, especially on
# non-European encodings.
#


package Neuros::Asciify;

use Exporter 'import';
our @EXPORT = qw {toAscii toAsciiFilename isValidNeurosPath};

use strict;
use warnings;
use English;

use Encode;
use Unicode::Normalize;



# Given a utf8 string, attempt to convert it into ASCII suitable for
# human consumption.  Note: there is no guarantee (or even likelyhood)
# that for a particular non-ASCII input string, the result will be
# unique.  DO NOT use this function to convert filenames.  Use
# toAsciiFilename instead.
sub toAscii {
  my ($string) = @_;

  # First, we attempt to strip accents off of accented characters.
  # Note that we use 's///' as a sort of character-wise 'map' here,
  # rather than splitting $string, calling map and then calling join
  # to reassemble it.
  $string =~ s/(.)/_removeAccent($1)/egs;

  # Now, we downcode it to ASCII
  $string = encode ("ascii", $string);

  # And explicitly remove any character that is not a printable ASCII
  # character.  This is *probably* redundant but bad characters can
  # crash the Neuros and I'm not entirely sure that 'encode' removes
  # every 'bad' character.
  $string =~ s/(.)/_downcode($1)/egs;

  return $string;
}



=begin comment

A brief explanation:

Unicode creates accented characters by composition, according some
document algorithm that is implemented by Unicode::Normalize.  This
means that there's a well-known way to convert, say, <a-with-accent>
to <a, accent>.

As it happens, Unicode::Normalize::NKFD just happens to do this for us.

So, we strip off the accent by running an accented character through
NKFD and just taking the first character of the resulting string.
Easy!

Of course, there are a few cases that don't work so we need to handle
them specially.

=cut

{

  # Latin-1 characters for which the decompose-and-snatch method
  # doesn't work:
  my %specialCases = (0xc6,   'AE', # Æ
                      0xd0,   'D',  # Ð
                      0xd7,   'x',  # ×
                      0xd8,   'O',  # Ø
                      0xde,   'P',  # Þ
                      0xdf,   'B',  # ß
                      0xe6,   'ae', # æ
                      0xf0,   'o',  # ð
                      0xf7,   '+',  # ÷
                      0xf8,   'o',  # ø
                      0xfe,   'p'); # þ

  # Attempt to strip off the accent from $char.  If this is not
  # possible, $char is returned unmodified.  See previous comment for a
  # more detailed description.
  sub _removeAccent {
    my ($char) = @_;

    # First, let's see $char is one of the special cases:
    my $special = $specialCases{ord($char)};
    return $special
      if defined($special);

    # Next, decompose $char into <base, accent> (if relevant).  We
    # quit if the decompsition did nothing.
    my $decomped = NFKD($char);
    return $char
      if ($decomped eq $char);

    # Now, strip of everything except the first character.
    $decomped =~ s/^(.).*$/$1/;

    # And bail if that first character isn't ASCII.
    return $char
      unless ($decomped =~ /^[[:ascii:]]+$/);

    return $decomped;
  }
}


# Given a character, if that character is an ASCII control character
# (below 0x20) or is not a printable 7-bit ASCII character, replaces
# it with '?'.  This reduces to keeping those characters between 0x20
# and 0x7e inclusive).
sub _downcode {
  my ($char) = @_;

  return '?' if (ord($char) < 0x20 or ord($char) > 0x7e);
  return $char;
}


=begin comment

Problem: the Neuros filesystem can't deal with non-ASCII filenames.
(Or maybe it can a little bit and I'm just being cautious.  It
*really* can't deal with full-blown Unicode, at any rate).

What Linux does when you try to copy a file is it converts non-ASCII
characters to '?'.  This is okay for what it is, but:

    1) We need to know what the destination name is in advance.

    2) We need to preserve uniqueness.

Consider (wrt 2), for example, if a directory contains "Ä.mp3" and
"À.mp3".  The resulting files will both be called "?.mp3" and one will
overwrite the other.  This is double-plus ungood.

So we need to make sure that if two local filenames are different,
then their Neuros equivalents are also different.  (Note that for the
previous example, toAscii() does the wrong thing as well.)

Being lazy, the easiest solution I can think of is just to treat the
name as a series of bytes and encode all non-printable characters in
some ASCII format.  I use %<hex-digit><hex-digit>, which is more or
less the standard form for URLs.

(Of course, this lengthens the filename so it could get truncated and
lose trailing characters which were what made it unambiguous, but that
(along with the whole case sensitivity issue) should be handled
elsewhere.

=cut


# Convert a (possibly) Unicode filename to an ASCII filename.
# Additionally, replace any characters that will likely cause a
# problem on the Neuros filesystem.
#
# Note: the conversion isn't particularly smart. All it does is write
# out the individual bytes, encoding the non-ASCII ones as percent
# sequences.  This has the problem of being tied to Perl's specific
# UTF8 implementation, which, er, probably won't change.
sub toAsciiFilename {
  my ($name) = @_;

  # Instead of downcoding this in any way, we just make perl treat
  # strings as sequences of bytes, no questions asked.
  use bytes;

  # Next, replace all '%' characters or all ASCII characters likely to
  # cause problems on a DOS filesystem with the %xx sequence for it.
  $name =~ s/ ([?<>:*^|\"\\%]) /_escape($1)/egmx;

  # Finally, replace all non-ASCII characters in $name with %xx
  # sequences.
  $name =~ s/ ([^[:ascii:]]) /_escape($1)/egmx;

  return $name;
}


# Detect if $path is a valid path for the master list (i.e. has no
# "special" characters.)
sub isValidNeurosPath {
  my ($path) = @_;

  # Strip off leading 'C:/' and any '%' characters so that
  # toAsciiFilename won't change those.
  $path = substr ($path, 2);
  $path =~ s/%/x/g;

  return $path eq toAsciiFilename($path);
}


# Given a character, return an escape sequence for it.
sub _escape {
  my ($char) = @_;

  return sprintf("%%%X", ord($char));
}
