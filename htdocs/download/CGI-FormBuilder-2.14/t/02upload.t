#!/usr/bin/perl

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
# XXX This test is currently broken on all platforms
BEGIN { plan tests => 1, todo => [1]; }

ok(1,0);

