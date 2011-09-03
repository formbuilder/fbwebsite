#!/usr/bin/perl -I.

use strict;
use vars qw($TESTING $DEBUG);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 22 }

# Fake a submission request
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk&_submitted=1&blank=&two=&two=';

use CGI::FormBuilder;

# Now manually try a whole bunch of things
#1
ok(do {
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/user name email/]);
    if ($form->submitted) {
        1;
    } else {
        0;
    }
}, 1);

#2
ok(do {
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields   => [qw/user name email/],
                                     validate => { email => 'EMAIL' } );
    if ($form->submitted && $form->validate) {
        1;
    } else {
        0;
    }
}, 1);

#3
ok(do {
    # this should fail since we are saying our email should be a netmask
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/user name email/],
                                     validate => { email => 'NETMASK' } );
    if ($form->submitted && $form->validate) {
        0;  # failure
    } else {
        1;
    }
}, 1);

#4
ok(do {
    # this should also fail since the submission key will be _submitted_magic,
    # and our query_string only has _submitted in it
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/user name email/],
                                     name   => 'magic');
    if ($form->submitted) {
        0;  # failure
    } else {
        1;
    }
}, 1);

#5
ok(do {
    # CGI should override default values
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/user name email/],
                                     values => { user => 'jim' } );
    if ($form->submitted && $form->field('user') eq 'pete') {
        1;
    } else {
        0;
    }
}, 1);

#6
ok(do {
    # test a similar thing, by with mixed-case values
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/user name email Addr/],
                                     values => { User => 'jim', ADDR => 'Hello' } );
    if ($form->submitted && $form->field('Addr') eq 'Hello') {
        1;
    } else {
        0;
    }
}, 1);

#7
ok(do {
    # test a similar thing, by with mixed-case values
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => { User => 'jim', ADDR => 'Hello' } );
    if ($form->submitted && ! $form->field('Addr') && $form->field('ADDR') eq 'Hello') {
        1;
    } else {
        0;
    }
}, 1);

#8
ok(do {
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => []);   # no fields!
    if ($form->submitted) {
        if ($form->field('name') || $form->field('extra')) {
            # if we get here, this means that the restrictive field
            # masking is not working, and all CGI params are available
            -1;
        } elsif ($form->cgi_param('name')) {
            1;
        } else {
            0;
        }
    } else {
            0;
    }
}, 1);

#9
ok(do {
    # test if required does what v1.97 thinks it should (should fail)
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => { user => 'nwiger', pass => '' },
                                     validate => { user => 'USER' },
                                     required => [qw/pass/]);
    if ($form->submitted && $form->validate) {
        0;
    } else {
        1;
    }
}, 1);

#10
ok(do {
    # YARC (yet another 'required' check)
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/name email phone/],
                    validate => {email => 'EMAIL', phone => 'PHONE'},
                    required => [qw/name email/],
               );
    if ($form->submitted && $form->validate) {
        1;
    } else {
        0;
    }
}, 1);

#11
ok(do {
    # test of proper CGI precendence when manually setting values
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/name email action/],
                    validate => {email => 'EMAIL'},
                    required => [qw/name email/],
               );
    $form->field(name => 'action', options => [qw/Subscribe Unsubscribe/],
                 value => 'Subscribe');
    if ($form->submitted && $form->validate && $form->field('action') eq 'Unsubscribe') {
        1;
    } else {
        0;
    }
}, 1);

#12
ok(do {
    # see if our checkboxes work how we want them to
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/name color/],
                    labels => {color => 'Favorite Color'},
                    validate => {email => 'EMAIL'},
                    required => [qw/name/],
                    sticky => 0,
               );
    $form->field(name => 'color', options => [qw/red green blue/],
                 nameopts => 1, multiple => 1);

    # Just return the form rendering
    # This should really go in 00generate.t, but the framework is too tight
    $form->render;
}, q{<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // standard text, hidden, password, or textarea box
    var name = form.elements['name'].value;
    if ( ((! name && name != 0) || name === "")) {
        alertstr += '- You must enter a valid value for the "Name" field\n';
        invalid++;
    }
    if (invalid > 0 || alertstr != '') {
        if (! invalid) invalid = 'The following';   // catch for programmer error
        alert(''+invalid+' error(s) were encountered with your submission:'+'\n\n'+alertstr+'\n'+'Please correct these fields and try again.');
        // reset counters
        alertstr = '';
        invalid  = 0;
        return false;
    }
    return true;  // all checked ok
}
//-->
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript><p>Fields that are <b>highlighted</b> are required.</p><form action="01process.t" method="GET" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="2" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left"><b>Name</b></td><td align="left"><input id="name" name="name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Favorite Color</td><td align="left"><input id="color_red" name="color" type="checkbox" value="red" /> <label for="color_red">Red</label> <input id="color_green" name="color" type="checkbox" value="green" /> <label for="color_green">Green</label> <input id="color_blue" name="color" type="checkbox" value="blue" /> <label for="color_blue">Blue</label> </td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
});

