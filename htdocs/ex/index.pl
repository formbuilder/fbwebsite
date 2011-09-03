#!/usr/bin/perl

use lib '../lib';
use FBSite::Layout;
use CGI::FormBuilder::Util;   # just for toname()

my $font = '<font face="arial,helvetica">';

my @d = (head('FormBuilder Examples'), <<EOH);
Here are some examples of what you can do with FormBuilder.
<p>
Each of these is used in the <a href=/tutor/>Tutorial</a>,
so you may want to read that as well.
<blockquote>
<table border="0">
EOH

opendir D, '.';
for my $f (sort grep /\.pl$/, readdir D) {
    next if $f eq 'index.pl' || $f eq 'source.pl';
    my $n = CGI::FormBuilder::Util::toname($f);  # shh! quiet!
    push @d, <<EOL
<tr><td>$font$n</td>
    <td>$font<a href="$f" onClick="miniwin(this)">in action</a></td>
    <td>$font<a href="source.pl?f=$f" onClick="miniwin(this)">source</a></td></tr>
EOL
}
push @d, <<EOD;
</table></blockquote><p>
If you have any examples of your own, I would love to use them.
Please <a href="/contrib/author.pl">send them to me</a>.
EOD

print layout(@d);

