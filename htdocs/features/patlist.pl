#!/usr/bin/perl

use CGI ':cgi';
print header();

open L, "<patlist.txt" or die "Can't read patlist.txt: $!";

print <<EOH;
<table border=1 width=500>
<tr>
    <th><font face="arial,helvetica">Tag</th>
    <th><font face="arial,helvetica">Description</th>
</tr>
EOH

while (<L>) {
    my($pat,$exp) = split '-', $_, 2;
    print <<EOR;
<tr>
    <td><font face="arial,helvetica">$pat</td>
    <td><font face="arial,helvetica">$exp</td>
</tr>
EOR
}

print '</table>';

