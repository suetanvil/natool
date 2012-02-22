# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This package parses the command-line arguments using Getopt::Long.
# It's trickier than just using that, however, because it first splits
# the command-line into sub-commands with parameters and arguments and
# then invokes Getopt::Long::GetOptions on each of them.


package Neuros::CommandLine;

use Exporter 'import';
@EXPORT = qw{ParseCommandLine};

use strict;
use warnings;

use Getopt::Long;

use Neuros::Main;
use Neuros::SimpleCmd;
use Neuros::DirSync;
use Neuros::Scan;
use Neuros::PlaylistCmd;
use Neuros::Util;



my %optsForCmd =
  (''       => ["natool options:",
                'neuros-path=s',    "Path to Neuros' mount point.",
                'no-check',         "Skip sanity checks on Neuros path.",
                'alt-ml-dir=s',     "Read master list from given dir.",
                'verbose',          "Enable verbose messages.",
                'args=s',           "Specify a file to read extra args from.",
                'help',             "Print this message. Can appear anywhere.",
                'version',          "Print the version information and quit.",
               ],

   dirsync  => ["Synchronize local audio dir. with Neuros audio dir.",
                'fake',             "Do nothing; print actions to perform.",
                'cleanup',          "Delete orphaned files.",
                'adopt',            "Copy orphaned files to source directory.",
                'no-update',        "Do not update the master list.",
               ],
   convert  => ["Print the 'laundered' version of a filename.",
                'no-newline',       "Do not print a newline after the file(s).",
                'basename',         "Strip off leading directory path.",
               ],
   dbsync   => ["Write out the master list as the Neuros file database.",
               ],
   install  => ["Copy one or more files onto the Neuros.",
                'no-update',        "Do not update the master list.",
               ],
   remove   => ["Remove files from the master list and maybe delete them.",
                'keep',             "Don't delete the file, just the entry.",
               ],
   scan     => ["Create a new master list from the files on the Neuros.",
                'full',             "Recreate the entire master list.",
               ],
   rmpl     => ["Delete the named playlist."
               ],
   addpl    => ["Add one or more files to a playlist.",
               ],
   lspl     => ["List named playlists (or all if none given).",
                'contents',         "Print out contents as well.",
               ],
   lsartists=> ["List given artists (or all) plus related data.",
                'albums',           "Also print out the artists' albums.",
                'files',            "Print filenames for each album.",
                'titles',           "Print out song titles instead."
               ],
   drop     => ["Immediately discard the master list from RAM.",
               ],
   save     => ["Immediately save the master list currently in RAM.",
               ],
   fix      => ["Attempt to clean up the master list.",
                'dumb-artist-sort', "Sort artists strictly lexically.",
                'smart-artist-sort',"Sort artists in a friendlier way.",
                'count-sort:i',     "Split artist list by track count.",
                'album-artist',     "Ensure albums are unique to artists.",
                'album-artist-dir', "Like above but unique to dir.",
               ],


  );

my %subsForCmd =
  (dirsync  => \&Neuros::DirSync::Go,
   convert  => \&Neuros::SimpleCmd::ConvertPath,
   dbsync   => \&Neuros::SimpleCmd::WriteNeurosDb,
   install  => \&Neuros::SimpleCmd::InstallFile,
   scan     => \&Neuros::Scan::ScanForFiles,
   remove   => \&Neuros::SimpleCmd::RemoveFile,
   rmpl     => \&Neuros::PlaylistCmd::RemovePlaylist,
   addpl    => \&Neuros::PlaylistCmd::AddToPlaylist,
   lspl     => \&Neuros::PlaylistCmd::ListPlaylists,
   lsartists=> \&Neuros::SimpleCmd::ListTracks,
   drop     => \&Neuros::SimpleCmd::DropCmd,
   save     => \&Neuros::SimpleCmd::SaveCmd,
   fix      => \&Neuros::SimpleCmd::FixCmd,
  );




# Parse the argument list.  Result is a list.  The first entry is the
# hash of global arguments and the rest are array ref's containing a
# command name and and arg hash.
sub ParseCommandLine {
  my @commands = ();

  my @args = processEarlyOpts(@ARGV);

  my @sections = splitSubSections(@args);

  my $mainArgs = parseMainArgs (shift @sections);
  push @commands, [undef, $mainArgs];

  for my $section (@sections) {
    my $cmdName = shift @{$section};

    my $command = $subsForCmd{$cmdName};
    my $options = parseAndExtractOptions($cmdName, $section);

    push @commands, [$command, $options, @{$section}];
  }

  return @commands;
}


