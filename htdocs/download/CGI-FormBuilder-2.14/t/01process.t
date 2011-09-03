#!/usr/bin/perl

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 13 }

# Fake a submission request
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'user=pete&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk&_submitted=1';

use CGI::FormBuilder;

# Now manually try a whole bunch of things
#1
ok(do {
    my $form = CGI::FormBuilder->new(fields => [qw/user name email/]);
    if ($form->submitted) {
        1;
    } else {
        0;
    }
}, 1);

#2
ok(do {
    my $form = CGI::FormBuilder->new(fields   => [qw/user name email/],
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
    my $form = CGI::FormBuilder->new(fields => [qw/user name email/],
                                     validate => { email => 'NETMASK' } );
    if ($form->submitted && $form->validate) {
        1;
    } else {
        0;
    }
}, 0);

#4
ok(do {
    # this should also fail since the submission key will be _submitted_magic,
    # and our query_string only has _submitted in it
    my $form = CGI::FormBuilder->new(fields => [qw/user name email/],
                                     name   => 'magic');
    if ($form->submitted) {
        1;
    } else {
        0;
    }
}, 0);

#5
ok(do {
    # CGI should override default values
    my $form = CGI::FormBuilder->new(fields => [qw/user name email/],
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
    my $form = CGI::FormBuilder->new(fields => [qw/user name email Addr/],
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
    my $form = CGI::FormBuilder->new(fields => { User => 'jim', ADDR => 'Hello' } );
    if ($form->submitted && ! $form->field('Addr') && $form->field('ADDR') eq 'Hello') {
        1;
    } else {
        0;
    }
}, 1);

#8
ok(do {
    my $form = CGI::FormBuilder->new(fields => []);   # no fields!
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
    my $form = CGI::FormBuilder->new(fields => { user => 'nwiger', pass => '' },
                                     validate => { user => 'USER' },
                                     required => [qw/pass/]);
    if ($form->submitted && $form->validate) {
        1;
    } else {
        0;
    }
}, 0);

#10
ok(do {
    # YARC (yet another 'required' check)
    my $form = CGI::FormBuilder->new(
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
}, q{
<script language="JavaScript1.3"><!-- hide from old browsers
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
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p><p>Fields shown in <b>bold</b> are required.<form action="01process.t" method="GET" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="2" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left"><b>Name</b></td><td><input id="name" name="name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Favorite Color</td><td><input id="color_red" name="color" type="checkbox" value="red" /> <label for="color_red">Red</label> <input id="color_green" name="color" type="checkbox" value="green" /> <label for="color_green">Green</label> <input id="color_blue" name="color" type="checkbox" value="blue" /> <label for="color_blue">Blue</label> </td></tr>
<tr valign="middle"><td colspan="2"><center><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>});

#13
ok(do {
    # check individual fields as static
    my $form = CGI::FormBuilder->new(fields => [qw/name color/]);
    $form->field(name => 'name', type => 'static');

    # Just return the form rendering
    # This should really go in 00generate.t, but the framework is too tight
    $form->render;
}, qq{<form action="01process.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="2" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Name</td><td><input id="name" name="name" type="hidden" value="Pete Peteson" />Pete Peteson </td></tr>
<tr valign="middle"><td align="left">Color</td><td><input id="color" name="color" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>});
