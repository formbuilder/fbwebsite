#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

$form = CGI::FormBuilder->new(
             fields => [qw/name email mlist/],
             template => 'email_form.tmpl'
        );

# create a pair of Yes/No options, and choose Yes by default
$form->field(name => 'mlist', options => [qw/Yes No/],
             value => 'Yes');

if ($form->submitted) {
    # update our database and redirect them to the next page
    print "Content-type: text/plain\n\nHere you would write your code";
} else {
    print $form->render(header => 1);
}

