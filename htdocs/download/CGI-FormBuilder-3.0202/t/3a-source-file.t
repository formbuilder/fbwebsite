#!/usr/bin/perl -I.

use strict;
use vars qw($TESTING $DEBUG);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN {
    my $numtests = 20;

    plan tests => $numtests;

    # success if we said NOTEST
    if ($ENV{NOTEST}) {
        ok(1) for 1..$numtests;
        exit;
    }
}


# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE&action=Unsubscribe&name=Pete+Peteson&email=pete%40peteson.com&extra=junk';

use CGI 'header';
use CGI::FormBuilder;
use CGI::FormBuilder::Source::File;

# egads this part is annoying due to line disciplines
my $h = header();

# For testing sortopts in test 18
sub refsort {
    $_[0] <=> $_[1]
}
sub getopts {
    return [99,9,8,83,7,73,6,61,66,5,4,104,3,2,10,1,101];
}

# What options we want to use, and what we expect to see
my @test = (
    #1
    {
        str => '
fields:
    name
    email
sticky: 0
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Name</td><td><input id="name" name="name" type="text" /></td></tr>
<tr valign="middle"><td>Email</td><td><input id="email" name="email" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
)
    },

    #2
    {
        str => '
# comment
fields:
    Upper:
        type: password
    Case
values:
    Upper: 1
    Case: 0
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Upper</td><td><input id="Upper" name="Upper" type="password" value="1" /></td></tr>
<tr valign="middle"><td>Case</td><td><input id="Case" name="Case" type="text" value="0" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #3
    {
        str => '
# test three
fields:

    first_name

        last_name

submit: Update

  reset: 0
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>First Name</td><td><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td>Last Name</td><td><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Update" /></td></tr>
</table></form>
),
    },

    #4
    {
        str => '
fields:
   first_name
    last_name:
        type: text
submit: Update
reset: 0
header: 1
body:
    bgcolor: black
',
        res => $h . q(<html><head><title>TEST</title></head>
<body bgcolor="black"><h3>TEST</h3><form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>First Name</td><td><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td>Last Name</td><td><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Update" /></td></tr>
</table></form></body></html>
),
    },

    #5
    {
        str => '
# rewritten fields hash
    # as a set of values
fields:
    email:
        required: 0

    first_name:
        required: 1

values:
     first_name: Nate
     email: nate@wiger.org

validate:
    email: EMAIL
sticky: 0
',
        res => q(<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // email: standard text, hidden, password, or textarea box
    var email = form.elements['email'].value;
    if (email != null && email != "" && ! email.match(/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) {
        alertstr += '- Invalid entry for the "Email" field\n';
        invalid++;
    }
    // first_name: standard text, hidden, password, or textarea box
    var first_name = form.elements['first_name'].value;
    if (first_name == null || first_name === "") {
        alertstr += '- Invalid entry for the "First Name" field\n';
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript><p>Fields that are <b>highlighted</b> are required.</p><form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Email</td><td><input id="email" name="email" type="text" value="nate@wiger.org" /></td></tr>
<tr valign="middle"><td><b>First Name</b></td><td><input id="first_name" name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #6
    {
        # utilize our query_string to test stickiness
        str => '
fields:
    ticket
    user
    part_number

method: POST
keepextras: 1

validate:
    ticket: /^\d+$/

submit: Update,Delete,Cancel
',
        res => q(<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // ticket: standard text, hidden, password, or textarea box
    var ticket = form.elements['ticket'].value;
    if (ticket == null || ! ticket.match(/^\d+$/)) {
        alertstr += '- Invalid entry for the "Ticket" field\n';
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
</script><noscript><p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p></noscript><p>Fields that are <b>highlighted</b> are required.</p><form action="TEST" method="POST" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="replacement" name="replacement" type="hidden" value="TRUE" /><input id="action" name="action" type="hidden" value="Unsubscribe" /><input id="name" name="name" type="hidden" value="Pete Peteson" /><input id="email" name="email" type="hidden" value="pete@peteson.com" /><input id="extra" name="extra" type="hidden" value="junk" /><table border="0">
<tr valign="middle"><td><b>Ticket</b></td><td><input id="ticket" name="ticket" type="text" value="111" /></td></tr>
<tr valign="middle"><td>User</td><td><input id="user" name="user" type="text" value="pete" /></td></tr>
<tr valign="middle"><td>Part Number</td><td><input id="part_number" name="part_number" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Delete" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Cancel" /></td></tr>
</table></form>
),
    },

    #7
    {
        # max it out, baby
        str => '
fields: supply, demand
options:
    supply: 0=A,1=B,2=C,3,4,5,6,7=D,8=E,9=F
    demand: 0=A,1=B,2=C,3,4,5,6,7=D,8=E,9=F

values:
    supply: 0,1,2,3,4
    demand: 5,6,7,8,9

method: PUT
title:  Econ 101
action: /nowhere.cgi
header: 1
name: econ
font: arial,helvetica,courier
fieldtype: select
',
        res => $h . <<EOH
<html><head><title>Econ 101</title></head>
<body bgcolor="white"><font face="arial,helvetica,courier"><h3>Econ 101</h3><form action="TEST" id="econ" method="PUT" name="econ"><input id="_submitted_econ" name="_submitted_econ" type="hidden" value="1" /><table border="0">
<tr id="econ_supply_row" valign="middle"><td id="econ_supply_label"><font face="arial,helvetica,courier">Supply</font></td><td id="econ_supply_input"><font face="arial,helvetica,courier"><select id="supply" multiple="multiple" name="supply"><option selected="selected" value="0">A</option><option selected="selected" value="1">B</option><option selected="selected" value="2">C</option><option selected="selected" value="3">3</option><option selected="selected" value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">D</option><option value="8">E</option><option value="9">F</option></select></font></td></tr>
<tr id="econ_demand_row" valign="middle"><td id="econ_demand_label"><font face="arial,helvetica,courier">Demand</font></td><td id="econ_demand_input"><font face="arial,helvetica,courier"><select id="demand" multiple="multiple" name="demand"><option value="0">A</option><option value="1">B</option><option value="2">C</option><option value="3">3</option><option value="4">4</option><option selected="selected" value="5">5</option><option selected="selected" value="6">6</option><option selected="selected" value="7">D</option><option selected="selected" value="8">E</option><option selected="selected" value="9">F</option></select></font></td></tr>
<tr valign="middle"><td align="center" colspan="2"><font face="arial,helvetica,courier"><input id="econ_submit" name="_submit" type="submit" value="Submit" /></font></td></tr>
</table></form></font></body></html>
EOH
    },

    #8
    {
        str => '
fields: db:name,db:type,db:tab,ux:user,ux:name
static: Yip
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Db Name</td><td><input id="db:name" name="db:name" type="hidden" /></td></tr>
<tr valign="middle"><td>Db Type</td><td><input id="db:type" name="db:type" type="hidden" /></td></tr>
<tr valign="middle"><td>Db Tab</td><td><input id="db:tab" name="db:tab" type="hidden" /></td></tr>
<tr valign="middle"><td>Ux User</td><td><input id="ux:user" name="ux:user" type="hidden" /></td></tr>
<tr valign="middle"><td>Ux Name</td><td><input id="ux:name" name="ux:name" type="hidden" /></td></tr>
</table></form>
),
    },

    #9
    {
        # single-line search thing ala Yahoo!
        str => "fields: search \r\n submit: Go \n\r reset: 0 \r table: 0",
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" />
Search <input id="search" name="search" type="text" /> <input id="_submit" name="_submit" type="submit" value="Go" /></form>
),
    },

    #10
    {
        str => '
fields:
    hostname
  domain
header: 1

# will come out (ticket,user) b/c of QUERY_STRING
keepextras: user,ticket

values: localhost,localdomain
validate:
    hostname: HOST
  domain:           DOMAIN          
',
        res => $h . q(<html><head><title>TEST</title>
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // hostname: standard text, hidden, password, or textarea box
    var hostname = form.elements['hostname'].value;
    if (hostname == null || ! hostname.match(/^[a-zA-Z0-9][-a-zA-Z0-9]*$/)) {
        alertstr += '- Invalid entry for the "Hostname" field\n';
        invalid++;
    }
    // domain: standard text, hidden, password, or textarea box
    var domain = form.elements['domain'].value;
    if (domain == null || ! domain.match(/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) {
        alertstr += '- Invalid entry for the "Domain" field\n';
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
<body bgcolor="white"><h3>TEST</h3><p>Fields that are <b>highlighted</b> are required.</p><form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="user" name="user" type="hidden" value="pete" /><input id="ticket" name="ticket" type="hidden" value="111" /><table border="0">
<tr valign="middle"><td><b>Hostname</b></td><td><input id="hostname" name="hostname" type="text" value="localhost" /></td></tr>
<tr valign="middle"><td><b>Domain</b></td><td><input id="domain" name="domain" type="text" value="localdomain" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form></body></html>
),
    },
 
    #11
    {
        str => '
fields:
    email: 
        value: nate@wiger.org
    first_name:
        value: Nate

validate:
    email: EMAIL

required: first_name

javascript: 0
',
        res => q(<p>Fields that are <b>highlighted</b> are required.</p><form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Email</td><td><input id="email" name="email" type="text" value="pete@peteson.com" /></td></tr>
<tr valign="middle"><td><b>First Name</b></td><td><input id="first_name" name="first_name" type="text" value="Nate" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),

    },

    #12
    {
        str => '
fields: earth, wind, fire, water
fieldattr:
    type: TEXT
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Earth</td><td><input id="earth" name="earth" type="text" /></td></tr>
<tr valign="middle"><td>Wind</td><td><input id="wind" name="wind" type="text" /></td></tr>
<tr valign="middle"><td>Fire</td><td><input id="fire" name="fire" type="text" /></td></tr>
<tr valign="middle"><td>Water</td><td><input id="water" name="water" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #13
    {
        str => '
fields:
    earth
   wind
  fire
 water
notafield
options:
 wind: <Slow>, <Medium>, <Fast>
   fire: &&MURDEROUS", &&HOT", &&WARM", &&COLD", &&CHILLY", &&OUT"
values:
                            water: >>&c0ld&<<
                                                        earth: Wind >>
            fire: &&MURDEROUS", &&HOT"
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Earth</td><td><input id="earth" name="earth" type="text" value="Wind &gt;&gt;" /></td></tr>
<tr valign="middle"><td>Wind</td><td><input id="wind_&lt;Slow&gt;" name="wind" type="radio" value="&lt;Slow&gt;" /> <label for="wind_&lt;Slow&gt;">&lt;Slow&gt;</label> <input id="wind_&lt;Medium&gt;" name="wind" type="radio" value="&lt;Medium&gt;" /> <label for="wind_&lt;Medium&gt;">&lt;Medium&gt;</label> <input id="wind_&lt;Fast&gt;" name="wind" type="radio" value="&lt;Fast&gt;" /> <label for="wind_&lt;Fast&gt;">&lt;Fast&gt;</label> </td></tr>
<tr valign="middle"><td>Fire</td><td><select id="fire" multiple="multiple" name="fire"><option selected="selected" value="&amp;&amp;MURDEROUS&quot;">&amp;&amp;MURDEROUS&quot;</option><option selected="selected" value="&amp;&amp;HOT&quot;">&amp;&amp;HOT&quot;</option><option value="&amp;&amp;WARM&quot;">&amp;&amp;WARM&quot;</option><option value="&amp;&amp;COLD&quot;">&amp;&amp;COLD&quot;</option><option value="&amp;&amp;CHILLY&quot;">&amp;&amp;CHILLY&quot;</option><option value="&amp;&amp;OUT&quot;">&amp;&amp;OUT&quot;</option></select></td></tr>
<tr valign="middle"><td>Water</td><td><input id="water" name="water" type="text" value="&gt;&gt;&amp;c0ld&amp;&lt;&lt;" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #14 - option maxing
    {
        str => '
fields:
    multiopt

values: 
    multiopt: 1,2,6,9

options: 
    multiopt: 1 = One, 2 = Two , 3 = Three, 7 = Seven, 8 = Eight, 9 = Nine,
              4 = Four, 5 = Five,  6 = Six, 10 = Ten
sortopts: NUM,
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Multiopt</td><td><select id="multiopt" multiple="multiple" name="multiopt"><option selected="selected" value="1">One</option><option selected="selected" value="2">Two</option><option value="3">Three</option><option value="4">Four</option><option value="5">Five</option><option selected="selected" value="6">Six</option><option value="7">Seven</option><option value="8">Eight</option><option selected="selected" value="9">Nine</option><option value="10">Ten</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #15 - obscure features
    {
        str => '
fields: plain, jane,    mane
nameopts: 1

    # Style is important
   stylesheet: /my/own/style.css
   styleclass: yo.

body:
    ignore: me
javascript: 0
jsfunc:// missing
labels:
 plain:AAA
 jane: BBB
options:
 mane: ratty,nappy,mr_happy
selectnum: 0
title: Bobby
header: On
',
        res => $h . q(<html><head><title>Bobby</title><link href="/my/own/style.css" rel="stylesheet" /></head>
<body ignore="me"><h3>Bobby</h3><form action="TEST" class="yo.form" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0" class="yo.table">
<tr class="yo.tr" valign="middle"><td class="yo.td">AAA</td><td class="yo.td"><input class="yo.text" id="plain" name="plain" type="text" /></td></tr>
<tr class="yo.tr" valign="middle"><td class="yo.td">BBB</td><td class="yo.td"><input class="yo.text" id="jane" name="jane" type="text" /></td></tr>
<tr class="yo.tr" valign="middle"><td class="yo.td">Mane</td><td class="yo.td"><select class="yo.select" id="mane" name="mane"><option value="">-select-</option><option value="ratty">Ratty</option><option value="nappy">Nappy</option><option value="mr_happy">Mr Happy</option></select></td></tr>
<tr class="yo.tr" valign="middle"><td align="center" class="yo.td" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form></body></html>
),
    },

    #16
    {
        str => '
fields: 
   name:
        comment: Hey buddy
   email:
     comment: No email >> address??

sticky: 0
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Name</td><td><input id="name" name="name" type="text" /> Hey buddy</td></tr>
<tr valign="middle"><td>Email</td><td><input id="email" name="email" type="text" /> No email >> address??</td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #17
    {
        str => '
fields:
    won:
        jsclick: taco_punch = 1, taco_salad = "yummy"
    too:
        options: 0,1,2
        jsclick: this.salami.value = "delicious"
    many:
        options: 0,1,2,3,4,5,6,7,8,9
        jsclick: this.ham.value = "it\'s a pig, man!"
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Won</td><td><input id="won" name="won" onchange="taco_punch = 1, taco_salad = &quot;yummy&quot;" type="text" /></td></tr>
<tr valign="middle"><td>Too</td><td><input id="too_0" name="too" onclick="this.salami.value = &quot;delicious&quot;" type="radio" value="0" /> <label for="too_0">0</label> <input id="too_1" name="too" onclick="this.salami.value = &quot;delicious&quot;" type="radio" value="1" /> <label for="too_1">1</label> <input id="too_2" name="too" onclick="this.salami.value = &quot;delicious&quot;" type="radio" value="2" /> <label for="too_2">2</label> </td></tr>
<tr valign="middle"><td>Many</td><td><select id="many" name="many" onchange="this.ham.value = &quot;it's a pig, man!&quot;"><option value="">-select-</option><option value="0">0</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #18
    {
        str => '
fields:
    refsort:
      sortopts: \&refsort
     options:  \&getopts
',
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td>Refsort</td><td><select id="refsort" name="refsort"><option value="">-select-</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="61">61</option><option value="66">66</option><option value="73">73</option><option value="83">83</option><option value="99">99</option><option value="101">101</option><option value="104">104</option></select></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #19 - table attr and field columns
    {
        str => '
fields:
    a:
        options: 0,1,2,3
        columns: 2
        value: 1,2
    b:
        options: 4,5,6,7,8,9
        columns: 3
        comment: Please fill these in

    c

lalign: today

table:
    border: 1
td:
    taco: beef
    align: right
tr:
    valign: top
th: 
    ignore: this
selectnum: 10
',
        mod => { a => { options => [0..3], columns => 2, value => [1..2] },
                 b => { options => [4..9], columns => 3, comment => "Please fill these in" },
               },
        res => q(<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="1">
<tr valign="top"><td align="today" taco="beef">A</td><td align="right" taco="beef"><table border="0">
<tr><td><input id="a_0" name="a" type="checkbox" value="0" /></td><td><label for="a_0">0</label> </td><td><input checked="checked" id="a_1" name="a" type="checkbox" value="1" /></td><td><label for="a_1">1</label> </td></tr>
<tr><td><input checked="checked" id="a_2" name="a" type="checkbox" value="2" /></td><td><label for="a_2">2</label> </td><td><input id="a_3" name="a" type="checkbox" value="3" /></td><td><label for="a_3">3</label> </td></tr></table></td></tr>
<tr valign="top"><td align="today" taco="beef">B</td><td align="right" taco="beef"><table border="0">
<tr><td><input id="b_4" name="b" type="radio" value="4" /></td><td><label for="b_4">4</label> </td><td><input id="b_5" name="b" type="radio" value="5" /></td><td><label for="b_5">5</label> </td><td><input id="b_6" name="b" type="radio" value="6" /></td><td><label for="b_6">6</label> </td></tr>
<tr><td><input id="b_7" name="b" type="radio" value="7" /></td><td><label for="b_7">7</label> </td><td><input id="b_8" name="b" type="radio" value="8" /></td><td><label for="b_8">8</label> </td><td><input id="b_9" name="b" type="radio" value="9" /></td><td><label for="b_9">9</label> </td></tr></table> Please fill these in</td></tr>
<tr valign="top"><td align="today" taco="beef">C</td><td align="right" taco="beef"><input id="c" name="c" type="text" /></td></tr>
<tr valign="top"><td align="center" colspan="2" taco="beef"><input id="_submit" name="_submit" type="submit" value="Submit" /></td></tr>
</table></form>
),
    },

    #20 - order.cgi from manpage (big)
    {
        str => '
method: POST
fields:
  first_name
  last_name
  email
  send_me_emails:
     options: 1=Yes,0=No
     value: 0
  address
  state:
        options: JS,IW,KS,UW,JS,UR,EE,DJ,HI,YK,NK,TY
        sortopts: NAME
  zipcode
  credit_card
  expiration

header: 1,
title:  Finalize Your Order
submit: Place Order, Cancel
reset: 0

validate:
    email: EMAIL
    zipcode: ZIPCODE
  credit_card: CARD
   expiration: MMYY

messages:
    form_invalid_text:  You fucked up. Check it:
    form_required_text: Don\'t fuck up,it causes me work. Fuck,try again,   ok?
    js_invalid_input:   - Enter shit in the "%s" field

required: ALL
jsfunc: <<EOJS
    // skip validation if they clicked "Cancel"
    if (form._submit.value == \'Cancel\') return true;
EOJS
',
         res => $h . q(<html><head><title>Finalize Your Order</title>
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // skip validation if they clicked "Cancel"
    if (form._submit.value == 'Cancel') return true;
    // first_name: standard text, hidden, password, or textarea box
    var first_name = form.elements['first_name'].value;
    if (first_name == null || first_name === "") {
        alertstr += '- Enter shit in the "First Name" field\n';
        invalid++;
    }
    // last_name: standard text, hidden, password, or textarea box
    var last_name = form.elements['last_name'].value;
    if (last_name == null || last_name === "") {
        alertstr += '- Enter shit in the "Last Name" field\n';
        invalid++;
    }
    // email: standard text, hidden, password, or textarea box
    var email = form.elements['email'].value;
    if (email == null || ! email.match(/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/)) {
        alertstr += '- Enter shit in the "Email" field\n';
        invalid++;
    }
    // send_me_emails: radio group or multiple checkboxes
    var send_me_emails = null;
    var selected_send_me_emails = 0;
    for (var loop = 0; loop < form.elements['send_me_emails'].length; loop++) {
        if (form.elements['send_me_emails'][loop].checked) {
            send_me_emails = form.elements['send_me_emails'][loop].value;
            selected_send_me_emails++;
            if (send_me_emails == null || send_me_emails === "") {
                alertstr += '- Choose one of the "Send Me Emails" options\n';
                invalid++;
            }
        } // if
    } // for send_me_emails
    if (! selected_send_me_emails) {
        alertstr += '- Choose one of the "Send Me Emails" options\n';
        invalid++;
    }

    // address: standard text, hidden, password, or textarea box
    var address = form.elements['address'].value;
    if (address == null || address === "") {
        alertstr += '- Enter shit in the "Address" field\n';
        invalid++;
    }
    // state: select list, always assume it's multiple to get all values
    var state = null;
    var selected_state = 0;
    for (var loop = 0; loop < form.elements['state'].options.length; loop++) {
        if (form.elements['state'].options[loop].selected) {
            state = form.elements['state'].options[loop].value;
            selected_state++;
            if (state == null || state === "") {
                alertstr += '- Select an option from the "State" list\n';
                invalid++;
            }
        } // if
    } // for state
    if (! selected_state) {
        alertstr += '- Select an option from the "State" list\n';
        invalid++;
    }

    // zipcode: standard text, hidden, password, or textarea box
    var zipcode = form.elements['zipcode'].value;
    if (zipcode == null || ! zipcode.match(/^\d{5}$|^\d{5}\-\d{4}$/)) {
        alertstr += '- Enter shit in the "Zipcode" field\n';
        invalid++;
    }
    // credit_card: standard text, hidden, password, or textarea box
    var credit_card = form.elements['credit_card'].value;
    if (credit_card == null || ! credit_card.match(/^\d{4}[\- ]?\d{4}[\- ]?\d{4}[\- ]?\d{4}$|^\d{4}[\- ]?\d{6}[\- ]?\d{5}$/)) {
        alertstr += '- Enter shit in the "Credit Card" field\n';
        invalid++;
    }
    // expiration: standard text, hidden, password, or textarea box
    var expiration = form.elements['expiration'].value;
    if (expiration == null || ! expiration.match(/^(0?[1-9]|1[0-2])\/?[0-9]{2}$/)) {
        alertstr += '- Enter shit in the "Expiration" field\n';
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
<body bgcolor="white"><h3>Finalize Your Order</h3>Don't fuck up it causes me work. Fuck try again ok?<form action="TEST" method="POST" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" /><table border="0">
<tr valign="middle"><td><b>First Name</b></td><td><input id="first_name" name="first_name" type="text" /></td></tr>
<tr valign="middle"><td><b>Last Name</b></td><td><input id="last_name" name="last_name" type="text" /></td></tr>
<tr valign="middle"><td><b>Email</b></td><td><input id="email" name="email" type="text" value="pete@peteson.com" /></td></tr>
<tr valign="middle"><td><b>Send Me Emails</b></td><td><input id="send_me_emails_1" name="send_me_emails" type="radio" value="1" /> <label for="send_me_emails_1">Yes</label> <input checked="checked" id="send_me_emails_0" name="send_me_emails" type="radio" value="0" /> <label for="send_me_emails_0">No</label> </td></tr>
<tr valign="middle"><td><b>Address</b></td><td><input id="address" name="address" type="text" /></td></tr>
<tr valign="middle"><td><b>State</b></td><td><select id="state" name="state"><option value="">-select-</option><option value="DJ">DJ</option><option value="EE">EE</option><option value="HI">HI</option><option value="IW">IW</option><option value="JS">JS</option><option value="JS">JS</option><option value="KS">KS</option><option value="NK">NK</option><option value="TY">TY</option><option value="UR">UR</option><option value="UW">UW</option><option value="YK">YK</option></select></td></tr>
<tr valign="middle"><td><b>Zipcode</b></td><td><input id="zipcode" name="zipcode" type="text" /></td></tr>
<tr valign="middle"><td><b>Credit Card</b></td><td><input id="credit_card" name="credit_card" type="text" /></td></tr>
<tr valign="middle"><td><b>Expiration</b></td><td><input id="expiration" name="expiration" type="text" /></td></tr>
<tr valign="middle"><td align="center" colspan="2"><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Place Order" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Cancel" /></td></tr>
</table></form></body></html>
),
    },
);

# Perl is sick.
@test = @test[$ARGV[0] - 1] if @ARGV;

# Cycle thru and try it out
for (@test) {

    #my $source = CGI::FormBuilder::Source::File->new(debug => $DEBUG);
    #my %conf = $source->parse(\"$_->{str}");
    my %conf = (source => {type => 'File', source => \"$_->{str}"});
    $conf{action}  = 'TEST';

    my $form = CGI::FormBuilder->new(%conf);
    $form->{title} = 'TEST' unless $form->{title};

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
