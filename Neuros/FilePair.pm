# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Class to hold information about a local audio file and its matching
# file on the Neuros.

package Neuros::FilePair;

use strict;
use warnings;

use Class::Std;

use Neuros::FileUtil;
use Neuros::FileInfo;


{
  my %pcFile            :ATTR;
  my %neurosFile        :ATTR;

  sub BUILD {
    my ($self, $ident, $args) = @_;

    my $relPath             = $args->{relPath};
    my $neurosRoot          = $args->{neurosRoot};
    my $pcRoot              = $args->{pcRoot};

    $pcFile{ident $self}    = $self->_mkNode("$pcRoot/$relPath");

    my $nfile = UnixPathToNeuros ($relPath);
    $neurosFile{ident $self} = $self->_mkNode("$neurosRoot/$nfile");

    return;
  }

  sub _mkNode {
    my ($self, $path) = @_;

    $path = $self->_cleanPath($path);
    return Neuros::FileInfo->new({fullPath  => $path});
  }


  sub _cleanPath {
    my ($self, $path) = @_;

    $path =~ s{\\}{/}gmx;
    $path =~ s{/+}{/}gmx;

    return $path;
  }

  # Synchronize items with information on the disk
  sub update {
    my ($self) = @_;

    $pcFile{ident $self}->update();
    $neurosFile{ident $self}->update();

    return;
  }

  sub pcPath {
    my ($self) = @_;

    return $pcFile{ident $self}->fullPath();
  }

  sub neurosPath {
    my ($self) = @_;

    return $neurosFile{ident $self}->fullPath();
  }

  # Return TRUE if the version on the PC should be copied to the
  # Neuros.  (I.e. it isn't on the Neuros or has been updated in some
  # notable way.)  This assumes that the version on the PC is the One
  # True Version.
  sub neurosNeedsUpdate {
    my ($self) = @_;

    # Copy if not on the Neuros
    return 1 if !$neurosFile{ident $self}->exists();

    # Copy if it looks like the PC-side version is different.  Since
    # reading the whole thing over a USB cable is slow, we make a
    # guess here.  Actually, two.

    # First, we check for missing files.
    return 0 unless -f $self->pcPath();

    # Next, we check for a difference in sizes.  That's the giveaway.
    return 1
      unless -s $self->neurosPath() == -s $self->pcPath();

    # Finally, we overwrite if the PC version is newer than the Neuros
    # version. (We add 5 as a fudge factor, since the Neuros
    # filesystem tends to round the time up or down.)
    return 1
      if $pcFile{ident $self}->date() > $neurosFile{ident $self}->date() + 5;

    # Otherwise, we assume they're the same.
    return 0;
  }

  # Return TRUE if $self exists on the Neuros only.
  sub onNeurosOnly {
    my ($self) = @_;

    return
      ($neurosFile{ident $self}->exists() && !$pcFile{ident $self}->exists());
  }


} #End FilePair


1;
