#!/usr/bin/perl -I.

package Stub;
sub new { return bless {}, shift }
sub AUTOLOAD { 1 }

package main;

use strict;
use vars qw($TESTING $DEBUG $NOSESSION);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { 
    my $numtests = 42;

    plan tests => $numtests;

    # success if we said NOTEST
    if ($ENV{NOTEST}) {
        ok(1) for 1..$numtests;
        exit;
    }
}


# Fake a submission request
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk&_submitted=1&blank=&two=&two=&_page=2&_submitted_p2=2';

use CGI::FormBuilder;
use CGI::FormBuilder::Multi;

my $h = "Content-Type: text/html; charset=ISO-8859-1\r\n\r\n";

# separate forms
my $form1 = {
    name  => 'p1',
    title => 'Page 1',
    fields => [qw(name email phone address city state zip extra)],
};
my $form2 = {
    name  => 'p2',
    title => 'Numero Dos',
    fields => 'ticket',
};
my $form3 = {
    name  => 'p3',
    title => 'Tres Tacos',
    fields => [qw(replacement ticket action)],
    # undocumented hooks
    fieldopts => {
        replacement => {
            options => [qw(TRUE FALSE MAYBE)],
            value   => 'FALSE',
            label   => 'MikeZ is Da"Bomb"'
        },
        ticket => {
            comment => 'master mister',
            value   => '-1million',
            force   => 1,
        },
        action => {
            label   => ' JackSUN ',
            value   => "Your mom if I'm lucky",
            type    => 'PASSWORD',
            misc    => 'ellaneous',
        },
    },
    header => 1,
};

my $html3 = $h . <<EOH;
<html><head><title>Tres Tacos</title></head>
<body bgcolor="white"><h3>Tres Tacos</h3><form action="/page.pl" id="p3" method="Post" name="p3"><input id="_submitted_p3" name="_submitted_p3" type="hidden" value="2" /><input id="_page" name="_page" type="hidden" value="3" /><table border="0">
<tr id="p3_replacement_row" valign="middle"><td id="p3_replacement_label">MikeZ is Da"Bomb"</td><td id="p3_replacement_input"><input checked="checked" id="replacement_TRUE" name="replacement" type="radio" value="TRUE" /> <label for="replacement_TRUE">TRUE</label> <input id="replacement_FALSE" name="replacement" type="radio" value="FALSE" /> <label for="replacement_FALSE">FALSE</label> <input id="replacement_MAYBE" name="replacement" type="radio" value="MAYBE" /> <label for="replacement_MAYBE">MAYBE</label> </td></tr>
<tr id="p3_ticket_row" valign="middle"><td id="p3_ticket_label">Ticket</td><td id="p3_ticket_input"><input id="ticket" name="ticket" type="text" value="-1million" /> master mister</td></tr>
<tr id="p3_action_row" valign="middle"><td id="p3_action_label"> JackSUN </td><td id="p3_action_input"><input id="action" misc="ellaneous" name="action" type="password" value="Unsubscribe" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="p3_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form></body></html>
EOH

my $multi = CGI::FormBuilder::Multi->new(
                 $form1, $form2, $form3,

                 header => 0,
                 method => 'Post',
                 action => '/page.pl',
                 debug  => $DEBUG,

                 navbar => 0,
            );

my $form = $multi->form;
ok($form->name, 'p2');  #1

ok($multi->page, 2);    #2
ok($multi->pages, 3);   #3
ok(--$multi->page, 1);  #4

$form = $multi->form;
ok($form->name, 'p1');          #5
ok($form->title, 'Page 1');     #6
ok(keys %{$form->field}, 8);    #7
ok($form->field('email'), 'pete@peteson.com');  #8
ok($form->submitted, 0);        # 9
ok($form->action, '/page.pl');  #10
ok($form->field('blank'), undef);  #11

ok($multi->page++, 1);      #12
ok($multi->page,   2);      #13
ok($form = $multi->form);   #14
ok(++$multi->page, $multi->pages); #15
ok($form = $multi->form);   #16
ok(++$multi->page, $multi->pages+1); #17
eval { $form = $multi->form };  # should die
ok($@);                     #18 ^^^ from die
ok($multi->page = $multi->pages, 3);    #19

ok($form = $multi->form);   #20
ok($form->field('replacement'), 'TRUE');  # 21

ok($form->render, $html3);  #22
ok($form->field('action'), 'Unsubscribe');  #23
ok($form->field('ticket'), '-1million');    #24
ok(--$multi->page, 2);      #25
ok($form = $multi->form);   #26
ok($form->field('ticket'), 111);    #27
ok($form->field('extra'), undef);   #28 - not a form field

ok($multi->page(1), 1);     #29
ok($form = $multi->form);   #30
ok($form->field('ticket'), undef);  #31 - not a form field
ok($form->field('extra'), 'junk');  #32 

# Session twiddling - must use page 3
ok($multi->page(3), 3);     #33
ok($form = $multi->form);   #34

my $session;
eval <<'EOE';
use Cwd;
my $pwd = cwd;
require CGI::Session;
$session = CGI::Session->new("driver:File", undef, {Directory => $pwd});
EOE
$session ||= new Stub;
$NOSESSION = $@ ? 'skip: CGI::Session not installed here' : 0;

skip($NOSESSION, $form->sessionid($session->id), $session->id);     #35
my($c) = $form->header =~ /Set-Cookie: (\S+)/;
skip($NOSESSION, $c, '_sessionid='.$session->id.';');               #36
skip($NOSESSION, $session->save_param($form));                      #37
skip($NOSESSION, $session->param('ticket'), $form->field('ticket'));#38
skip($NOSESSION, $session->param('name'), $form->field('name'));    #39
ok($form->field(name => 'name', value => 'Tater Salad', force => 1));   #40
skip($NOSESSION, $session->param('name', $form->field('name')));    #41
skip($NOSESSION, $session->param('name'), $form->field('name'));    #42

