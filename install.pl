#!/bin/env perl

# Run this program to install 'natool' on your system.  Run with
# '--help' for instructions.

use strict;
use warnings;

use English;
use Getopt::Long;
use File::Path;
use File::Copy;
use File::Basename;
use Cwd;

#
# Flags and Arguments:
#

# This is the default installation location.  You can modify this or
# just use the --prefix option.
my $prefix = '/usr/local/';

# This is the path to the Perl interpreter to use for the program
# being installed.  You can change this or override it with the --perl
# option but you probably won't need to.
my $perl = $EXECUTABLE_NAME;

# If true, perform a dry run instead of installing the files.
my $fake = '';

# If true, keeps intermediate files instead of deleting them.
my $keep = '';

# If true, skip the regression test
my $skipTests = 0;

# If true, print a help message.
my $help = '';

# Version string, taken from file 'VERSION'.
my $version;

# Go:
init_install();

print "Doing sanity checks.\n";
sanity_checks();

print "\n\nCreating files.\n";
make_docs();
make_main();

print "\n\nInstalling files to '$prefix'.\n";
install_code();
install_other();

print "\n\nDeleting temp files:\n";
cleanup();

exit(0);


###########################################################################



# Fetch arguments, handling --help if necessary.
sub init_install {

  # Get command-line arguments.
  GetOptions ('prefix=s'        => \$prefix,
              'fake'            => \$fake,
              'perl'            => \$perl,
              'keep-temp',      => \$keep,
              'skip-test',      => \$skipTests,
              'help'            => \$help)
    or die "Invalid option.  Try running with '--help'.\n";

  # Handle --help now:
  if ($help) {
    print <<'EOF';
perl install.pl [OPTION]

This script installs 'natool'.

Options:
    --prefix=<path>        -- Installation prefix path (default: '/usr/local/')
    --fake                 -- Do nothing, just print what it would do.
    --perl=<path-to-perl>  -- Path to alternate Perl interpreter to use.
    --keep-temp            -- If given, do not delete local temp files.
    --skip-test            -- If given, do not run tests before installing.
    --help                 -- Print this message.
EOF
    ;
    exit 0;
  }

  # Get the version number
  $version = `cat VERSION`;
  chomp $version;
  $version
    or die "Unable to read file 'VERSION'.\n";
}


# Do sanity checks.
sub sanity_checks {

  # First, check the prefix to make sure we can install.
  die "Prefix directory '$prefix' does not exist or is not a directory.\n"
    unless -d $prefix;

  unless (-r $prefix && -w $prefix && -x $prefix) {
    my $msg = "You don't have access permission to access '$prefix'.\n";
    die $msg unless $fake;

    # If this is a fake, we only warn the user.
    print "WARNING WARNING WARNING: $msg";
    print "Continuing on the assumption that you'll do the actual ";
    print "install as root.\n\n\n ";
  }

  die "Prefix must be an absolute path.\n"
    unless ($prefix =~ m'^/');

  # Next, make sure we're in the directory created by the unzipped tarball.
  die "Current directory must have the contents of the installation tarball.\n"
    unless (-d 'bin' && -d 'CPAN' && -f 'install.pl' &&
            -d 'Neuros' && -d 'regression_tests');

  # Now, run the regression test
  if ($skipTests) {
    print "Skipping regression tests.  Compatibility is unverified.\n";
  } else {
    print "Running regression test...\n";
    cd ("regression_tests");
    run ("sh test.sh");
    cd ("..");
  }

  # If we got here, the test passed.
}


# Generate all documentation
sub make_docs {
  print "Creating man page...\n";
  run ("pod2man natool.1.pod > natool.1");
}


# Create and return the initial perl snippet that starts everything.
# This has the path to the installed app hardcoded, which is why we
# generate it here instead of just copying over bin/natool.
sub make_main {

  my $libdir = libdir();
  my $entryModule = 'Neuros::Main';
  my $entryFunction = 'Neuros::Main::Go()';

  my $script = <<"EOF";
#!$perl

BEGIN {
  unshift \@INC, '$libdir';
  unshift \@INC, '$libdir/CPAN';
}

use strict;
use warnings;

use $entryModule;

$entryFunction;
EOF
;

  save ("natool", 0755, $script);
}



