
use warnings;
use diagnostics;

use Test::More tests => 16;

use File::Basename;
use Cwd 'abs_path';

use Neuros::FileUtil;

# Make warnings into errors:
$SIG{__WARN__} = sub { die @_ };

#
# Tests for RelToNeuros
#
# We use the 't' directory as the Neuros directory because we know
# what's going to be in it.
#
{
  my $nr = abs_path(dirname($0));
  my $odir = abs_path("$nr/../../regression_tests/");

  # Test 1: missing file
  ok (!defined(RelToNeuros ("$odir/nothinghere.txt", $nr)),
	  "Undef on missing file.");

  # Test 2: present file
  is (RelToNeuros("$nr/fileutil.t", $nr), 'fileutil.t',
	  "Relative path to this file.");

  # Test 3: present subdirectory
  is (RelToNeuros("$nr/dir_for_test", $nr), 'dir_for_test',
	  "Relative path to subdirectory.");

  # Test 4: missing file in present directory.
  is (RelToNeuros("$nr/dir_for_test/missing", $nr), undef,
	  "Missing file in subdirectory.");

  # Test 5: present file in subdirectory
  my $relpath = 'dir_for_test/testfile.txt';
  is (RelToNeuros("$nr/dir_for_test/testfile.txt", $nr), $relpath,
	  "Present file in subdirectory.");

}

# And GetAudioExt, too.
is (GetAudioExt("foo.MP3"), 'mp3', "MP3 extension.");
is (GetAudioExt("foo.MP4"), undef, "Unsupported extension.");

# Tests for IsAudioFile
ok (IsAudioFile("foo.mp3"), "mp3 file");
ok (IsAudioFile("/mnt/home/baz/foo.MP3"), "MP3 file in subdir");
ok (!IsAudioFile("foo.mp4"), "unsupported format.");


# Tests for UnixPathToNeuros
is (UnixPathToNeuros("music/foo.mp3"), "music/foo.mp3", "Ordinary file.");
is (UnixPathToNeuros("music/foo.mp3..."), "music/foo.mp3", "Trailing dots.");
is (UnixPathToNeuros("fooü.mp3"), 'foo%C3%BC.mp3', "Non-ascii characters.");
is (UnixPathToNeuros('foo%.mp3'), 'foo%25.mp3', "Percent char.");
is (UnixPathToNeuros('foo%ü.mp3'), 'foo%25%C3%BC.mp3',
	"Percent, non-ascii char.");
is (UnixPathToNeuros(('a' x 300) . '/' . 'b' x 300),
	('a' x 254) . '/' . 'b' x 254,
	"Test that filenames are truncated to 254 characters.")
