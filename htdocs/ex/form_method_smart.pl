#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

@fields = qw(username filename);

$form = CGI::FormBuilder->new(
             method  => 'POST',
             name    => 'personal_info',
             enctype => 'multipart/form-data',
             fields  => \@fields,
             smartness => 2,        # turn up smartness
        );

if ($form->submitted) {
    print $form->confirm(header => 1);
} else {
    print $form->render(header => 1);
}