# Actually install the necessary files to $prefix/lib and $prefix/bin
sub install_code {
  my @src = qw {CPAN/Ogg/Vorbis/Header/PurePerl.pm
                CPAN/README.txt
                CPAN/MP3/Info.pm
                CPAN/Class/Std.pm
                Neuros/FileInfo.pm
                Neuros/PlaylistCmd.pm
                Neuros/FileSet.pm
                Neuros/UnusedDb.pm
                Neuros/AudioInfo.pm
                Neuros/AlbumRenameList.pm
                Neuros/FileUtil.pm
                Neuros/Main.pm
                Neuros/SimpleCmd.pm
                Neuros/CommandLine.pm
                Neuros/Util.pm
                Neuros/NdbWriter.pm
                Neuros/Scan.pm
                Neuros/BinFileWriter.pm
                Neuros/DirSync.pm
                Neuros/FilePair.pm
                Neuros/MetaData.pm
                Neuros/Asciify.pm
                Neuros/State.pm};

  install (\@src, 0644, libdir());
  install (['natool'], 0755, "$prefix/bin");
}

# Install anything that isn't actual code.
sub install_other {
  install ([qw{Copyright.txt LICENSE.GPL}], 0644, libdir());
  install (['natool.1'], 0644, "$prefix/share/man/man1");
}


# Delete intermediate files.
sub cleanup {
  for my $trash (qw {natool.1 natool}) {
    next unless -f $trash;

    my $del = $keep ? "KEEPING" : "Deleting";

    print "$del temporary file '$trash'.\n";
    next if $keep;  # Don't delete if --keep-temps was given

    unlink($trash);
  }
}


###########################################################################
# Utilities
###########################################################################


# Create a directory unless $fake is set.
sub md {
  my ($path) = @_;

  print "Creating directory: '$path'\n";
  return if $fake;

  mkpath ($path, 1, 0755);
}


# Chdir, dying on failure.
sub cd {
  my ($path) = @_;

  chdir ($path)
    or die "Unable to chdir to '$path'\n";
}


# Write out a string to the given filename
sub save {
  my ($filename, $perms, @lines) = @_;

  print "Creating $filename...\n";
  return if $fake;

  open OUTPUT, ">$filename"
    or die "Unable to open '$filename' for writing.\n";

  for my $l (@lines) {
    print OUTPUT $l;
  }

  close OUTPUT;

  chmod $perms, $filename
    or die "Unable to change permissions of $filename.\n";
}


# Copy the source files into a destination directory
sub install  {
  my ($filesRef, $perm, $destDir) = @_;

  # Ensure that $destDir exists
  mkpath ([$destDir], 1, 0755);

  # Create destination directories.  First, pull them from $filesRef
  my @dirs = map { dirname($_) } @{$filesRef};

  # Next, get rid of dupes and "."
  my %uniqueDirs = map { $_ => 1} @dirs;
  delete $uniqueDirs{"."};
  @dirs = keys %uniqueDirs;

  # Now, make them subdir's of the install dir.
  @dirs = map { "$destDir/$_" } @dirs;

  # And create the directories
  mkpath ([@dirs], 1, 0755)
    unless $fake;

  print "Would have created '@dirs'\n"
    if $fake && scalar @dirs;

  # Now, copy the files.
  foreach my $src (@{$filesRef}) {
    my $dest = "$destDir/$src";

    # Strip out repeated slashes.
    for ($src, $dest) {
      s{/+}{/}g;
    }

    print "Copying '$src' to '$dest'\n";
    next if $fake;

    copy ($src, $dest)
      or die "Error copying $src to $dest.\n";
    chmod $perm, $dest
      or die "Unable to change permissions of '$dest'\n";
  }
}


# Execute the given string and die with an error message if it fails.
sub run ( $ ) {
  my $cmd = shift;
  my $stat = system ($cmd);
  die "Unable to execute command: '$cmd'\n"
    unless $stat == 0;
}


# Compute the lib directory path.
sub libdir {
  my $result = "$prefix/share/natool-$version/";
  $result =~ s{/+}{/}g;
  $result =~ s{/$}{};

  return $result;
}


