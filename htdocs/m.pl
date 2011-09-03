#!/usr/bin/perl

use CGI::FormBuilder;
my $f = CGI::FormBuilder->new(
   header      => 1,
   title       => 'test',
   name        => 'test',
   table       => 1,
   fields      => [ 'test' ],
   #validate    => {
       #test        => '/^.*$/',
   #},
   required    => 'ALL',
);

if ($f->submitted && $f->validate) {
   print $f->confirm;
}
else {
   print $f->render;
}