#13
ok(do {
    # check individual fields as static
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/name name_2 color/]);
    $form->field(name => 'name', static => 1);
    $form->field(name => 'name_2', type => 'static');

    # Just return the form rendering
    # This should really go in 00generate.t, but the framework is too tight
    $form->render;
}, qq{<form action="01process.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="2" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Name</td><td align="left"><input id="name" name="name" type="hidden" value="Pete Peteson" />Pete Peteson </td></tr>
<tr valign="middle"><td align="left">Name 2</td><td align="left"><input id="name_2" name="name_2" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Color</td><td align="left"><input id="color" name="color" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
});

#14
ok(do {
    # test of proper CGI precendence when manually setting values
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/name email blank/],
                    values => {blank => 'DEF', name => 'DEF'}
               );
    if (defined($form->field('blank')) && ! $form->field('blank') 
        && $form->field('name') eq 'Pete Peteson') {
        1;
    } else {
        0;
    }
}, 1);

#15
ok(do {
    # test of proper CGI precendence when manually setting values
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/name email blank/],
                    keepextras => 0,    # should still get value
               );
    if (! $form->field('extra') && 
        $form->cgi_param('extra') eq 'junk') {
        1;
    } else {
        0;
    }
}, 1);

# 16
ok(do{
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/name color hid1 hid2/]);
    $form->field(name => 'name', static => 1, type => 'text');
    $form->field(name => 'hid1', type => 'hidden', value => 'Val1a');
    $form->field(name => 'hid1', type => 'hidden', value => 'Val1b');   # should replace Val1a
    $form->field(name => 'hid2', type => 'hidden', value => 'Val2');
    $form->field(name => 'color', value => 'blew');

    # Just return the form rendering
    # This should really go in 00generate.t, but the framework is too tight
    $form->confirm;
}, qq{Success! Your submission has been received LOCALTIME.<form action="01process.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="2" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><input id="hid1" name="hid1" type="hidden" value="Val1b" /><input id="hid2" name="hid2" type="hidden" value="Val2" /><table border="0">
<tr valign="middle"><td align="left">Name</td><td align="left"><input id="name" name="name" type="hidden" value="Pete Peteson" />Pete Peteson </td></tr>
<tr valign="middle"><td align="left">Color</td><td align="left"><input id="color" name="color" type="hidden" value="blew" />blew </td></tr>
</table></form>
});

# 17
ok(do{
    my $form = CGI::FormBuilder->new(debug => $DEBUG, fields => [qw/name color dress_size taco:punch/]);
    $form->field(name => 'blank', value => 175, force => 1);
    $form->field(name => 'user', value => 'bob');

    if ($form->field('blank') eq 175 && $form->field('user') eq 'pete') {
        1;
    } else {
        0;
    }
}, 1);

#18
ok(do{
    my $form = CGI::FormBuilder->new(
                        debug => $DEBUG,
                        smartness  => 0,
                        javascript => 0,
                   );

    $form->field(name => 'blank', value => 'aoe', type => 'text'); 
    $form->field(name => 'extra', value => '24', type => 'unspecified', override => 1);
    $form->field(name => 'two', value => 'one');

    my @v = $form->field('two');
    if ($form->submitted && $form->validate && defined($form->field('blank')) && ! $form->field('blank')
        && $form->field('extra') eq 24 && @v == 2) {
        1;
    } else {
        0;
    }
}, 1);

#19
ok(do{
    my $form = CGI::FormBuilder->new(debug => $DEBUG);
    $form->fields([qw/one two three/]);
    my @v;
    if (@v = $form->field('two') and @v == 2) {
        1;
    } else {
        0;
    }
}, 1);

#20
ok(do{
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/one two three/],
                    fieldtype => 'TOMATO',
               );
    $form->field(name => 'added_later', label => 'Yo');
    my $ok = 1;
    for ($form->fields) {
        $ok = 0 unless $_->render =~ /tomato/i;
    }
    $ok;
}, 1);

#21
ok(do{
    my $form = CGI::FormBuilder->new(
                    debug => $DEBUG,
                    fields => [qw/a b c/],
                    fieldattr => {type => 'TOMATO'},
                    values => {a => 'Ay', b => 'Bee', c => 'Sea'},
               );
    $form->values(a => 'a', b => 'b', c => 'c');
    my $ok = 1;
    for ($form->fields) {
        $ok = 0 unless $_->value eq $_;
    }
    $ok;
}, 1);

#22
ok(do{
    my $form = CGI::FormBuilder->new(
                    fields  => [qw/name user/],
                    required => 'ALL',
                    sticky  => 0,
               );
    my $ok = 1;
    my $name = $form->field('name');
    $ok = 0 unless $name eq 'Pete Peteson';
    my $user = $form->field('user');
    $ok = 0 unless $user eq 'pete';
    for ($form->fields) {
        $ok = 0 unless $_->tag eq qq(<input id="$_" name="$_" type="text" />);
    }
    $ok;
}, 1);

