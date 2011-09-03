#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

@fields = qw(first_name last_name address city state zip email);

$form = CGI::FormBuilder->new(
             fields => \@fields,
             required => 'ALL',
             font   => 'arial,helvetica',
             title  => 'Personal Information',
             text   => 'Please input your personal info below:',
             body   => {
                bgcolor => '#3399CC',
                text    => 'white',
                link    => '#CC0000', 
                vlink   => '#CC0000', 
                alink   => '#CC0000', 
             },
             table  => {
                bgcolor => 'gray',
                border  => 0,
                cellspacing => 0,
                cellpadding => 5,
             },
             lalign => 'right',
        );

# Setup options for a couple fields
$form->field(name => 'state', options => 'STATE');
$form->field(name => 'zip', size => 10, maxlength => 10);

if ($form->submitted) {
    # Do a database update here, etc
    $fname = $form->field('first_name');
    $addr  = $form->field('address');

    print $form->confirm(header => 1);
} else {
    print $form->render(header => 1);
}

