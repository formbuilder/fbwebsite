#!/usr/bin/perl

# Simple doc displayer, it looks for files in this
# directory named [0-9][0-9].shtml, where the first
# line in the file is the name of the function

use lib '../lib';
use strict;

use FBSite::Layout;
use CGI ':cgi';

my $base = '../download/CGI-FormBuilder-';
my $cpan = 'http://search.cpan.org/search?mode=module&query=';

my $hdoc;
if ($ENV{PATH_INFO}) {
    (my $ver = $ENV{PATH_INFO}) =~ s#^/+##;
    my $hdoc = "$base$ver";
} else {
    opendir(DOC, '.');
    ($hdoc) = reverse sort grep /^fbdoc/, readdir DOC;
    closedir(DOC);
}

# Just extract the POD and do a little parsing
# Must have run pod2html on FormBuilder.pm to generate this file
open P, "<$hdoc" or die "Missing documentation source file";
$_ = join '', <P>;
close P;

# Uniquely Perl chars
s/([^-])->/$1-&gt;/g;
s/=>/=&gt;/g;

s!</body>!!i;
s!</html>!!i;

s!(.+?)<HR>!!si;

# custom navbar twiddling
my $nav = $1;
$nav =~ s!</?ul>!!gi;
$nav =~ s!<LI>(<A\s+HREF=.*>[-A-Z0-9\(\) ]+</A>)</LI>!<b>$1</b><br>!g;   # top level
#$nav =~ s!<LI>(<A\s+HREF=.*>\w+</A>)</LI>!- $1<br>!g;         # sub heading

# strip options out of function headings
$nav =~ s!<LI>(<A\s+HREF=.*>.+\()[^<]+(.*)!<LI>$1)$2$3!g;

# I don't know why, but this has to go after navbar?
s!(<a)(\s*href="?)/!$1 target=_blank $2$cpan!gi;

# Finally, special <pre> magic
s!</PRE>\n<PRE>!\n!g;
s!<pre>!<blockquote>
<table cellpadding=5 border=1><tr><td bgcolor="#FFFFCC" width=500>
<font face="courier new,courier"><pre>!gi;
s!</pre>!</pre>
</tr></td></table>
</blockquote>!gi;

print layout(navbar($nav), $_);


