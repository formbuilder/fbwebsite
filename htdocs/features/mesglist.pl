#!/usr/bin/perl

use CGI ':cgi';
print header();

open L, "<mesglist.txt" or die "Can't read mesglist.txt: $!";

print <<EOH;
<table border=1 width=600>
<tr>
    <th><font face="arial,helvetica">Message</th>
    <th><font face="arial,helvetica">Default</th>
</tr>
EOH

while (<L>) {
    chomp;
    next unless /\w/;
    my($pat,$exp) = split '=>', $_, 2;
    chop($exp);   # lose trailing comma
    $exp =~ s/</&lt;/g;
    print <<EOR;
<tr>
    <td><font face="arial,helvetica">$pat</td>
    <td><font face="arial,helvetica">$exp</td>
</tr>
EOR
}

print '</table>';

