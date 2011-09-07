
package FBSite::Layout;

=head1 NAME

FBSite::Layout - simple module for header functions

=head1 SYNOPSIS

    use FBSite::Layout;

    $html = head("Home");
    print layout($html);

=head1 DESCRIPTION

Concat all your HTML onto a single variable called C<$html>.
Then, issue a single line at the bottom of your script as shown.
You can use C<head()> to create a canned heading in consistent style.
You should die() on errors as always.

=cut

use Carp;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $LAYOUT $FBSITE);

$VERSION = do { my @r=(q$Revision: 1.9 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };

use File::Basename;
BEGIN {
    $FBSITE = dirname(__FILE__) . "/../..";
    $LAYOUT = "$FBSITE/htdocs/layout";
}

# Place functions you want to export by default in the
# @EXPORT array. Any other functions can be requested
# explicitly if you place them in the @EXPORT_OK array.
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(head navbar layout layout_noads google_ad layout_header
             layout_footer layout_footer_noads cgihead $FBSITE);

# Begin module functions
sub head ($) {
    return join '', '<p class="label">', @_, "</p>\n";
}

sub navbar (@) {
    local $/;
    open(LN, "<$LAYOUT/leftnav_open.html");
    my $on = <LN>;
    close LN;

    open(CN, "<$LAYOUT/leftnav_close.html");
    my $cn = <CN>;
    close CN;

    return wantarray ? ($on, @_, $cn) : join('', $on, @_, $cn);
}

sub layout_header () {
    local $/;
    open H, "<$LAYOUT/header.html" or warn "Can't open $LAYOUT/header.html: $!";
    my $h = <H>;
    close H;
    return $h;
}

sub layout_footer () {
    local $/;
    open F, "<$LAYOUT/footer.html" or warn "Can't open $LAYOUT/footer.html: $!";
    my $f = <F>;
    close F;
    return $f;
}

sub layout_footer_noads () {
    local $/;
    open F, "<$LAYOUT/footer_noads.html" or warn "Can't open $LAYOUT/footer_noads.html: $!";
    my $f = <F>;
    close F;
    return $f;
}

sub cgihead () {
    return unless $ENV{REQUEST_METHOD};
    require CGI;
    return CGI::header();
}

sub layout (@) {
    my @html = (cgihead, layout_header, @_, layout_footer);
    return wantarray ? @html : join '', @html;
}

sub layout_noads {
    my @html = (cgihead, layout_header, @_, layout_footer_noads);
    return wantarray ? @html : join '', @html;
}

sub google_ad {
	open H, "<$LAYOUT/google.html" or warn "Can't open $LAYOUT/google.html: $!";
    my @html = <H>;
    close H;
    return wantarray ? @html : join '', @html;
}

# End of Perl code
1;

=head1 VERSION

$Id: Layout.pm,v 1.9 2005/05/10 00:32:29 nwiger Exp $

=head1 AUTHOR

Copyright (c) L<Nate Wiger|http://nateware.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
