#!/usr/bin/perl

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 10 }

# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE';

use CGI::FormBuilder;

# UNIX test
#my $NOT_UNIX = -d '/usr' ? 0 : 1;
my $NOT_UNIX = 0;

#warn "# VERSION = $CGI::FormBuilder::VERSION\n";

# What options we want to use, and what we expect to see
my @test = (
    {
        opt => { fields => [qw/name email/] },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">Name</td><td><input name="name" type="text"></td></tr>
<tr valign="middle"><td align="left">Email</td><td><input name="email" type="text"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset"><input name="_submit" type="submit" value="Submit"></center></td></tr></table>
</form>)
    },

    {
        opt => { fields => [qw/Upper Case/], values => { Upper => 1, Case => 0 } },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">Upper</td><td><input name="Upper" type="text" value="1"></td></tr>
<tr valign="middle"><td align="left">Case</td><td><input name="Case" type="text" value="0"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset"><input name="_submit" type="submit" value="Submit"></center></td></tr></table>
</form>),
    },

    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', reset => 0 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">First Name</td><td><input name="first_name" type="text"></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td><input name="last_name" type="text"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_submit" type="submit" value="Update"></center></td></tr></table>
</form>),
    },

    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', 
                 reset => 0, header => 1, body => {bgcolor => 'black'} },
        res => q(Content-type: text/html

<html><head><title>00generate</title></head><body bgcolor="black"><h3>00generate</h3>
<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">First Name</td><td><input name="first_name" type="text"></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td><input name="last_name" type="text"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_submit" type="submit" value="Update"></center></td></tr></table>
</form></body></html>
),
    },

    {
        opt => { fields => {first_name => 'Nate', email => 'nate@wiger.org' },
                 validate => {email => 'EMAIL'}, required => [qw/first_name/] },
        res => q(
<script language="JavaScript1.2"><!-- hide from old browsers
function validate (form) {
    // standard text, hidden, password, or textarea box
    var email = form.elements['email'].value;
    if ((email || email == 0) &&
        (! email.match(/^[\w\-\+\.]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) ) {
        alert('Error: You did not enter a valid value for the "Email" field');
        return false;
    }
    // standard text, hidden, password, or textarea box
    var first_name = form.elements['first_name'].value;
    if ( ! (first_name )) {
        alert('Error: You did not enter a valid value for the "First Name" field');
        return false;
    }
    return true;  // all checked ok
}
//-->
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="GET" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">Email</td><td><input name="email" type="text" value="nate@wiger.org"> <font size="-1">(name@host.domain)</font></td></tr>
<tr valign="middle"><td align="left"><b>First Name</b></td><td><input name="first_name" type="text" value="Nate"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset"><input name="_submit" type="submit" value="Submit"></center></td></tr></table>
</form>),
    },

    {
        # utilize our query_string to test stickiness
        opt => { fields => [qw/ticket user part_number/], method => 'POST', keepextras => 1,
                 validate => { ticket => '/^\d+$/' }, submit => [qw/Update Delete Cancel/],
                },
        res => q(
<script language="JavaScript1.2"><!-- hide from old browsers
function validate (form) {
    // standard text, hidden, password, or textarea box
    var ticket = form.elements['ticket'].value;
    if ( (! ticket.match(/^\d+$/)) ) {
        alert('Error: You did not enter a valid value for the "Ticket" field');
        return false;
    }
    return true;  // all checked ok
}
//-->
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="POST" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><input name="replacement" type="hidden" value="TRUE"><table>
<tr valign="middle"><td align="left"><b>Ticket</b></td><td><input name="ticket" type="text" value="111"></td></tr>
<tr valign="middle"><td align="left">User</td><td><input name="user" type="text" value="pete"></td></tr>
<tr valign="middle"><td align="left">Part Number</td><td><input name="part_number" type="text"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset"><input onClick="this.form.submit.value = this.value;" name="_submit" type="submit" value="Update"><input onClick="this.form.submit.value = this.value;" name="_submit" type="submit" value="Delete"><input onClick="this.form.submit.value = this.value;" name="_submit" type="submit" value="Cancel"></center></td></tr></table>
</form>),
    },

    {
        # max it out, baby
        opt => { fields => [qw/supply demand/], values => { supply => [qw/1 2 3 4 5/], demand => [qw/6 7 8 9 0/] },
                 method => 'PUT', title => 'Econ 101', action => '/nowhere.cgi', header => 1, name => 'econ',
                 font   => 'arial,helvetica', fieldtype => 'select' },
        res => q(Content-type: text/html

<html><head><title>Econ 101</title></head><body bgcolor="white"><font face="arial,helvetica"><h3>Econ 101</h3>
<form action="/nowhere.cgi" method="PUT" name="econ"><input name="_submitted_econ" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left"><font face="arial,helvetica">Supply</td><td><font face="arial,helvetica"><select multiple name="supply" type="select"><option selected value="1">1</option><option selected value="2">2</option><option selected value="3">3</option><option selected value="4">4</option><option selected value="5">5</option></select></td></tr>
<tr valign="middle"><td align="left"><font face="arial,helvetica">Demand</td><td><font face="arial,helvetica"><select multiple name="demand" type="select"><option selected value="6">6</option><option selected value="7">7</option><option selected value="8">8</option><option selected value="9">9</option><option selected value="0">0</option></select></td></tr>
<tr valign="middle"><td colspan="2"><font face="arial,helvetica"><center><input name="_reset" type="reset" value="Reset"><input name="_submit" type="submit" value="Submit"></center></td></tr></table>
</form></body></html>
),
    },

    {
        opt => { fields => [qw/db:name db:type db:tab ux:user ux:name/], static => 1 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><table>
<tr valign="middle"><td align="left">Db Name</td><td><input name="db:name" type="hidden"></td></tr>
<tr valign="middle"><td align="left">Db Type</td><td><input name="db:type" type="hidden"></td></tr>
<tr valign="middle"><td align="left">Db Tab</td><td><input name="db:tab" type="hidden"></td></tr>
<tr valign="middle"><td align="left">Ux User</td><td><input name="ux:user" type="hidden"></td></tr>
<tr valign="middle"><td align="left">Ux Name</td><td><input name="ux:name" type="hidden"></td></tr>
<tr valign="middle"><td colspan="2"><center></center></td></tr></table>
</form>),
    },

    {
        # single-line search thing ala Yahoo!
        opt => { fields => 'search', submit => 'Go', reset => 0 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value="">Search <input name="search" type="text"> <input name="_submit" type="submit" value="Go"> </form>),
    },

    {
        opt => { fields => [qw/hostname domain/], header => 1, keepextras => 1,
                 values => [qw/localhost localdomain/],
                 validate => {hostname => 'HOST', domain => 'DOMAIN'},
                },
        res => q(Content-type: text/html

<html><head><title>00generate</title>
<script language="JavaScript1.2"><!-- hide from old browsers
function validate (form) {
    // standard text, hidden, password, or textarea box
    var hostname = form.elements['hostname'].value;
    if ( (! hostname.match(/^[a-zA-Z0-9][-a-zA-Z0-9]*$/)) ) {
        alert('Error: You did not enter a valid value for the "Hostname" field');
        return false;
    }
    // standard text, hidden, password, or textarea box
    var domain = form.elements['domain'].value;
    if ( (! domain.match(/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) ) {
        alert('Error: You did not enter a valid value for the "Domain" field');
        return false;
    }
    return true;  // all checked ok
}
//-->
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p></head><body bgcolor="white"><h3>00generate</h3>
Fields shown in <b>bold</b> are required.<form action="00generate.t" method="GET" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1"><input name="_sessionid" type="hidden" value=""><input name="ticket" type="hidden" value="111"><input name="user" type="hidden" value="pete"><input name="replacement" type="hidden" value="TRUE"><table>
<tr valign="middle"><td align="left"><b>Hostname</b></td><td><input name="hostname" type="text" value="localhost"></td></tr>
<tr valign="middle"><td align="left"><b>Domain</b></td><td><input name="domain" type="text" value="localdomain"></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset"><input name="_submit" type="submit" value="Submit"></center></td></tr></table>
</form></body></html>
),
    },

);

# Cycle thru and try it out
for (@test) {
    my $form = CGI::FormBuilder->new( %{ $_->{opt} } );
    while(my($f,$o) = each %{$_->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }
    # skip all tests on non-UNIX platforms because of fucking CRLF
    skip($NOT_UNIX, $form->render, $_->{res});
}

