
use warnings;
use diagnostics;

use Test::More tests => 19;
use File::Basename;

use Neuros::Util;

# Make warnings into errors:
$SIG{__WARN__} = sub { die @_ };

# Test tokenize
is_deeply([tokenize('foo bar quux')], [qw{foo bar quux}],
		  "Simple tokenization.");

is_deeply([tokenize("foo    bar\t\n quux\n\n")], [qw{foo bar quux}],
		  "Simple tokenization with wonky spaces.");

my $commentText = <<EOF;
# this is a comment
foo

#another comment bar
#xxx
 #bar quux


EOF
;
is_deeply([tokenize($commentText)], ['foo', '#bar', 'quux'],
		  "Simple tokenization with comments.");


# Test escaped spaces
is_deeply([tokenize('foo\\ bar quux')], ['foo bar', 'quux'],
		  "Escaped space.");

is_deeply([tokenize('foo\\ \\  bar quux')], ['foo  ', 'bar', 'quux'],
		  "Escaped trailing spaces.");

is_deeply([tokenize('f\\o\\o bar quux')], ['foo', 'bar', 'quux'],
		  "Escaped ordinary letters.");

is_deeply([tokenize('foo bar quux\\')], ['foo', 'bar', 'quux\\'],
		  "Trailing backslash.");

is_deeply([tokenize('\\foo bar quux\\')], ['foo', 'bar', 'quux\\'],
		  "Leading backslash.");

is_deeply([tokenize('\\\\foo bar quux\\')], ['\\foo', 'bar', 'quux\\'],
		  "Leading escaped backslash and trailing backslash.");

is_deeply([tokenize('foo bar quux\\ ')], ['foo', 'bar', 'quux '],
		  "Escaped trailing space.");

# Test quotes
is_deeply([tokenize('"foo bar" quux  ')], ['foo bar', 'quux'],
		  "Quoted sequence.");

is_deeply([tokenize('"foo" bar quux  ')], ['foo', 'bar', 'quux'],
		  "Quoted token.");

is_deeply([tokenize('" foo  " bar quux  ')], [' foo  ', 'bar', 'quux'],
		  "Quoted token containing leading and trailing spaces.");

is_deeply([tokenize('\\"foo  \\" bar quux  ')], ['"foo', '"', 'bar', 'quux'],
		  "Escaped quotes.");

is_deeply([tokenize('foo "bar \" x" quux  ')], ['foo', 'bar " x', 'quux'],
		  "Escaped quote within quoted token.");

is_deeply([tokenize("foo \" \t\n\n\t \" quux")], ['foo', " \t\n\n\t ", 'quux'],
		  "Newlines and tabs and no non-whitespace within quotes.");

# An unclosed quote is fatal, so testing for it is trickier.
eval {tokenize ('this is " an unclosed quote.')};
is ($@, "Unterminated quote, started at '\" an unclo...'\n",
	"Fatal error on unterminated quote.");


# Test listFiles
{
  my $path = dirname($0)."/dir_for_test/";
  my @files = listFiles ($path, "txt");
  is (scalar @files, 1);
  is ($files[0], "${path}testfile.txt");
}
