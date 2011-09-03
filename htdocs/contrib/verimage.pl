#!/usr/bin/perl

# verimage.pl - generate verification image as fast as possible

$text = $ENV{QUERY_STRING} || die "Missing verification text";
$text = substr($text,0,6);                      # only first 6 are used
$text =~ tr/A-Za-z0-9/N-ZA-Mn-za-m987654321/;   # rot13 (trivial)

print "Content-type: image/jpeg\n\n" if $ENV{REQUEST_METHOD};

open(IMG, "convert -background black -fill white -pointsize 14 'label:$text' jpg:- |") || die "verimage.pl: convert failed: $!";
print while <IMG>;
close IMG;