# Go through @args and handle those flags that need to be handled
# early.  Specifically, --args and --help are handled here.  We do
# --args because the presence of that flag changes the arg list while
# --help results in an immediate exit.  Returns a new argument list.
sub processEarlyOpts {
  my (@args) = @_;

  die "Execting arguments.  Try running with '--help' for a list.\n"
    unless @args;

  my @newArgs = ();

  while (@args) {
    my $arg = shift @args;

    printHelpMessage()
      if ($arg eq '--help');

    printVersion()
      if ($arg eq '--version');

    if ($arg eq '--args') {
      my $argFile = shift @args
        or die "No argument file for '--args'.\n";
      push @newArgs, tokenize (slurp ($argFile));
      next;
    }

    push @newArgs, $arg;
  }

  return @newArgs;
}


# Parse the arguments (if any) given to the main natool program, as
# opposed to a subcommand.
sub parseMainArgs {
  my ($sectionsRef) = @_;

  my $resultRef = parseAndExtractOptions('', $sectionsRef);

  # There should be no non-option parameters here.
  die "Invalid argument: '@{[shift @{$sectionsRef}]}'\n"
    if scalar @{$sectionsRef};

  return $resultRef;
}


# Split up a copy of argument array @args into a bunch of arrays, each
# containing a subcommand followed by its arguments.  (Well, except
# for the first, which is the list of commands that go to the program
# itself.).
sub splitSubSections {
  my (@args) = @_;

  my @sections = ();
  my @currSection = ();

  for my $arg (@args) {
    if ($arg && defined($optsForCmd{$arg})) {
      push @sections, [@currSection];
      @currSection = ($arg);
    } else {
      push @currSection, $arg;
    }
  }

  push @sections, \@currSection
    unless scalar @currSection == 0;

  return @sections;
}


# Parse the command-line of a subcommand.  Returns the options in a
# hash and the remaining arguments stay in @{$sectionRef}.
sub parseAndExtractOptions {
  my ($cmdName, $sectionRef) = @_;

  local @ARGV = @{$sectionRef};
  my $optValsRef = {};

  my $section = $cmdName ? "'$cmdName' section" : "command";
  GetOptions ($optValsRef, getOptsForCmd($cmdName))
    or die "Invalid $section option.\n";

  # Store the leftover arguments
  @{$sectionRef} = @ARGV;

  # And return the hash o' flags
  return $optValsRef;
}


# Return the list of options in Getopt::Long form for the command
# named $cmd.
sub getOptsForCmd {
  my ($cmd) = @_;

  my @cmds = @{ $optsForCmd{$cmd} };
  shift @cmds;      # Strip off description string.

  # Strip out the documentation strings.
  my @result;
  while (my $opt = shift @cmds) {
    push @result, $opt;
    shift @cmds;
  }

  return @result;
}



# Print the help message and exit.
sub printHelpMessage {

  print <<EOF;
usage: natool [OPTIONS] [SUBCOMMAND] [SUB-OPTIONS] [ARGUMENTS] ...

Adds or removes files from a Neuros 2[tm] digital audio player and/or
updates the audio database.

EOF
;

  for my $k (sort (keys %optsForCmd)) {
    printf "%-26s -- ", "Subcommand '$k'"
      if $k;

    my @opts = @{$optsForCmd{$k}};

    my $cmdDesc = shift (@opts);
    print "$cmdDesc\n";

    while (@opts) {
      my $opt = shift @opts;
      my $desc = shift @opts;

      $opt =~ s/\=.*/ <arg>/;
      $opt =~ s/\:.*/ ?<arg>?/;
      printf "    --%-24s%s\n", $opt, $desc;
    }

    print "\n";
  }

  printDisclaimer();

  exit (0);
}



sub printVersion {
  my $version = Neuros::Main::VERSION();

  print <<"EOF";
natool version $version

Copyright (C) 1998-2008 Chris Reuter and others.  See the file
"Copyright.txt" for details.

EOF
  printDisclaimer();

  exit(0);
}

# Print a disclaimer message.
sub printDisclaimer {

  print <<EOF;
This program is Free Software under the terms of the GNU General
Public License.

There is NO WARRANTY, to the extent permitted by law.  You use this
program entirely at your OWN RISK.

This program is neither created nor endorsed by Neuros Audio, LLC or
any of its affiliates.  You use it at your own risk.  "Neuros" is a
trademark of Neuros audio.
EOF

  return;
}


1;
