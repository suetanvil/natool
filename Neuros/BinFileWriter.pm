# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Class to create a binary file in memory and then write it out to
# disk.  (Some code taken from Sorune by Darren Smith).

package Neuros::BinFileWriter;

use strict;
use warnings;

use Class::Std;

use File::Path;
use File::Basename;



{
  my %bufferRef         :ATTR;          # In-memory copy of the database


  sub BUILD {
    my ($self, $ident, $args) = @_;

    $self->reset();

    return;
  }


  # Clear the buffer
  sub reset {
    my ($self) = @_;

    my $t = "";
    $bufferRef{ident $self} = \$t;

    return;
  }

  # Return the buffer size in bytes.
  sub bsize {
    my ($self) = @_;

    return length (${$bufferRef{ident $self}});

    return;
  }

  # Return the buffer size in words.
  sub wsize {
    my ($self) = @_;

    die "Internal error: Odd size.\n"
      if $self->bsize() % 2;

    return int($self->bsize() / 2);
  }


  # Append a string.
  sub string {
    my ($self, $string) = @_;

    # Sanity check.  If this fails, it means we haven't successfully
    # filtered the non-ASCII strings out of the global AudioInfo.
    utf8::is_utf8($string)
        and die "Internal error: Unicode string used where bytes expected.\n";

    ${ $bufferRef{ident $self} } .= pack("A*", $string);
    $self->byte(0)
      if $self->bsize() % 2;
    $self->word(0);

    return;
  }

  # Append a display string
  sub display {
    my ($self, $string) = @_;

    my $length = length($string);
    my $offset = $self->bsize();

    $self->word(0);
    $self->string($string);

    my $offset2 = $self->bsize();
    $self->wordOverwrite($offset, ($offset2 - $offset) / 2 - 1);

    return;
  }

  sub byte {
    my ($self, @values) = @_;

    ${$bufferRef{ident $self}} .= pack("C*", @values);

    return;
  }

  sub word {
    my ($self, @values) = @_;

    ${$bufferRef{ident $self}} .= pack("n*", @values);

    return;
  }

  # Append one or more words.  If the word is a metacharacter, escape it.
  sub wordEscaped {
    my ($self, @values) = @_;

    for my $field (@values) {
      my $word = pack ("n", ($field));
      $word =~ s{^ \x00 ([\#%\$/]) $}{\x00/\x00$1}gmx;

      ${$bufferRef{ident $self}} .= $word;
    }

    return;
  }


  sub dword {
    my ($self, @values) = @_;

    ${$bufferRef{ident $self}} .= pack("N*", @values);

    return;
  }

  # Append one or more dwords, inserting escape characters before any
  # metacharacters.
  sub dwordEscaped {
    my ($self, @values) = @_;

    for my $field (@values) {
      $self->wordEscaped($field >> 16);
      $self->wordEscaped($field & 0xFFFF);
    }

    return;
  }


  # Append the magic number 'WOID'
  sub woid {
    my ($self) = @_;

    ${$bufferRef{ident $self}} .= 'WOID';
  }

  # Append a binary string to this buffer
  sub byteString {
    my ($self, $string) = @_;

    utf8::is_utf8($string)
        and die "Unicode string used where bytes expected.\n";

    ${$bufferRef{ident $self}} .= $string;

    return;
  }


  # Append a numeric (dword) record field consisting of one or more
  # subfields.  (Doesn't escape arguments because Sorune doesn't and
  # I'm trying to find out if that's a bug or not.)
  sub dwordField {
    my ($self, @subfields) = @_;

    # Sanity check
    scalar @subfields
      or die "Missing arguments.\n";

    my $last = pop @subfields;

    for my $subfield (@subfields) {
      $self->dwordEscaped($subfield);
      $self->subfieldDelim();
    }
    $self->dwordEscaped($last);
    $self->fieldDelim();

    return;
  }


  # Append a string field to $self.  (Doesn't take subfields, doesn't
  # need to escape because there are no nulls allowed in the master
  # list).  Appends delimiter.
  sub stringField {
    my ($self, $fieldText) = @_;

    $self->string($fieldText);      # Ditto about escape
    $self->fieldDelim();

    return;
  }


  # Append various delimiters
  sub subfieldDelim  {my ($self) = @_;  $self->word (0x24); return}
  sub fieldDelim     {my ($self) = @_;  $self->word (0x23); return}
  sub recordDelim    {my ($self) = @_;  $self->word (0x25); return}


  # Write words in @values at position $offset instead of appending
  # them to the end.
  sub wordOverwrite {
    my ($self, $offset, @values) = @_;

    my $bufRef = $bufferRef{ident $self};
    substr(${$bufRef}, $offset, 2 * scalar @values) = pack("n*", @values);

    return;
  }


  # Write dwords in @values at position $offset instead of appending
  # them to the end.
  sub dwordOverwrite {
    my ($self, $offset, @values) = @_;

    my $bufRef = $bufferRef{ident $self};
    substr(${$bufRef}, $offset, 4 * scalar @values) = pack ("N*", @values);

    return;
  }


  # Append a Neuros menu data structure
  sub createMenu {
    my ($self, @entries) = @_;
    my @offsets = ();

    # Create the table of menu string starting positions
    for my $entry (@entries) {
      push @offsets, $self->bsize();
      $self->dword(0);
    }

    while (scalar(@entries)) {
      my $name = shift @entries;
      my $filename = shift @entries;

      my $indexOffset = shift @offsets;
      my $menuOffset = int($self->bsize()/2);

      $self->dwordOverwrite ($indexOffset, $menuOffset);
      $self->display ($name);

      $indexOffset = shift @offsets;
      $menuOffset = int($self->bsize()/2);
      if ($filename ne "") {
        $self->dwordOverwrite ($indexOffset, $menuOffset);
        $self->string ($filename);
      }
    }

    return;
  }


  # Return a copy of the contents.  Currently used only for debugging.
  sub contents {
    my ($self) = @_;

    return ${ $bufferRef{ident $self} };
  }

  # Write contents to $file, creating intermediate directories if
  # needed.
  sub write {
    my ($self, $file) = @_;

    my $dir = dirname($file);
    my $bufRef = $bufferRef{ident $self};

    mkpath $dir, 0, 0700;

    open my $fh, ">", $file
      or die "Unable to open file '$file' for writing.\n";
    binmode $fh;

    my $length = length $$bufRef;
    my $chunksize = 1024 * 64;
    my $offset = 0;

    while ($length) {
      my $wlen = syswrite($fh, $$bufRef, $chunksize, $offset)
        or die "Error writing to '$file'\n";

      $offset += $wlen;
      $length -= $wlen;
    }

    close ($fh);        # Redundant but here for form.

    return;
  }

}

1;
