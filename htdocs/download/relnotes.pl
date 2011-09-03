#!/usr/bin/perl

# must discard warnings since regex mismatches prototype?
BEGIN { open STDERR, ">/dev/null" }

use strict;
use CGI ':standard';
use File::Basename;

my $base = "$ENV{DOCUMENT_ROOT}/download";

use lib '../lib';
use FBSite::Layout;

my $rel = param('r') || die "No release specified";
my $dir = "$base/CGI-FormBuilder-$rel";

open(R, "<$dir/Changes") || warn "Can't open CGI-FormBuilder-$rel/Changes";
$_ = join '', <R>;
close R;

# HTML escaping
s!<!&lt;!g;
s!>!&gt;!g;

if (/RCS/) {
    # RCS plaintext
    s/^/    /msg;
    $_ = "<pre>$_</pre>";
} else {
    # Specialized POD text -> HTML conversion
    s!"([^"]+)"!<code>$1</code>!gm;
    s!^(\s+[-*])\s+(.+)!<ul><li>$2</li></ul>!gm;
    s!</ul>\s*<ul>!!gms;    # took me 5 years to figure that out
    s!^([A-Z]{2,}.+)!'</blockquote>'.head($1).'<blockquote>'!gme;
    s!^(\w.+)!head($1)!gme;

    # Egads this is a special-purpose heading thingy
    s!^  (?:<code>)?([A-Z]\w+.+)!head($1)!gme;

    # This is pod2text-centric and will not "scale"
    s!(\n)(\n[ \t]{8,}.+?\n)(\n)[ ]{0,4}(\S+)!$1<pre>$2</pre>$3$4!gs;

    s!\n\n(\w)!\n<p>\n$1!gms;
}

my $tar = basename(-f "$dir.tgz" ? "$dir.tgz" : "$dir.tar.gz");
my $browse = basename($dir);

print layout(head("Release Notes for $rel"), <<EOH, $_);
Here's what's new in FormBuilder
<a href="$tar" class="mark">$rel</a> (<a href="$browse">browse</a>),
along with any known issues or bugs still in the works.
EOH

