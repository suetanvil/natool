
use warnings;
use diagnostics;

use Test::More tests => 6;

# CWD must be either the "t" directory or the toplevel runes project
# directory.
use File::Spec;

use Neuros::Asciify;

# Make warnings into errors:
$SIG{__WARN__} = sub { die @_ };

binmode STDOUT, ':utf8';

my $asc1 = "Hello, world";
is (toAscii($asc1), $asc1);
is (toAsciiFilename($asc1), $asc1);

my $asc2a = 'foo%bar';
my $asc2b = 'foo%25bar';
is (toAsciiFilename ($asc2a), $asc2b);

my $asc3 = "Hello, world\n";
my $asc3a = "Hello, world?";
is (toAscii ($asc3), $asc3a);

my $uc1a = 'Jøhnny Fävòrítê (it means "Sick-Cow Vibrato")';
my $uc1c = 'Johnny Favorite (it means "Sick-Cow Vibrato")';
my $uc1b = 'J%F8hnny F%E4v%F2r%EDt%EA (it means %22Sick-Cow Vibrato%22)';
is (toAsciiFilename ($uc1a), $uc1b);
is (toAscii ($uc1a), $uc1c);

