#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

# Hardwired - in reality these would come from a database
$defref = {
    first_name => 'Nathan',
    last_name  => 'Wiger',
    address    => '1234 Nowhere St',
    city       => 'San Diego',
    state      => 'California',
    zip        => '90210',
    mail_list  => 'No',
};

@fields = qw(first_name last_name email phone address city state zip mail_list);

$form = CGI::FormBuilder->new(
             method => 'POST',
             fields => \@fields,
             values => $defref,     # values from hashref
             required => 'ALL',
        );

# Read states
open(S, "<states");
chomp(@states = <S>);
close S;

$form->field(name => 'state', options => \@states);
$form->field(name => 'zip', size => 10, maxlength => 10);
$form->field(name => 'mail_list', options => [qw/Yes No/]);

# No confirmation to demonstrate stickiness
print $form->render(header => 1);

