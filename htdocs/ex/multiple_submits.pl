#!/usr/bin/perl

use lib '../lib';
use CGI::FormBuilder;

@fields = qw(serial_number part_number description purchase_date updated_by);
%values = ( serial_number => '200-192-0931', part_number => '200-192',
            description   => 'Flux Capacitor', purchase_date => 1984 );

$form = CGI::FormBuilder->new(
             header => 1,
             font   => 'arial,helvetica',
             method => 'POST',
             fields => \@fields,
             values => \%values,
             required => 'ALL',
             submit => [qw/Update Delete Cancel/],
             reset  => 0,         # turn off reset button
             jsfunc => <<EOJS

if (form._submit.value == "Delete") {
    if (confirm("Really DELETE this entry?")) return true;
    return false;
} else if (form._submit.value == "Cancel") {
    return true;    
}

EOJS
        );

if ($form->submitted eq 'Update' && $form->validate) {
    # code to update record
    print $form->confirm(text => 'Your request to "Update" was received');
} elsif ($form->submitted eq 'Delete') {
    # code to delete record
    print $form->confirm(text => 'Your request to "Delete" was received');
} elsif ($form->submitted eq 'Cancel') {
    # do nothing
    print $form->confirm(text => 'Your request to "Cancel" was received');
} else {
    print $form->render;
}
