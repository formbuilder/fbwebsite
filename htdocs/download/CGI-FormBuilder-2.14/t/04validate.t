#!/usr/bin/perl -w

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 7 }

# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';

# egads this part is annoying
use CGI 'header';
my $h = header();

use CGI::FormBuilder;

sub is_number {
    my $v = shift;
    return $v =~ /^\d+$/;
}

# What options we want to use, and data to validate
my @test = (
    {
        opt => { fields => [qw/first_name email/],
                 validate => {email => 'EMAIL'}, 
                 required => [qw/first_name/] ,
                 values => { first_name => 'Nate', email => 'nate@wiger.org' },
               },
        pass => 1,
    },
    {
        # max it out, baby
        opt => { fields => [qw/supply demand/],
                 options => { supply => [0..9], demand => [0..9] },
                 values  => { supply => [0..4], demand => [5..7] },
                 validate => { supply => [5..9], demand => [0..9] },
               },
        pass => 0,
    },
    {
        # max it out, baby
        opt => { fields => [qw/supply tag/],
                 options => { supply => [0..9], },
                 values  => { supply => [0..4], tag => ['Johan-Sebastian', 'Bach'] },
                 validate => { supply => 'NUM', tag => 'NAME' },
               },
        pass => 0,
    },
    {
        opt => { fields => [qw/date time ip_addr name time_confirm/],
                 validate => { date => 'DATE', time => 'TIME', ip_addr => 'IPV4',
                               time_confirm => 'eq $form->field("time")' },
                 values => { date => '03/30/2003', time => '1:30', ip_addr => '129.153.53.1', time_confirm => '1:30' },
               },
        pass => 1,
    },
    {
        opt => { fields => [qw/security_test/],
                 validate => { security_test => 'ne 42' },
                 values => { security_test => "'; print join ':', \@INC; return; '" },
               },
        pass => 1,
    },
    {
        opt => { fields => [qw/security_test2/],
                 validate => { security_test2 => 'ne 42' },
                 values => { security_test => 'foo\';`cat /etc/passwd`;\'foo' },
               },
        pass => 1,
    },
    {
        opt => { fields => [qw/subref_num/],
                 values => {subref_num => [0..9]},
                 validate => {subref_num => \&is_number},
               },
        pass => 1,
    },
);

# Cycle thru and try it out
for my $t (@test) {
    #$ENV{QUERY_STRING} = join '&', map { $_ . '=' . $t->{data}{$_} } keys %{$t->{data}};
    #$ENV{QUERY_STRING} =~ tr/ /+/;
    #warn "QUERY_STRING=$ENV{QUERY_STRING}\n" if $ENV{DEBUG};

    my $form = CGI::FormBuilder->new( %{ $t->{opt} } );
    while(my($f,$o) = each %{$t->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }

    # just try to validate
    ok($form->validate, $t->{pass} || 0);
}

