#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

@fields = qw(first_name last_name email phone mailing_list);

$form = CGI::FormBuilder->new(
             method => 'POST',
             fields => \@fields,
             validate => {
                email => 'EMAIL',    # validate fields using
                phone => 'PHONE',    # built-in patterns
             },
             required => 'ALL',
        );

    $form->field(name => 'mailing_list',
             options => [qw/Subscribe Unsubscribe/]);

if ($form->submitted) {
    # you would write code here to act on the form data
    $fname = $form->field('first_name');
    $lname = $form->field('last_name');

    print $form->confirm(header => 1);
} else {
    print $form->render(header => 1);
}

