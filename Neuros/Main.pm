# Copyright (C) 2008, 2012 Chris Reuter et. al. GPL. No Warranty.
# See Copyright.txt for details.

#
# This module is the main driver for the natools program.  It
# processes subcommands and arguments and invokes them.
#

package Neuros::Main;

use strict;
use warnings;

use Neuros::CommandLine;
use Neuros::FileUtil;
use Neuros::Util;
use Neuros::AudioInfo;
use Neuros::State;

use constant VERSION => '1.00.02';


sub Go {
  my (@cmds) = ParseCommandLine();
  my $mainArgs = (shift @cmds)->[1];

  # Set verbosity if requested
  setVerbosity(1) if $mainArgs->{verbose};

  SetToplevelArgs ($mainArgs);

  for my $cmd (@cmds) {
    my ($cmdFun, $cmdFlags, @cmdArgs) = @{$cmd};

    $cmdFun->($cmdFlags, @cmdArgs);
  }

  # Save the database if necessary
  WriteAudio();

  return;
}


1;
