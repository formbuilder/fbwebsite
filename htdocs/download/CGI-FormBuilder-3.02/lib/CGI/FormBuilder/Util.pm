
package CGI::FormBuilder::Util;

=head1 NAME

CGI::FormBuilder::Util - Utility functions for FormBuilder

=head1 SYNOPSIS

    use CGI::FormBuilder::Util;

    belch "Badness";
    puke "Egads";
    debug 2, "Debug message for level 2";

=head1 DESCRIPTION

This module exports some common utility functions for B<FormBuilder>.
These functions are intended for internal use, however I must admit
that, from time to time, I just import this module and use some of
the routines directly (like C<htmltag()> to generate HTML).

=head1 USEFUL FUNCTIONS

These can be used directly and are somewhat useful. Don't tell anyone
I said that, though.

=cut

use strict;
use vars qw($VERSION @ISA @EXPORT $DEBUG @OURATTR %OURATTR);

# Don't "use" or it collides with our basename()
require File::Basename;

$VERSION = '3.02';

# Place functions you want to export by default in the
# @EXPORT array. Any other functions can be requested
# explicitly if you place them in the @EXPORT_OK array.
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(debug belch puke indent escapeurl escapehtml escapejs
             autodata optalign optsort optval cleanargs
             htmlattr htmltag toname tovar ismember basename);
$DEBUG = 0;

# To clean up the HTML, instead of just allowing the HTML tags that
# we interpret are "valid", instead we yank out all the options and
# stuff that we use internally. This allows arbitrary tags to be
# specified in the generation of HTML tags, and also means that this
# module doesn't go out of date when the HTML spec changes next week.
@OURATTR = qw(
    attr body checknum cleanopts columns cookies comment debug delete doctype
    errorname fields fieldattr fieldsubs fieldtype fieldopts font force growable growname
    header idprefix inputname invalid javascript jsname jsprefix jsfunc jshead keepextras
    label labels labelname lalign linebreaks messages nameopts other othername options
    override page pages pagename params render required reset resetname rowname
    selectnum sessionidname sessionid smartness sortopts static sticky stylesheet
    styleclass submit submitname submittedname table template title
    validate values
);

# trick for speedy lookup
%OURATTR = map { $_ => 1 } @OURATTR;

=head2 debug($level, $string)

This prints out the given string only if C<$DEBUG> is greater than
the C<$level> specified. For example:

    $CGI::FormBuilder::Util::DEBUG = 1;
    debug 1, "this is printed";
    debug 2, "but not this one";

A newline is automatically included, so don't provide one of your own.

=cut

sub debug ($;@) {
    return unless $DEBUG >= $_[0];  # first arg is debug level
    my $l = shift;  # using $_[0] directly above is just a little faster...
    my($func) = (caller(1))[3];
    warn "[$func] (debug$l) ", @_, "\n";
}

=head2 belch($string)

A modified C<warn> that prints out a better message with a newline added.

=cut

sub belch (@) {
    my $i=1;
    my($pkg,$file,$line,$func);
    while (my @stk = caller($i++)) {
        ($pkg,$file,$line,$func) = @stk;
    }
    warn "[$func] Warning: ", @_, " at $file line $line\n";
}

=head2 puke($string)

A modified C<die> that prints out a useful message.

=cut

sub puke (@) {
    my $i=1;
    my($pkg,$file,$line,$func);
    while (my @stk = caller($i++)) {
        ($pkg,$file,$line,$func) = @stk;
    }
    die "[$func] Fatal: ", @_, " at $file line $line\n";
}

=head2 escapeurl($string)

Returns a properly escaped string suitable for including in URL params.

=cut

sub escapeurl ($) {
    # minimalist, not 100% correct, URL escaping
    my $toencode = shift;
    $toencode =~ s!([^a-zA-Z0-9_,.-/])!sprintf("%%%02x",ord($1))!eg;
    return $toencode;
}

=head2 escapehtml($string)

Returns an HTML-escaped string suitable for embedding in HTML tags.
This dispatches to C<HTML::Entities::encode()> if available.

=cut

sub escapehtml ($) {
    my $toencode = shift;
    return '' unless defined $toencode;
    eval { require  HTML::Entities };
    if ($@) {
        # not found; use very basic built-in HTML escaping
        $toencode =~ s!&!&amp;!g;
        $toencode =~ s!<!&lt;!g;
        $toencode =~ s!>!&gt;!g;
        $toencode =~ s!"!&quot;!g;
        return $toencode;
    } else {
        # dispatch to HTML::Entities
        return HTML::Entities::encode($toencode);
    }
}

