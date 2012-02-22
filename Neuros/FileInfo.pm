# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Class to contain information about a specific audio file.

package Neuros::FileInfo;

use strict;
use warnings;

use Class::Std;
use Cwd 'abs_path';


{
  my %fullPath          :ATTR;                      # Absolute path to the file

  my %size              :ATTR;                      # Size in bytes
  my %date              :ATTR;                      # Age in seconds
  my %exists            :ATTR;                      # True if the file exists

  my %updated           :ATTR;                      # True if above were set

  sub BUILD {
    my ($self, $ident, $args) = @_;

    $fullPath{$ident}   = $args->{fullPath};
    $size{$ident}       = 0;
    $date{$ident}       = 0;
    $exists{$ident}     = 0;
    $updated{$ident}    = 0;

    return;
  }

  # Accessors
  sub fullPath {
    my ($self) = @_;
    return $fullPath{ident $self};
  }

  sub size {
    my ($self) = @_;

    # Sync if we don't currently have the value
    $self->update() unless $updated{ident $self};

    return $size{ident $self};
  }

  sub date {
    my ($self) = @_;

    # Sync if we don't currently have the value
    $self->update() unless $updated{ident $self};

    return $date{ident $self};
  }

  sub exists {
    my ($self) = @_;

    # Sync if we don't currently have the value
    $self->update() unless $updated{ident $self};

    return $exists{ident $self};
  }


  # Synchronize contents with the actual file.
  sub update {
    my ($self) = @_;

    $updated{ident $self} = 1;

    return unless -f $self->fullPath();

    $exists{ident $self} = 1;

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks)
      = stat($fullPath{ident $self});

    die "stat failed\n"     # sanity check
      unless defined($dev);

    $size{ident $self} = $size;
    $date{ident $self} = $mtime;

    return;
  }


} #End FileInfo



1;
