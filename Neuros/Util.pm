# Copyright (C) 2008 Chris Reuter et. al. See Copyright.txt. GPL. No Warranty.

# This module contains general-purpose utility routines


package Neuros::Util;

use Exporter 'import';
our @EXPORT = qw {vsay asay wsay setVerbosity isVerbose slurp tokenize
                  uniqueKey listFiles};

use strict;
use warnings;


{
  my $verbose = 0;

  # Enable or disable verbosity via vsay
  sub setVerbosity {
    my ($enable) = @_;

    $verbose = $enable;

    return;
  }

  # Test verbosity
  sub isVerbose {$verbose}

  # Print the arguments to stdout IF AND ONLY IF verbosity has been
  # turned on via setVerbosity
  sub vsay (@) {
    asay(@_) if $verbose;

    return;
  }

  # Like vsay but ignores the verbosity flag.  For when you always
  # want to get your message out.
  sub asay (@) {
    print join (" ", @_, "\n");

    return;
  }

  # Issue a warning.  Like asay but prepends "WARNING:".
  sub wsay (@) {
    asay ("WARNING:", @_);

    return;
  }
}



# Read in the contents of $filename and return it as a single string.
sub slurp {
  my ($filename) = @_;

  open my $fh, "<", $filename
    or die "Unable to open '$filename' for reading.\n";

  local $/ = undef;
  my $result = <$fh>;

  close $fh;

  return $result;
}


# Given a string, split it into individual tokens and return the
# result as an array. Tokens are delimited by whitespace unless it has
# been escaped with a backslash ('\') or quoted with double quotes
# ('"').  Other escaped characters are just themselves, including
# backslash itself.  A trailing backslash is also implicitly escaped
# as a special case.
sub tokenize {
  my ($text) = @_;

  # Strip out comments.
  $text =~ s{^ \# .* $}{}gmx;

  # And also handle the case of a trailing backslash.
  $text =~ s{ ([^\\] \\) $}{$1\\}mx;

  # Tokenize
  my @result = ();
  while (1) {
    # Strip leading spaces
    $text =~ s/^\s*//;
    last unless $text;

    # If we're at a quoted sequence, match until the next unescaped
    # quote.
    if ($text =~ /^\"/) {
      $text =~ s{ \A \" ( ([^"\\] | \\ \")* ) \"}{}mx
        or die "Unterminated quote, started at '@{[substr($text,0,10)]}...'\n";
      push @result, $1;
      next;
    }

    # Otherwise, match until the next unescaped blank
    $text =~ s{ \A ( ([^[:space:]\\] | \\ .)* ) \s?}{}mx
      or die "Internal error: can't parse token.\n";
    push @result, $1;
  }

  # Strip out backslashes
  map { s/\\(.)/$1/g; } @result;

  # We're done
  return @result;
}


# Given a string $base, return a version of it that is not already a
# key in $hashRef by tacking numbers onto the end.
sub uniqueKey {
  my ($base, $hashRef) = @_;

  return $base unless exists($hashRef->{$base});

  my $extra = 2;

  # If it looks like $base was previously made unique with uniqueKey,
  # we try to increment instead of tacking on another number.
  # Presumably, this could occasionally lead to humorous album titles.
  $base =~ s/\ \[ (\d+) \] $//x
    and do {$extra = $1+1};

  while (exists($hashRef->{"$base [$extra]"})) {
    ++$extra;
  }

  return "$base [$extra]";
}



# Return the list of files in $path with extension $ext.
sub listFiles {
  my ($path, $ext) = @_;

  $path =~ s{/\z}{};	# Strip trailing '/'

  opendir my $dir, $path
	or die "Unable to open directory '$path' for reading.\n";
  my @files = readdir $dir;
  closedir $dir;

  @files = map { "$path/$_" } @files;
  @files = grep { m{\. $ext \z}gmx && -f $_ } @files;

  return @files;
}



# Teh ENB
1;
