#!/usr/bin/perl -Ilib -I../lib

# Copyright (c) 2000-2006 Nathan Wiger <nate@wiger.org>.
# All Rights Reserved. If you're reading this, you're bored.
# 1d-messages.t - messages and localization

use strict;

our $TESTING = 1;
our $DEBUG = $ENV{DEBUG} || 0;
our $VERSION;
BEGIN { $VERSION = '3.05'; }

use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
my @pm;
my %messages;
BEGIN { 
    %messages = (
        form_invalid_text   => 'You fucked up',
        js_invalid_text     => 'Yep, shit sucks!',
        form_select_default => '*<- choose ->*',
        taco_salad          => 'is delicious',
        parade              => [1,2,3],

        form_invalid_text     => '<font color="red"><b>%s</b></font>',
        form_invalid_input    => 'Invalid entry',
        form_invalid_select   => 'Select an option from this list',
        form_invalid_checkbox => 'Check one or more options',
        form_invalid_radio    => 'Choose an option',
        form_invalid_password => 'Invalid entry',
        form_invalid_textarea => 'Please fill this in',
        form_invalid_file     => 'Invalid filename',
        form_invalid_default  => 'Invalid entry',
    );

    # try to load all the .pm's except templates from MANIFEST
    open(M, "<MANIFEST") || warn "Can't open MANIFEST ($!) - skipping imports";
    chomp(@pm = grep m#Messages/[a-z]+_.*#, grep /\.pm$/, <M>);
    close(M);

    #
    # There are 34 keys, times the number of modules, plus one load of the module.
    # Then, also add in our custom tests as well, which is two passes over
    # the %messages hash (above) plus 4 charset/dtd checks
    #

    my $numtests = (34 * @pm) + @pm + (keys(%messages) * 2) + 4;

    plan tests => $numtests;

    # success if we said NOTEST
    if ($ENV{NOTEST}) {
        ok(1) for 1..$numtests;
        exit;
    }
}

# Messages, both inline and file
my $locale = "fb_FAKE";
my $messages = "messages.$locale";
open(M, ">$messages") || warn "Can't write $messages: $!";
while (my($k,$v) = each %messages) {
    print M join(' ', $k, ref($v) ? @$v : $v), "\n";
}
close(M);

# Fake a submission request
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk&_submitted=1&blank=&two=&two=';

use CGI::FormBuilder 3.05;

# Now manually try a whole bunch of things
my $hash = CGI::FormBuilder->new(
                debug => $DEBUG,
                fields => [qw/user name email/],
                messages => \%messages
           );

for my $k (sort keys %messages) {
    #local $" = ', ';
    ok($hash->messages->$k, ref($messages{$k}) ? "@{$messages{$k}}" : $messages{$k});
}

my $file = CGI::FormBuilder->new(
                debug => $DEBUG,
                fields => [qw/user name email/],
                messages => $messages,
           );

for my $k (sort keys %messages) {
    #local $" = ', ';
    ok($file->messages->$k, ref($messages{$k}) ? "@{$messages{$k}}" : $messages{$k});
}

unlink $messages;

# Check to ensure our lang and charset work correctly
{   local $TESTING = 0;
    ok($file->charset, 'iso-8859-1');
    ok($file->lang,    'en_US');
    ok($file->dtd, <<EOD);
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html
        PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en_US" xml:lang="en_US">
EOD
    ok($file->charset('yo.momma'), 'yo.momma');
}

# Final test set is to just make sure we have all the keys for all modules
require CGI::FormBuilder::Messages::default;
my %need = CGI::FormBuilder::Messages::locale->messages;
my @keys = keys %need;
for my $pm (@pm) {
    my($lang) = $pm =~ /([a-z]+_[A-Z]+)/;
    my $skip = $lang ? undef : "skip: Can't get language from $pm";
    my $form;
    eval { $form = CGI::FormBuilder->new(messages => ":$lang"); };
    skip($skip, !$@);
    for (@keys) {
        skip($skip, $form->{messages}->$_) || warn "Locale $lang: missing $_\n";
    }
}