=head2 escapejs($string)

Returns a string suitable for including in JavaScript. Minimal processing.

=cut

sub escapejs ($) {
    my $toencode = shift;
    $toencode =~ s#'#\\'#g;
    return $toencode;
}

=head2 htmltag($name, %attr)

This generates an XHTML-compliant tag for the name C<$name> based on the
C<%attr> specified. For example:

    my $table = htmltag('table', cellpadding => 1, border => 0);

No routines are provided to close tags; you must manually print a closing
C<< </table> >> tag.

=cut

sub htmltag ($;@) {
    # called as htmltag('tagname', %attr)
    # creates an HTML tag on the fly, quick and dirty
    my $name = shift || return;
    my $attr = htmlattr($name, @_);     # ref return faster

    my $htag = join(' ', $name,
                  map { qq($_=") . escapehtml($attr->{$_}) . '"' } sort keys %$attr);

    $htag .= ' /' if $name eq 'input' || $name eq 'link';  # XHTML self-closing
    return '<' . $htag . '>';
}

=head2 htmlattr($name, %attr)

This cleans any internal B<FormBuilder> attributes from the specified tag.
It is automatically called by C<htmltag()>.

=cut

sub htmlattr ($;@) {
    # called as htmlattr('tagname', %attr)
    # returns valid HTML attr for that tag
    my $name = shift || return;
    my $attr = ref $_[0] ? $_[0] : { @_ };
    my %html;
    while (my($key,$val) = each %$attr) {
        # Anything but normal scalar data gets yanked
        next if ref $val || ! defined $val;

        # This cleans out all the internal junk kept in each data
        # element, returning everything else (for an html tag).
        # Crap, I used "text" here and body takes a text attr!!
        next if ($OURATTR{$key} || $key =~ /^_/
                                || ($key eq 'text'     && $name ne 'body')
                                || ($key eq 'multiple' && $name ne 'select')
                                || ($key eq 'type'     && $name eq 'select'));

        $html{$key} = $val;
    }
    # "double-name" fields with an id for easier DOM scripting
    # do not override explictly set id attributes
    $html{id} = $html{name} if exists $html{name} and not exists $html{id};

    return wantarray ? %html : \%html; 
}

=head2 toname($string)

This is responsible for the auto-naming functionality of B<FormBuilder>.
Since you know Perl, it's easiest to just show what it does:

    $name =~ s!\.\w+$!!;                # lose trailing ".suf"
    $name =~ s![^a-zA-Z0-9.-/]+! !g;    # strip non-alpha chars
    $name =~ s!\b(\w)!\u$1!g;           # convert _ to space/upper

This results in something like "cgi_script.pl" becoming "Cgi Script".

=cut

sub toname ($) {
    # creates a name from a var/file name (like file2name)
    my $name = shift;
    $name =~ s!\.\w+$!!;                # lose trailing ".suf"
    $name =~ s![^a-zA-Z0-9.-/]+! !g;    # strip non-alpha chars
    $name =~ s!\b(\w)!\u$1!g;           # convert _ to space/upper
    return $name;
}

=head2 tovar($string)

Turns a string into a variable name. Basically just strips C<\W>,
and prefixes "fb_" on the front of it.

=cut

sub tovar ($) {
    my $name = shift;
    $name =~ s#\W+#_#g;
    $name =~ tr/_//s;   # squish __ accidentally
    $name =~ s/_$//;    # trailing _ on "[Yo!]"
    return $name;
}

=head2 ismember($el, @array)

Returns true if C<$el> is in C<@array>

=cut

sub ismember ($@) {
    # returns 1 if is in set, undef otherwise
    # do so case-insensitively
    my $test = lc shift;
    for (@_) {
        return 1 if $test eq lc $_;
    }
    return;
}

=head1 USELESS FUNCTIONS

These are totally useless outside of B<FormBuilder> internals.

=head2 autodata($ref)

This dereferences C<$ref> and returns the underlying data. For example:

    %hash  = autodata($hashref);
    @array = autodata($arrayref);

=cut

sub autodata ($) {
    # auto-derefs appropriately
    my $data = shift;
    return unless defined $data;
    if (my $ref = ref $data) {
        if ($ref eq 'ARRAY') {
            return wantarray ? @{$data} : $data;
        } elsif ($ref eq 'HASH') {
            return wantarray ? %{$data} : $data;
        } else {
            puke "Sorry, can't handle odd data ref '$ref'";
        }
    }
    return $data;   # return as-is
}

=head2 cleanargs(@_)

This returns a hash of options passed into a sub:

    sub field {
        my $self = shift;
        my %opt  = cleanargs(@_);
    }

It does some minor sanity checks as well.

=cut

sub cleanargs (;@) {
    return $_[0] if ref $_[0];  # assume good data struct verbatim

    belch "Odd number of arguments passed into ", (caller(1))[3]
       if @_ % 2 != 0;

=for dummies_sorry_this_is_too_slow

    # strip off any leading '-opt' crap
    my @args;
    while (@_) {
        (my $k = shift) =~ s/^-//;
        push @args, $k, shift;
    }

=cut

    return wantarray ? @_ : { @_ };   # assume scalar hashref
}

=head2 indent($num)

A simple sub that returns 4 spaces x C<$num>. Used to indent code.

=cut

sub indent (;$) {
    # return proper spaces to indent x 4 (code prettification)
    return '    ' x shift();
}

=head2 optalign(\@opt)

This returns the options specified as an array of arrayrefs, which
is what B<FormBuilder> expects internally.

=cut

sub optalign ($) {
    # This creates and returns the options needed based
    # on an $opt array/hash shifted in
    my $opt = shift;

    # "options" are the options for our select list
    my @opt = ();
    if (my $ref = ref $opt) {
        if ($ref eq 'CODE') {
            # exec to get options
            $opt = &$opt;
        }
        # we turn any data into ( ['key', 'val'], ['key', 'val'] )
        # have to check sub-data too, hence why this gets a little nasty
        @opt = ($ref eq 'HASH')
                  ? map { [$_, $opt->{$_}] } keys %{$opt}
                  : map { (ref $_ eq 'HASH')  ? [ %{$_} ] : $_ } autodata $opt;
    } else {
        # this code should not be reached, but is here for safety
        @opt = ($opt);
    }

    return @opt;
}

=head2 optsort($sortref, @opt)

This sorts and returns the options based on C<$sortref>. It expects
C<@opt> to be in the format returned by C<optalign()>. The C<$sortref>
spec can be the string C<NAME>, C<NUM>, or a reference to a C<&sub>
which takes pairs of values to compare.

=cut

sub optsort ($@) {
    # pass in the sort and ref to opts
    my $sort = shift;
    my @opt  = @_;

    debug 2, "optsort($sort) called for field";

    # Currently we can only sort on the value, which sucks if the value
    # and label are substantially different. This is caused by the fact
    # that options as specified by the user only have one element, not two
    # as hashes or generated options do. This should really be an option,
    # since sometimes you want the values sorted too. Patches welcome.
    if ($sort eq 'alpha' || $sort eq 'name' || $sort eq 'NAME' || $sort eq 1) {
        @opt = sort { (autodata($a))[0] cmp (autodata($b))[0] } @opt;
    } elsif ($sort eq 'numeric' || $sort eq 'num' || $sort eq 'NUM') {
        @opt = sort { (autodata($a))[0] <=> (autodata($b))[0] } @opt;
    } elsif (ref $sort eq 'CODE') {
        @opt = sort { eval &{$sort}((autodata($a))[0], (autodata($b))[0]) } @opt;
    } else {
        puke "Unsupported sort type '$sort' specified - must be 'NAME' or 'NUM'";
    }

    # return our options
    return @opt;
}

=head2 optval($opt)

This takes one of the elements of C<@opt> and returns it split up.
Useless outside of B<FormBuilder>.

=cut

sub optval ($) {
    my $opt = shift;
    my($o,$n,$a) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
    return wantarray ? ($o,$n,$a) : $o;
}

=head2 basename

Returns the script name or $0 hacked up to the first dir

=cut

sub basename () {
    # Windows sucks so bad it's amazing to me.
    my $prog = File::Basename::basename($ENV{SCRIPT_NAME} || $0);
    $prog =~ s/\?.*//;     # lose ?p=v
    belch "Script basename() undefined somehow" unless $prog;
    return $prog;
}

1;
__END__

=head1 SEE ALSO

L<CGI::FormBuilder>

=head1 REVISION

$Id: Util.pm,v 1.26 2005/04/06 18:46:32 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut