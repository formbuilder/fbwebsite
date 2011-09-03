#!/usr/bin/perl

# advanced_validation.pl - showcase extended validation regexps

use lib '../lib';
use CGI::FormBuilder;

$form = CGI::FormBuilder->new(
             fields   => [qw/full_name username email dept_num
                             password confirm_password/],
             validate => {
                full_name => '/\w+\s+\w+.*/',
                username  => '/^[a-zA-Z]\w{5,7}$/',
                email     => 'EMAIL',
                dept_num  => [110923, 398122, 918923, 523211],
                password  => '/^[\w.!?@#$%&*]{6,8}$/',
                confirm_password => {
                      javascript => '== form.password.value',
                      perl       => 'eq $form->field("password")'
                }
             }
        );

warn $form->basename;

if ($form->submitted && $form->validate) {
    print $form->confirm(header => 1);
} else {
    print $form->render(header => 1);
}

