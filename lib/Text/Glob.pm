package Text::Glob;
use strict;
use Exporter;
use vars qw/$VERSION @ISA @EXPORT_OK
            $strict_leading_dot $strict_wildcard_slash $globstar/;
$VERSION = '0.11';
@ISA = 'Exporter';
@EXPORT_OK = qw( glob_to_regex glob_to_regex_string match_glob );

$globstar              = 0;
$strict_leading_dot    = 1;
$strict_wildcard_slash = 1;

use constant debug => 0;

sub glob_to_regex {
    my $glob = shift;
    my $regex = glob_to_regex_string($glob);
    return qr/^$regex$/;
}

sub glob_to_regex_string
{
    my $glob = shift;

    my $seperator = $Text::Glob::seperator;
    $seperator = "/" unless defined $seperator;
    $seperator = quotemeta($seperator);

    my ($regex, $in_curlies, $escaping);
    local $_;
    my $first_byte = 1;
    while ($glob =~ m/(.)/gs) {
        local $_ = $1;
        if ($first_byte) {
            if ($strict_leading_dot) {
                $regex .= '(?=[^\.])' unless $_ eq '.';
            }
            $first_byte = 0;
        }
        if ($_ eq '/') {
            $first_byte = 1;
        }
        if ($_ eq '.' || $_ eq '(' || $_ eq ')' || $_ eq '|' ||
            $_ eq '+' || $_ eq '^' || $_ eq '$' || $_ eq '@' || $_ eq '%' ) {
            $regex .= "\\$_";
        }
        elsif ($_ eq '*') {
            if ( $escaping ) {
                $regex .= '\\*';
            }
            else {
                my $more;
                if ( '*' eq substr $glob, pos $glob, 1 ) {
                    $more = 1;
                    pos $glob += 1;
                }
                $regex .= ( $strict_wildcard_slash && ! (
                    $globstar && $more ) ) ? "(?:(?!$seperator).)*" : '.*';
            }
        }
        elsif ($_ eq '?') {
            $regex .= $escaping ? "\\?" :
              $strict_wildcard_slash ? "(?!$seperator)." : ".";
        }
        elsif ($_ eq '{') {
            $regex .= $escaping ? "\\{" : "(";
            ++$in_curlies unless $escaping;
        }
        elsif ($_ eq '}' && $in_curlies) {
            $regex .= $escaping ? "}" : ")";
            --$in_curlies unless $escaping;
        }
        elsif ($_ eq ',' && $in_curlies) {
            $regex .= $escaping ? "," : "|";
        }
        elsif ($_ eq "\\") {
            if ($escaping) {
                $regex .= "\\\\";
                $escaping = 0;
            }
            else {
                $escaping = 1;
            }
            next;
        }
        else {
            $regex .= $_;
            $escaping = 0;
        }
        $escaping = 0;
    }
    print "# $glob $regex\n" if debug;

    return $regex;
}

sub match_glob {
    print "# ", join(', ', map { "'$_'" } @_), "\n" if debug;
    my $glob = shift;
    my $regex = glob_to_regex $glob;
    local $_;
    grep { $_ =~ $regex } @_;
}

1;
__END__

=head1 NAME

Text::Glob - match globbing patterns against text

=head1 SYNOPSIS

 use Text::Glob qw( match_glob glob_to_regex );

 print "matched\n" if match_glob( "foo.*", "foo.bar" );

 # prints foo.bar and foo.baz
 my $regex = glob_to_regex( "foo.*" );
 for ( qw( foo.bar foo.baz foo bar ) ) {
     print "matched: $_\n" if /$regex/;
 }

=head1 DESCRIPTION

Text::Glob implements glob(3) style matching that can be used to match
against text, rather than fetching names from a filesystem.  If you
want to do full file globbing use the File::Glob module instead.

=head2 Routines

=over

=item match_glob( $glob, @things_to_test )

Returns the list of things which match the glob from the source list.

=item glob_to_regex( $glob )

Returns a compiled regex which is the equivalent of the globbing
pattern.

=item glob_to_regex_string( $glob )

Returns a regex string which is the equivalent of the globbing
pattern.

=back

=head1 SYNTAX

The following metacharacters and rules are respected.

=over

=item C<*> - match zero or more characters

C<a*> matches C<a>, C<aa>, C<aaaa> and many many more.

=item C<?> - match exactly one character

C<a?> matches C<aa>, but not C<a>, or C<aaa>

=item Character sets/ranges

C<example.[ch]> matches C<example.c> and C<example.h>

C<demo.[a-c]> matches C<demo.a>, C<demo.b>, and C<demo.c>

=item alternation

C<example.{foo,bar,baz}> matches C<example.foo>, C<example.bar>, and
C<example.baz>

=item leading . must be explicitly matched

C<*.foo> does not match C<.bar.foo>.  For this you must either specify
the leading . in the glob pattern (C<.*.foo>), or set
C<$Text::Glob::strict_leading_dot> to a false value while compiling
the regex.

This setting also affects whether the C<$globstar> feature will match
intermediate directories that begin with '.'

=item C<*> and C<?> do not match the seperator (i.e. do not match C</>)

In the shell, "*" cannot match accross a directory separator, and you
must normally explicitly match the '/' with the pattern.  However some
tools like bash and rsync provide an alternate notation '**' for this
purpose.  This module gives you plain shell behavior by default, but
offers three workarounds:

=over

=item C<$Text::Glob::globstar>

Named after the Bash shell option, setting this to true enables bash-like
behavior.  Notice that it won't match hidden directories unless you also
unset C<$Text::Glob::strict_leading_dot>.  Also note that if '**' is
bounded by directory separators or the ends of a string, it can also match
zero directories.

=item C<$Text::Glob::strict_wildcard_slash>

Set this to false to allow '*' to match the directory separator.

=item C<$Text::Glob::seperator>

You can simply re-define the separator character if that is an appropriate
solution for your use case.

=back

Examples:

  Pattern     String             Match?
  *.foo       bar/baz.foo        no
  */*.foo     bar/baz.foo        yes
  **.foo      bar/baz.foo        no       # need to enabe globstar
  */*.foo     .config/baz.foo    no       # strict_leading_dot in effect
  
  # With globstar enabled:
  *.foo       bar/baz.foo        no
  **.foo      bar/baz.foo        yes
  **.foo      .config/baz.foo    no       # strict_leading_dot in effect
  **/README   foo/bar/README     yes
  **/README   README             yes

=back

=head1 BUGS

The code uses qr// to produce compiled regexes, therefore this module
requires perl version 5.005_03 or newer.

=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright (C) 2002, 2003, 2006, 2007 Richard Clamp.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<File::Glob>, glob(3)

=cut
