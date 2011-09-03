#!/usr/bin/perl

use strict;
use vars qw($TESTING);
$TESTING = 1;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 13 }

# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE';

# egads this part is annoying
use CGI 'header';
my $h = header();

use CGI::FormBuilder;

# What options we want to use, and what we expect to see
my @test = (
    {
        opt => { fields => [qw/name email/] },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Name</td><td><input name="name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Email</td><td><input name="email" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>)
    },

    {
        opt => { fields => [qw/Upper Case/], values => { Upper => 1, Case => 0 } },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Upper</td><td><input name="Upper" type="text" value="1" /></td></tr>
<tr valign="middle"><td align="left">Case</td><td><input name="Case" type="text" value="0" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>),
    },

    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', reset => 0 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">First Name</td><td><input name="first_name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td><input name="last_name" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_submit" type="submit" value="Update" /></center></td></tr></table>
</form>),
    },

    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', 
                 reset => 0, header => 1, body => {bgcolor => 'black'} },
        res => $h . q(<html><head><title>00generate</title></head><body bgcolor="black"><h3>00generate</h3><form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">First Name</td><td><input name="first_name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td><input name="last_name" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_submit" type="submit" value="Update" /></center></td></tr></table>
</form></body></html>
),
    },

    {
        opt => { fields => {first_name => 'Nate', email => 'nate@wiger.org' },
                 validate => {email => 'EMAIL'}, required => [qw/first_name/] },
        res => q(
<script language="JavaScript1.3"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // standard text, hidden, password, or textarea box
    var email = form.elements['email'].value;
    if ((email || email === 0) &&
        (! email.match(/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) ) {
        alertstr += '- You must enter a valid value for the "Email" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var first_name = form.elements['first_name'].value;
    if ( ((! first_name && first_name != 0) || first_name === "")) {
        alertstr += '- You must enter a valid value for the "First Name" field\n';
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
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p><p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="GET" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Email</td><td><input name="email" type="text" value="nate@wiger.org" /> <font size="-1">(name@host.domain)</font></td></tr>
<tr valign="middle"><td align="left"><b>First Name</b></td><td><input name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>),
    },

    {
        # utilize our query_string to test stickiness
        opt => { fields => [qw/ticket user part_number/], method => 'POST', keepextras => 1,
                 validate => { ticket => '/^\d+$/' }, submit => [qw/Update Delete Cancel/],
                },
        res => q(
<script language="JavaScript1.3"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // standard text, hidden, password, or textarea box
    var ticket = form.elements['ticket'].value;
    if ( (! ticket.match(/^\d+$/)) ) {
        alertstr += '- You must enter a valid value for the "Ticket" field\n';
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
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p><p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="POST" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><input name="replacement" type="hidden" value="TRUE" /><table>
<tr valign="middle"><td align="left"><b>Ticket</b></td><td><input name="ticket" type="text" value="111" /></td></tr>
<tr valign="middle"><td align="left">User</td><td><input name="user" type="text" value="pete" /></td></tr>
<tr valign="middle"><td align="left">Part Number</td><td><input name="part_number" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Update" /><input name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Delete" /><input name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Cancel" /></center></td></tr></table>
</form>),
    },

    {
        # max it out, baby
        opt => { fields => [qw/supply demand/],
                 options => { supply => [0..9], demand => [0..9] },
                 values  => { supply => [0..4], demand => [5..9] },
                 method => 'PUT', title => 'Econ 101', action => '/nowhere.cgi', header => 1, name => 'econ',
                 font   => 'arial,helvetica', fieldtype => 'select' },
        res => $h . q(<html><head><title>Econ 101</title></head><body bgcolor="white"><font face="arial,helvetica"><h3>Econ 101</h3><form action="/nowhere.cgi" method="PUT" name="econ"><input name="_submitted_econ" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left"><font face="arial,helvetica">Supply</td><td><font face="arial,helvetica"><select multiple="multiple" name="supply"><option selected="selected" value="0">0</option><option selected="selected" value="1">1</option><option selected="selected" value="2">2</option><option selected="selected" value="3">3</option><option selected="selected" value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option></select></td></tr>
<tr valign="middle"><td align="left"><font face="arial,helvetica">Demand</td><td><font face="arial,helvetica"><select multiple="multiple" name="demand"><option value="0">0</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option selected="selected" value="5">5</option><option selected="selected" value="6">6</option><option selected="selected" value="7">7</option><option selected="selected" value="8">8</option><option selected="selected" value="9">9</option></select></td></tr>
<tr valign="middle"><td colspan="2"><font face="arial,helvetica"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form></body></html>
),
    },

    {
        opt => { fields => [qw/db:name db:type db:tab ux:user ux:name/], static => 1 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Db Name</td><td><input name="db:name" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Db Type</td><td><input name="db:type" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Db Tab</td><td><input name="db:tab" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Ux User</td><td><input name="ux:user" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Ux Name</td><td><input name="ux:name" type="hidden" /></td></tr>
<tr valign="middle"><td colspan="2"><center></center></td></tr></table>
</form>),
    },

    {
        # single-line search thing ala Yahoo!
        opt => { fields => 'search', submit => 'Go', reset => 0 },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" />Search <input name="search" type="text" /> <input name="_submit" type="submit" value="Go" /> </form>),
    },

    {
        opt => { fields => [qw/hostname domain/], header => 1, keepextras => 1,
                 values => [qw/localhost localdomain/],
                 validate => {hostname => 'HOST', domain => 'DOMAIN'},
                },
        res => $h . q(<html><head><title>00generate</title>
<script language="JavaScript1.3"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // standard text, hidden, password, or textarea box
    var hostname = form.elements['hostname'].value;
    if ( (! hostname.match(/^[a-zA-Z0-9][-a-zA-Z0-9]*$/)) ) {
        alertstr += '- You must enter a valid value for the "Hostname" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var domain = form.elements['domain'].value;
    if ( (! domain.match(/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) ) {
        alertstr += '- You must enter a valid value for the "Domain" field\n';
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
</script><noscript><font color="red"><b>Please enable JavaScript or use a newer browser</b></font></noscript><p></head><body bgcolor="white"><h3>00generate</h3><p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="GET" onSubmit="return validate(this);"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><input name="ticket" type="hidden" value="111" /><input name="user" type="hidden" value="pete" /><input name="replacement" type="hidden" value="TRUE" /><table>
<tr valign="middle"><td align="left"><b>Hostname</b></td><td><input name="hostname" type="text" value="localhost" /> <font size="-1">(valid hostname)</font></td></tr>
<tr valign="middle"><td align="left"><b>Domain</b></td><td><input name="domain" type="text" value="localdomain" /> <font size="-1">(DNS domain)</font></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form></body></html>
),
    },
    {
        opt => { fields => {first_name => 'Nate', email => 'nate@wiger.org' },
                 validate => {email => 'EMAIL'}, required => [qw/first_name/],
                 javascript => 0 },
        res => q(<p>Fields shown in <b>bold</b> are required.<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Email</td><td><input name="email" type="text" value="nate@wiger.org" /> <font size="-1">(name@host.domain)</font></td></tr>
<tr valign="middle"><td align="left"><b>First Name</b></td><td><input name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>),

    },

    {
        opt => { fields => [qw/earth wind fire water/], fieldattr => {type => 'TEXT'}},
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Earth</td><td><input name="earth" type="text" /></td></tr>
<tr valign="middle"><td align="left">Wind</td><td><input name="wind" type="text" /></td></tr>
<tr valign="middle"><td align="left">Fire</td><td><input name="fire" type="text" /></td></tr>
<tr valign="middle"><td align="left">Water</td><td><input name="water" type="text" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>),
    },

    {
        opt => { fields => [qw/earth wind fire water/], 
                 options => { wind => [qw/<Slow> <Medium> <Fast>/], 
                              fire => [qw/&&MURDEROUS" &&HOT" &&WARM" &&COLD" &&CHILLY" &&OUT"/],
                            },
                 values => { water => '>>&c0ld&<<' },
                 labels => { earth => 'Earth =>', wind => 'Wind >>', fire => '"Fire"', water => '&Water&>>'},
               },
        res => q(<form action="00generate.t" method="GET"><input name="_submitted" type="hidden" value="1" /><input name="_sessionid" type="hidden" value="" /><table>
<tr valign="middle"><td align="left">Earth =&gt;</td><td><input name="earth" type="text" /></td></tr>
<tr valign="middle"><td align="left">Wind &gt;&gt;</td><td><input id="wind_&lt;Slow&gt;" name="wind" type="radio" value="&lt;Slow&gt;" /> <label for="wind_&lt;Slow&gt;">&lt;Slow&gt;</label> <input id="wind_&lt;Medium&gt;" name="wind" type="radio" value="&lt;Medium&gt;" /> <label for="wind_&lt;Medium&gt;">&lt;Medium&gt;</label> <input id="wind_&lt;Fast&gt;" name="wind" type="radio" value="&lt;Fast&gt;" /> <label for="wind_&lt;Fast&gt;">&lt;Fast&gt;</label> </td></tr>
<tr valign="middle"><td align="left">&quot;Fire&quot;</td><td><select name="fire"><option value="">-select-</option><option value="&amp;&amp;MURDEROUS&quot;">&amp;&amp;MURDEROUS&quot;</option><option value="&amp;&amp;HOT&quot;">&amp;&amp;HOT&quot;</option><option value="&amp;&amp;WARM&quot;">&amp;&amp;WARM&quot;</option><option value="&amp;&amp;COLD&quot;">&amp;&amp;COLD&quot;</option><option value="&amp;&amp;CHILLY&quot;">&amp;&amp;CHILLY&quot;</option><option value="&amp;&amp;OUT&quot;">&amp;&amp;OUT&quot;</option></select></td></tr>
<tr valign="middle"><td align="left">&amp;Water&amp;&gt;&gt;</td><td><input name="water" type="text" value="&gt;&gt;&amp;c0ld&amp;&lt;&lt;" /></td></tr>
<tr valign="middle"><td colspan="2"><center><input name="_reset" type="reset" value="Reset" /><input name="_submit" type="submit" value="Submit" /></center></td></tr></table>
</form>),
    },
);

# Cycle thru and try it out
for (@test) {
    my $form = CGI::FormBuilder->new( %{ $_->{opt} } );
    while(my($f,$o) = each %{$_->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }
    # just compare the output of render with what's expected
    ok($form->render, $_->{res});

    if ($ENV{LOGNAME} eq 'nwiger') {
        open(O, ">/tmp/fb.1.out");
        print O $form->render;
        close O;

        open(O, ">/tmp/fb.2.out");
        print O $_->{res};
        close O;

        system "diff /tmp/fb.1.out /tmp/fb.2.out";
        exit if $?;
    }
}

