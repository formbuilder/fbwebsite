#!/usr/bin/perl

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
# XXX This test is currently broken on all platforms
BEGIN { plan tests => 1, todo => [1]; }

# Keep upload contents
my $junkfile = '/tmp/fbtest.junk.file';

# Fake a file uploading, which is tricky
# Need to create a junk file and link STDIN to it...
$ENV{REQUEST_METHOD} = 'POST';
open(JUNKFILE, ">$junkfile") || die "Can't write $junkfile: $!";
print JUNKFILE <<EOF;
Content-Type: multipart/form-data; boundary=SLICE_AND_DICE

--SLICE_AND_DICE\r
Content-Disposition: form-data; name="_submitted"

1
--SLICE_AND_DICE\r
Content-Disposition: form-data; name="file"; filename="$junkfile"
Content-Type: text/plain

This file has some text in it.
It also has more than one line.

--SLICE_AND_DICE\r
EOF
close JUNKFILE;
open(STDIN, "<$junkfile") || die "Can't link STDIN to $junkfile: $!";

use CGI::FormBuilder;

# Now manually try a whole bunch of things
ok(do {
    my $form = CGI::FormBuilder->new(
                    enctype => 'multipart/form-data', method  => 'POST',
                    fields => [qw/file/]
               );

    $form->field(name => 'file', type => 'file');

    if ($form->submitted) {
        my $file = $form->field('file');
    }

}, 1);

unlink $junkfile;

