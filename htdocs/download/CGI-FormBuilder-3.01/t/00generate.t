#!/usr/bin/perl -I.

use strict;
use vars qw($TESTING $DEBUG);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 20 }

# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk';

# egads this part is annoying due to line disciplines
my $h = "Content-Type: text/html; charset=ISO-8859-1\n\n";

use CGI::FormBuilder;

# What options we want to use, and what we expect to see
my @test = (
    #1
    {
        opt => { fields => [qw/name email/], sticky => 0 },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Name</td><td align="left"><input id="name" name="name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Email</td><td align="left"><input id="email" name="email" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
)
    },

    #2
    {
        opt => { fields => [qw/Upper Case/], values => { Upper => 1, Case => 0 } },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Upper</td><td align="left"><input id="Upper" name="Upper" type="text" value="1" /></td></tr>
<tr valign="middle"><td align="left">Case</td><td align="left"><input id="Case" name="Case" type="text" value="0" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #3
    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', reset => 0 },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">First Name</td><td align="left"><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td align="left"><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Update" /></td></tr>
</table></form>
),
    },

    #4
    {
        opt => { fields => [qw/first_name last_name/], submit => 'Update', 
                 reset => 0, header => 1, body => {bgcolor => 'black'} },
        res => $h . q(<html><head><title>00generate</title></head>
<body bgcolor="black"><h3>00generate</h3><form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">First Name</td><td align="left"><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td align="left">Last Name</td><td align="left"><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Update" /></td></tr>
</table></form></body></html>
),
    },

    #5
    {
        opt => { fields => {first_name => 'Nate', email => 'nate@wiger.org' },
                 validate => {email => 'EMAIL'}, required => [qw/first_name/], sticky => 0 },
        res => q(<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript><p>Fields that are <b>highlighted</b> are required.</p><form action="00generate.t" method="GET" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Email</td><td align="left"><input id="email" name="email" type="text" value="nate@wiger.org" /></td></tr>
<tr valign="middle"><td align="left"><b>First Name</b></td><td align="left"><input id="first_name" name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #6
    {
        # utilize our query_string to test stickiness
        opt => { fields => [qw/ticket user part_number/], method => 'POST', keepextras => 1,
                 validate => { ticket => '/^\d+$/' }, submit => [qw/Update Delete Cancel/],
                },
        res => q(<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript><p>Fields that are <b>highlighted</b> are required.</p><form action="00generate.t" method="POST" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><input id="replacement" name="replacement" type="hidden" value="TRUE" /><input id="action" name="action" type="hidden" value="Unsubscribe" /><input id="name" name="name" type="hidden" value="Pete Peteson" /><input id="email" name="email" type="hidden" value="pete@peteson.com" /><input id="extra" name="extra" type="hidden" value="junk" /><table border="0">
<tr valign="middle"><td align="left"><b>Ticket</b></td><td align="left"><input id="ticket" name="ticket" type="text" value="111" /></td></tr>
<tr valign="middle"><td align="left">User</td><td align="left"><input id="user" name="user" type="text" value="pete" /></td></tr>
<tr valign="middle"><td align="left">Part Number</td><td align="left"><input id="part_number" name="part_number" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Delete" /><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Cancel" /></td></tr>
</table></form>
),
    },

    #7
    {
        # max it out, baby
        opt => { fields => [qw/supply demand/],
                 options => { supply => [0..9], demand => [0..9] },
                 values  => { supply => [0..4], demand => [5..9] },
                 method => 'PUT', title => 'Econ 101', action => '/nowhere.cgi', header => 1, name => 'econ',
                 font   => 'arial,helvetica', fieldtype => 'select' },
        res => $h . q(<html><head><title>Econ 101</title></head>
<body bgcolor="white"><font face="arial,helvetica"><h3>Econ 101</h3><form action="/nowhere.cgi" id="econ" method="PUT" name="econ"><input id="_submitted_econ" name="_submitted_econ" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left"><font face="arial,helvetica">Supply</font></td><td align="left"><font face="arial,helvetica"><select id="supply" multiple="multiple" name="supply"><option selected="selected" value="0">0</option><option selected="selected" value="1">1</option><option selected="selected" value="2">2</option><option selected="selected" value="3">3</option><option selected="selected" value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option></select></font></td></tr>
<tr valign="middle"><td align="left"><font face="arial,helvetica">Demand</font></td><td align="left"><font face="arial,helvetica"><select id="demand" multiple="multiple" name="demand"><option value="0">0</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option selected="selected" value="5">5</option><option selected="selected" value="6">6</option><option selected="selected" value="7">7</option><option selected="selected" value="8">8</option><option selected="selected" value="9">9</option></select></font></td></tr>
<tr valign="middle"><td align="center" colspan="2"><font face="arial,helvetica"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></font></td></tr>
</table></form></font></body></html>
),
    },

    #8
    {
        opt => { fields => [qw/db:name db:type db:tab ux:user ux:name/], static => 1 },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Db Name</td><td align="left"><input id="db:name" name="db:name" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Db Type</td><td align="left"><input id="db:type" name="db:type" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Db Tab</td><td align="left"><input id="db:tab" name="db:tab" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Ux User</td><td align="left"><input id="ux:user" name="ux:user" type="hidden" /></td></tr>
<tr valign="middle"><td align="left">Ux Name</td><td align="left"><input id="ux:name" name="ux:name" type="hidden" /></td></tr>
</table></form>
),
    },

    #9
    {
        # single-line search thing ala Yahoo!
        opt => { fields => 'search', submit => 'Go', reset => 0, table => 0 },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" />
Search <input id="search" name="search" type="text" /> <input id="_submit" name="_submit" type="submit" value="Go" /></form>
),
    },

    #10
    {
        opt => { fields => [qw/hostname domain/], header => 1,
                 keepextras => [qw/user ticket/],   # will come out (ticket,user) b/c of QUERY_STRING
                 values => [qw/localhost localdomain/],
                 validate => {hostname => 'HOST', domain => 'DOMAIN'},
                },
        res => $h . q(<html><head><title>00generate</title>
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript></head>
<body bgcolor="white"><h3>00generate</h3><p>Fields that are <b>highlighted</b> are required.</p><form action="00generate.t" method="GET" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><input id="ticket" name="ticket" type="hidden" value="111" /><input id="user" name="user" type="hidden" value="pete" /><table border="0">
<tr valign="middle"><td align="left"><b>Hostname</b></td><td align="left"><input id="hostname" name="hostname" type="text" value="localhost" /></td></tr>
<tr valign="middle"><td align="left"><b>Domain</b></td><td align="left"><input id="domain" name="domain" type="text" value="localdomain" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form></body></html>
),
    },
 
    #11
    {
        opt => { fields => {first_name => 'Nate', email => 'nate@wiger.org' },
                 validate => {email => 'EMAIL'}, required => [qw/first_name/],
                 javascript => 0 },
        res => q(<p>Fields that are <b>highlighted</b> are required.</p><form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Email</td><td align="left"><input id="email" name="email" type="text" value="pete@peteson.com" /></td></tr>
<tr valign="middle"><td align="left"><b>First Name</b></td><td align="left"><input id="first_name" name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),

    },

    #12
    {
        opt => { fields => [qw/earth wind fire water/], fieldattr => {type => 'TEXT'}},
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Earth</td><td align="left"><input id="earth" name="earth" type="text" /></td></tr>
<tr valign="middle"><td align="left">Wind</td><td align="left"><input id="wind" name="wind" type="text" /></td></tr>
<tr valign="middle"><td align="left">Fire</td><td align="left"><input id="fire" name="fire" type="text" /></td></tr>
<tr valign="middle"><td align="left">Water</td><td align="left"><input id="water" name="water" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #13
    {
        opt => { fields => [qw/earth wind fire water/],
                 options => { wind => [qw/<Slow> <Medium> <Fast>/], 
                              fire => [qw/&&MURDEROUS" &&HOT" &&WARM" &&COLD" &&CHILLY" &&OUT"/],
                            },
                 values => { water => '>>&c0ld&<<', earth => 'Wind >>' },
               },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Earth</td><td align="left"><input id="earth" name="earth" type="text" value="Wind &gt;&gt;" /></td></tr>
<tr valign="middle"><td align="left">Wind</td><td align="left"><input id="wind_&lt;Slow&gt;" name="wind" type="radio" value="&lt;Slow&gt;" /> <label for="wind_&lt;Slow&gt;">&lt;Slow&gt;</label> <input id="wind_&lt;Medium&gt;" name="wind" type="radio" value="&lt;Medium&gt;" /> <label for="wind_&lt;Medium&gt;">&lt;Medium&gt;</label> <input id="wind_&lt;Fast&gt;" name="wind" type="radio" value="&lt;Fast&gt;" /> <label for="wind_&lt;Fast&gt;">&lt;Fast&gt;</label> </td></tr>
<tr valign="middle"><td align="left">Fire</td><td align="left"><select id="fire" name="fire"><option value="">-select-</option><option value="&amp;&amp;MURDEROUS&quot;">&amp;&amp;MURDEROUS&quot;</option><option value="&amp;&amp;HOT&quot;">&amp;&amp;HOT&quot;</option><option value="&amp;&amp;WARM&quot;">&amp;&amp;WARM&quot;</option><option value="&amp;&amp;COLD&quot;">&amp;&amp;COLD&quot;</option><option value="&amp;&amp;CHILLY&quot;">&amp;&amp;CHILLY&quot;</option><option value="&amp;&amp;OUT&quot;">&amp;&amp;OUT&quot;</option></select></td></tr>
<tr valign="middle"><td align="left">Water</td><td align="left"><input id="water" name="water" type="text" value="&gt;&gt;&amp;c0ld&amp;&lt;&lt;" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #14 - option maxing
    {
        opt => { fields => [qw/multiopt/], values => {multiopt => [1,2,6,9]},
                 options => { multiopt => [ 
                                 [1 => 'One'],   {2 => 'Two'},   {3 => 'Three'},
                                 {7 => 'Seven'}, [8 => 'Eight'], [9 => 'Nine'],
                                 {4 => 'Four'},  {5 => 'Five'},  [6 => 'Six'],
                                 [10 => 'Ten']
                               ],
                            },
                  sortopts => 'NUM',
                },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Multiopt</td><td align="left"><select id="multiopt" multiple="multiple" name="multiopt"><option selected="selected" value="1">One</option><option selected="selected" value="2">Two</option><option value="3">Three</option><option value="4">Four</option><option value="5">Five</option><option selected="selected" value="6">Six</option><option value="7">Seven</option><option value="8">Eight</option><option selected="selected" value="9">Nine</option><option value="10">Ten</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #15 - obscure features
    {
        opt => { fields => [qw/plain jane mane/],
                 nameopts => 1,
                 stylesheet => '/my/own/style.css',
                 styleclass => 'yo.',
                 body => {ignore => 'me'},
                 javascript => 0,
                 jsfunc => '// missing',
                 labels => {plain => 'AAA', jane => 'BBB'},
                 options => {mane => [qw/ratty nappy mr_happy/]},
                 selectnum => 0,
                 title => 'Bobby',
                 header => 1, 
                },
        res => q(Content-Type: text/html; charset=ISO-8859-1

<html><head><title>Bobby</title><link href="/my/own/style.css" rel="stylesheet" /></head>
<body ignore="me"><h3>Bobby</h3><form action="00generate.t" class="yo.form" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0" class="yo.table">
<tr class="yo.tr" valign="middle"><td align="left" class="yo.td">AAA</td><td align="left" class="yo.td"><input class="yo.text" id="plain" name="plain" type="text" /></td></tr>
<tr class="yo.tr" valign="middle"><td align="left" class="yo.td">BBB</td><td align="left" class="yo.td"><input class="yo.text" id="jane" name="jane" type="text" /></td></tr>
<tr class="yo.tr" valign="middle"><td align="left" class="yo.td">Mane</td><td align="left" class="yo.td"><select class="yo.select" id="mane" name="mane"><option value="">-select-</option><option value="ratty">Ratty</option><option value="nappy">Nappy</option><option value="mr_happy">Mr Happy</option></select></td></tr>
<tr class="yo.tr" valign="middle"><td align="center" class="yo.td" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form></body></html>
),
    },

    #16
    {
        opt => { fields => [qw/name email/], sticky => 0 },
        mod => { name => {comment => 'Hey buddy'}, email => {comment => 'No email >> address??'} },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Name</td><td align="left"><input id="name" name="name" type="text" /> Hey buddy</td></tr>
<tr valign="middle"><td align="left">Email</td><td align="left"><input id="email" name="email" type="text" /> No email >> address??</td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #17
    {
        opt => { fields => [qw/won too many/] },
        mod => { won  => { jsclick => 'taco_punch = 1'},
                 too  => { options => [0..2], jsclick => 'this.salami.value = "delicious"'},
                 many => { options => [0..9], jsclick => 'this.ham.value = "it\'s a pig, man!"'},
               },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Won</td><td align="left"><input id="won" name="won" onChange="taco_punch = 1" type="text" /></td></tr>
<tr valign="middle"><td align="left">Too</td><td align="left"><input id="too_0" name="too" onClick="this.salami.value = &quot;delicious&quot;" type="radio" value="0" /> <label for="too_0">0</label> <input id="too_1" name="too" onClick="this.salami.value = &quot;delicious&quot;" type="radio" value="1" /> <label for="too_1">1</label> <input id="too_2" name="too" onClick="this.salami.value = &quot;delicious&quot;" type="radio" value="2" /> <label for="too_2">2</label> </td></tr>
<tr valign="middle"><td align="left">Many</td><td align="left"><select id="many" name="many" onChange="this.ham.value = &quot;it's a pig, man!&quot;"><option value="">-select-</option><option value="0">0</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #18
    {
        opt => { fields => [qw/refsort/] },
        mod => { refsort => { sortopts => \&refsort, 
                 options => [qw/99 9 8 83 7 73 6 61 66 5 4 104 3 2 10 1 101/] } },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left">Refsort</td><td align="left"><select id="refsort" name="refsort"><option value="">-select-</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="61">61</option><option value="66">66</option><option value="73">73</option><option value="83">83</option><option value="99">99</option><option value="101">101</option><option value="104">104</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    # 19 - table attr and field columns
    {
        opt => { fields => [qw/a b c/],
                 table  => { border => 1 },
                 td => { taco => 'beef', align => 'right' },
                 tr => { valign => 'top' },
                 th => { ignore => 'this' },
                 selectnum => 10,
                },
        mod => { a => { options => [0..3], columns => 2, value => [1..2] },
                 b => { options => [4..9], columns => 3, comment => "Please fill these in" },
               },
        res => q(<form action="00generate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="1">
<tr valign="top"><td align="right" taco="beef">A</td><td align="left" taco="beef"><table border="0"><tr>
<td><input id="a_0" name="a" type="checkbox" value="0" /> <label for="a_0">0</label> </td><td><input checked="checked" id="a_1" name="a" type="checkbox" value="1" /> <label for="a_1">1</label> </td></tr><tr>
<td><input checked="checked" id="a_2" name="a" type="checkbox" value="2" /> <label for="a_2">2</label> </td><td><input id="a_3" name="a" type="checkbox" value="3" /> <label for="a_3">3</label> </td></tr></table></td></tr>
<tr valign="top"><td align="right" taco="beef">B</td><td align="left" taco="beef"><table border="0"><tr>
<td><input id="b_4" name="b" type="radio" value="4" /> <label for="b_4">4</label> </td><td><input id="b_5" name="b" type="radio" value="5" /> <label for="b_5">5</label> </td><td><input id="b_6" name="b" type="radio" value="6" /> <label for="b_6">6</label> </td></tr><tr>
<td><input id="b_7" name="b" type="radio" value="7" /> <label for="b_7">7</label> </td><td><input id="b_8" name="b" type="radio" value="8" /> <label for="b_8">8</label> </td><td><input id="b_9" name="b" type="radio" value="9" /> <label for="b_9">9</label> </td></tr></table> Please fill these in</td></tr>
<tr valign="top"><td align="right" taco="beef">C</td><td align="left" taco="beef"><input id="c" name="c" type="text" /></td></tr>
<tr valign="top"><td align="center" colspan="2" taco="beef"><input id="_reset" name="_reset" type="reset" value="Reset" /><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    # 20 - order.cgi from manpage (big)
    {
        opt => { method => 'POST',
                 fields => [
                   qw(first_name last_name
                      email send_me_emails
                      address state zipcode
                      credit_card expiration)
                 ],

                 header => 1,
                 title  => 'Finalize Your Order',
                 submit => ['Place Order', 'Cancel'],
                 reset  => 0,

                 validate => {
                     email   => 'EMAIL',
                     zipcode => 'ZIPCODE',
                     credit_card => 'CARD',
                     expiration  => 'MMYY',
                 },
                 required => 'ALL',
                 jsfunc => <<EOJS,
    // skip validation if they clicked "Cancel"
    if (this._submit.value == 'Cancel') return true;
EOJS
         },
         mod => { state => {
                     options => [qw(JS IW KS UW JS UR EE DJ HI YK NK TY)],
                     sortopts=> 'NAME'
                 },
                 send_me_emails => {
                     options => [[1 => 'Yes'], [0 => 'No']],
                     value   => 0,   # "No"
                 },
             },
         res => $h . q(<html><head><title>Finalize Your Order</title>
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // skip validation if they clicked "Cancel"
    if (this._submit.value == 'Cancel') return true;
    // standard text, hidden, password, or textarea box
    var first_name = form.elements['first_name'].value;
    if ( ((! first_name && first_name != 0) || first_name === "")) {
        alertstr += '- You must enter a valid value for the "First Name" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var last_name = form.elements['last_name'].value;
    if ( ((! last_name && last_name != 0) || last_name === "")) {
        alertstr += '- You must enter a valid value for the "Last Name" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var email = form.elements['email'].value;
    if ( (! email.match(/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) ) {
        alertstr += '- You must enter a valid value for the "Email" field\n';
        invalid++;
    }
    // radio group or checkboxes
    var send_me_emails = '';
    if (form.elements['send_me_emails'][0]) {
        for (var loop = 0; loop < form.elements['send_me_emails'].length; loop++) {
            if (form.elements['send_me_emails'][loop].checked) {
                send_me_emails = form.elements['send_me_emails'][loop].value;
            }
        }
    } else {
        if (form.elements['send_me_emails'].checked) {
            send_me_emails = form.elements['send_me_emails'].value;
        }
    }
    if ( ((! send_me_emails && send_me_emails != 0) || send_me_emails === "")) {
        alertstr += '- You must choose an option for the "Send Me Emails" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var address = form.elements['address'].value;
    if ( ((! address && address != 0) || address === "")) {
        alertstr += '- You must enter a valid value for the "Address" field\n';
        invalid++;
    }
    // select list: always assume it's multiple to get all values
    var selected_state = 0;
    for (var loop = 0; loop < form.elements['state'].options.length; loop++) {
        if (form.elements['state'].options[loop].selected) {
            var state = form.elements['state'].options[loop].value;
            selected_state++;
            if ( ((! state && state != 0) || state === "")) {
                alertstr += '- You must choose an option for the "State" field\n';
                invalid++;
            }
        }
    } // close for loop;
    if (! selected_state) {
        alertstr += '- You must choose an option for the "State" field\n';
        invalid++;
    }

    // standard text, hidden, password, or textarea box
    var zipcode = form.elements['zipcode'].value;
    if ( (! zipcode.match(/^\d{5}$|^\d{5}\-\d{4}$/)) ) {
        alertstr += '- You must enter a valid value for the "Zipcode" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var credit_card = form.elements['credit_card'].value;
    if ( (! credit_card.match(/^\d{4}[\- ]?\d{4}[\- ]?\d{4}[\- ]?\d{4}$|^\d{4}[\- ]?\d{6}[\- ]?\d{5}$/)) ) {
        alertstr += '- You must enter a valid value for the "Credit Card" field\n';
        invalid++;
    }
    // standard text, hidden, password, or textarea box
    var expiration = form.elements['expiration'].value;
    if ( (! expiration.match(/^(0?[1-9]|1[0-2])\/?[0-9]{2}$/)) ) {
        alertstr += '- You must enter a valid value for the "Expiration" field\n';
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript></head>
<body bgcolor="white"><h3>Finalize Your Order</h3><p>Fields that are <b>highlighted</b> are required.</p><form action="00generate.t" method="POST" onSubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" /><table border="0">
<tr valign="middle"><td align="left"><b>First Name</b></td><td align="left"><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td align="left"><b>Last Name</b></td><td align="left"><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td align="left"><b>Email</b></td><td align="left"><input id="email" name="email" type="text" value="pete@peteson.com" /></td></tr>
<tr valign="middle"><td align="left"><b>Send Me Emails</b></td><td align="left"><input id="send_me_emails_1" name="send_me_emails" type="radio" value="1" /> <label for="send_me_emails_1">Yes</label> <input checked="checked" id="send_me_emails_0" name="send_me_emails" type="radio" value="0" /> <label for="send_me_emails_0">No</label> </td></tr>
<tr valign="middle"><td align="left"><b>Address</b></td><td align="left"><input id="address" name="address" type="text" /></td></tr>
<tr valign="middle"><td align="left"><b>State</b></td><td align="left"><select id="state" name="state"><option value="">-select-</option><option value="DJ">DJ</option><option value="EE">EE</option><option value="HI">HI</option><option value="IW">IW</option><option value="JS">JS</option><option value="JS">JS</option><option value="KS">KS</option><option value="NK">NK</option><option value="TY">TY</option><option value="UR">UR</option><option value="UW">UW</option><option value="YK">YK</option></select></td></tr>
<tr valign="middle"><td align="left"><b>Zipcode</b></td><td align="left"><input id="zipcode" name="zipcode" type="text" /></td></tr>
<tr valign="middle"><td align="left"><b>Credit Card</b></td><td align="left"><input id="credit_card" name="credit_card" type="text" /></td></tr>
<tr valign="middle"><td align="left"><b>Expiration</b></td><td align="left"><input id="expiration" name="expiration" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Place Order" /><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Cancel" /></td></tr>
</table></form></body></html>
),
    },
);

sub refsort {
    $_[0] <=> $_[1]
}

# Perl is sick.
@test = @test[$ARGV[0] - 1] if @ARGV;

# Cycle thru and try it out
for (@test) {
    my $form = CGI::FormBuilder->new( %{ $_->{opt} }, debug => $DEBUG );
    while(my($f,$o) = each %{$_->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }
    # just compare the output of render with what's expected
    my $ok = ok($form->render, $_->{res});

    if (! $ok && $ENV{LOGNAME} eq 'nwiger') {
        open(O, ">/tmp/fb.1.out");
        print O $_->{res};
        close O;

        open(O, ">/tmp/fb.2.out");
        print O $form->render;
        close O;

        system "diff /tmp/fb.1.out /tmp/fb.2.out";
        exit 1;
    }
}
