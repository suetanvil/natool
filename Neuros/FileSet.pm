# Copyright (C) 2014 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# Instances hold a collection of file pairs representing the status of
# the source and destination directory trees.

package Neuros::FileSet;

use strict;
use warnings;

use Class::Std;
use File::Find;
use File::Spec;
use Cwd 'abs_path';

use Neuros::FilePair;
use Neuros::FileUtil;
use Neuros::Util;

{
  my %neurosRoot        :ATTR(:get<neurosRoot>);# Neuros music directory.
  my %pcRoot            :ATTR(:get<pcRoot>);    # PC side music directory.
  my %pairsHash_ref     :ATTR;  # Hash of pairs, keyed by relative paths
  my %longNamesHash_ref :ATTR;  # Hash of lower-cased absolute Neuros-side
                                #   names->PC-side names

  sub BUILD {
    my ($self, $ident, $args) = @_;

    $neurosRoot{$ident} = $args->{neurosRoot};
    $pcRoot{$ident}     = $args->{pcRoot};

    $pairsHash_ref{$ident}  = {};

    return;
  }


  # Test if (relative) Neuros file $neurosRelPath has a corresponding
  # file on the PC (that this FileSet knows about).
  sub hasPcFileFor {
    my ($self, $neurosRelPath) = @_;

    my $fullPath = lc("$neurosRoot{ident $self}/$neurosRelPath");
    my $pcName = $longNamesHash_ref{ident $self}->{$fullPath};

    return !!$pcName;
  }

  # Add $node to $longNamesHash_ref, the hash mapping Neuros-side
  # names to PC-side names.
  sub _addToLongNamesHash {
    my ($self, $node) = @_;

    my $pcPath = $node->pcPath();

    # Catch the case where to different files on the PC side have the
    # same path and name on the Neuros.
    my $key = lc($node->neurosPath());
    my $oldValue = $longNamesHash_ref{ident $self}->{$key};
    die "Files '$pcPath' and '$oldValue' would overwrite each other "
      . "if copied to the Neuros.\n"
        if (defined($oldValue) && $oldValue ne $pcPath);

    # Otherwise, store the file.
    $longNamesHash_ref{ident $self}->{$key} = $pcPath;

    return;
  }

  # Add a file on the PC.  If $isNeurosFs is true, treat it as a file
  # on the Neuros and don't add it if this FileSet already knows about
  # the matching PC-side file.
  sub _addFile {
    my ($self, $relPath, $isNeurosFs) = @_;

    my $node = Neuros::FilePair->new({relPath   => $relPath,
                                      neurosRoot=> $neurosRoot{ident $self},
                                      pcRoot    => $pcRoot{ident $self}});
    $node->update();

    return
      if ($isNeurosFs && $self->hasPcFileFor ($relPath));


    $pairsHash_ref{ident $self}->{$relPath} = $node;

    $self->_addToLongNamesHash($node);

    return;
  }


  # Search the disk for files to load.  If $searchNeuros is true, also
  # search the neuros' drive for files but only add them if they're
  # not already on the PC side.
  sub fillFromDisk {
    my ($self, $searchNeuros) = @_;

    $self->_fill($pcRoot{ident $self},      sub {$self->_addFile(shift, 0)} );

    $self->_fill($neurosRoot{ident $self},  sub {$self->_addFile(shift, 1)} )
      if $searchNeuros;

    return;
  }


  # Search subdirectory at $root for audio files and perform function
  # $action on the complete path (relative to $root).
  sub _fill {
    my ($self, $root, $action) = @_;

    vsay "Scanning '$root'";

    my $wanted =
      sub {
        return unless -f;
        return unless IsAudioFile($_);

        my $relPath = $File::Find::name;
        $relPath =~ s{^$root/*}{};

        $action->($relPath);
      };

    find({wanted => $wanted, follow => 1}, $root);

    return;
  }


  # Print out all files this FileSet knows about.
  sub printKnown {
    my ($self) = @_;

    for my $paths ( values %{$pairsHash_ref{ident $self}} ) {
      print $paths->pcPath(), " -> ", $paths->neurosPath(), "\n";
    }

    return;
  }

  # Return a reference to the list of files that need to be installed
  # onto the Neuros.
  sub installList {
    my ($self) = @_;

    my @result = grep { $_->neurosNeedsUpdate() }
      values (%{$pairsHash_ref{ident $self}});

    @result = map { [$_->pcPath(), $_->neurosPath()] } @result;

    @result = sort { $a->[0] cmp $b->[0] } @result;

    return \@result;
  }

  # Return list of files that are only on the Neuros
  sub orphanedList {
    my ($self) = @_;
    my @result = map { $_->neurosPath() }
      grep { $_->onNeurosOnly() } values (%{$pairsHash_ref{ident $self}});

    @result = sort @result;

    return \@result;
  }



} #End FileSet

1;
