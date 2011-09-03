#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

@fields = qw(first_name last_name email phone);

$form = CGI::FormBuilder->new(
             fields => \@fields,
        );

if ($form->submitted && $form->validate) {
    # you would write code here to act on the form data
    $fname = $form->field('first_name');
    $lname = $form->field('last_name');

    print $form->confirm(header => 1); 
} else {
    print $form->render(header => 1); 
}   
