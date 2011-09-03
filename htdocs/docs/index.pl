#!/usr/bin/perl

# Simple doc displayer, it looks for files in this
# directory named [0-9][0-9].shtml, where the first
# line in the file is the name of the function

use lib '../lib';
use strict;

use FBSite::Layout;
use CGI ':cgi';

my $base = "$FBSITE/htdocs/download/CGI-FormBuilder-";
my $file = 'CGI/FormBuilder.html';
my $jump = param('jump');

my $html = <<EOS;
Please select the version of FormBuilder you wish to view documentation
for. The most recent versions are shown first.
<ul>
EOS

my @doc = ();
for (reverse glob "$base*/docs") {
    my($ver) = m#^$base([\d\.]+)#;
    s/.*htdocs//;   # basename, essentially
    push @doc, <<EOL;
<li><a href="$_/$file">FormBuilder $ver</a>
EOL
    if ($jump) {
        print redirect("$_/$file#$jump");
        exit;
    }
}

$html .= join '', @doc;
$html .= <<EOE;
</ul>
<p>
To download FormBuilder, visit the <a href=/download/>download page</a>.
<p>
Still confused? Try the <a href=/tutor/>Tutorial</a>, <a href=/ex/>Examples</a>,
or <a href="http://groups.google.com/group/perl-formbuilder">FormBuilder Google Group</a>.
EOE

print layout(head('FormBuilder Documentation'), $html);


