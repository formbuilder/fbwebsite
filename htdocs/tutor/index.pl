#!/usr/bin/perl

# Copyright (c) 2003-2005 Nathan Wiger <nate@wiger.org>
#
# Simple tutorial runner, it looks for files in this
# directory named [0-9][0-9].html, where the first
# line in the file is the title of the step

use lib '../lib';
use strict;

use FBSite::Layout;

use CGI;
local $CGI::USE_PARAM_SEMICOLONS = 0;
my $cgi = new CGI;

my $base = "$ENV{DOCUMENT_ROOT}/tutor";

my $c = $cgi->param('c') || 1;
my $s = $cgi->param('s') || 1;
my $n = $cgi->script_name();
my $p = $cgi->param('p') ? '&p=1' : '';

# Topics, IN ORDER
# First element is '-' to index by 1 since I'm LAZY
my @t = qw(- basic intermediate advanced);

# Create a navbar with all the steps in it.
my @nav = ();

# my $step = step(5,1);
sub step ($$) {
    my $td = $_[1] ? $t[$_[1]] : $t[$c];
    return $_[0] =~ /[a-zA-Z]/
            ? "$base/$td/".uc($_[0]).'.html'
            : sprintf("$base/$td/%2.2d\.html", $_[0]);
}

my $tc = 1;
for my $to (@t) {
    next if $to eq '-';
    push @nav, head(ucfirst($to));
    opendir D, "$base/$to" or warn "Can't readdir $base/$to: $!";
    my @steps = sort grep /^[A-Z0-9]+\.html/, readdir D;
    closedir D;

    for my $st (@steps) {
        my($sn) = $st =~ /^0?(\w+)/;
        my $sl = $sn == 99 ? 'S' : $sn;
        open T, "<$base/$to/$st" or next;
        chomp(my $tt = <T>);
        close T; 
        push @nav, qq($sl. <a href="$n?c=$tc&s=$sn$p">$tt</a><br />\n);
    }
    $tc++;
}

# Open current step
my $step = step($s,$c);
open S, $step or warn "Can't read step $s: $!";
chomp(my $stit = <S>);
my $sdoc = join '', <S>;
close S;

# Parse our step doc a little, using pseudo-HTML, *not* POD

# Uniquely Perl chars
$sdoc =~ s/([^-])->/$1-&gt;/g;
$sdoc =~ s/=>/=&gt;/g;

# Step next and prev pointers appropriately
my $next = $s+1;
my $prev = $s-1;

# Init our html with this title
my $sl = $s == 99 ? 'S' : $s;
my $sx = $s eq 'S'? " Tutorial - $stit" : " Tutorial - Step $s: $stit";
my $ph = '';
if ($p) {
    # link to non-printable
    $cgi->param(-name => 'p', -value => 0, -override => 1); # mess with query
    $ph = ' <a href="'.$cgi->self_url().'">'
        . '<font size="1">Back</font></a>';
} else {
    # link to printable
    $cgi->param(-name => 'p', -value => 1, -override => 1); # mess with query
    $ph = ' <a href="'.$cgi->self_url().'"><img src="/images/printer.gif"'
        . ' width="13" height="12" border="0" align="middle" />'
        . '<font size="1">Print</font></a>';
}
my @h = head(ucfirst($t[$c]) . $sx . $ph);

# Get titles
my @steps;
if ($prev >= 1) {
    my $step = step($prev,$c);
    if (open(P, $step)) {
        chomp(my $ptit = <P>);
        close P;
        push @steps, qq(<a href="$n?c=$c&s=$prev$p"><font size="1">&lt;&lt;</font> $ptit</a>);
    } else {
        warn "Can't read $step: $!";
    }
}

# Next step at bottom
if ($s eq 'S') {
    my $step = step(1,++$c);
    if (open(N, $step)) {
        chomp(my $ntit = <N>);
        close N;
        push @steps, qq(<a href="$n?c=$c&s=$next$p">$ntit <font size="1">&gt;&gt;</font></a>);
    }
} elsif ($next > 1) {
    my $step = step($next,$c);
    if (open(N, $step)) {
        chomp(my $ntit = <N>);
        close N;
        push @steps, qq(<a href="$n?c=$c&s=$next$p">$ntit <font size="1">&gt;&gt;</font></a>);
    } elsif (open(N, step('S',$c))) {
        chomp(my $ntit = <N>);
        close N;
        push @steps, qq(<a href="$n?c=$c&s=S$p">$ntit <font size="1">&gt;&gt;</font></a>);
    }
}

# Current doc in middle
my $steps = join(' | ', @steps);
push @h, $steps, '<p>', $sdoc, '<p>', $steps;

# Print in fancy layout unless printable
if ($p) {
    print $cgi->header, <<EOH, @h, '</div></body></html>';
<html>
<head>
<title>$sx</title>
<link rel="stylesheet" type="text/css" href="/layout/style.css" />
<style type="text/css">
body { margin: 4px; }
</style>
</head>
<body>
<div class="body">
EOH
} else {
    print layout(navbar(@nav), @h);
}

