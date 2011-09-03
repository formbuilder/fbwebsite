#!/usr/bin/perl -I.

use strict;
use vars qw($TESTING $DEBUG $SKIP);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN {
    my $numtests = 4;

    plan tests => $numtests;

    # try to load template engine so absent template does
    # not cause all tests to fail
    eval "require Text::Template";
    $SKIP = $@ ? 'skip: Text::Template not installed here' : 0;

    # success if we said NOTEST
    if ($ENV{NOTEST}) {
        ok(1) for 1..$numtests;
        exit;
    }
}


# Need to fake a request or else we stall
$ENV{REQUEST_METHOD} = 'GET';
$ENV{QUERY_STRING}   = 'ticket=111&user=pete&replacement=TRUE';

use CGI::FormBuilder;

# Create our template and store it in a scalarref
my $template = <<'EOT';
<html>
<title>User Info</title>
Please update your info and hit "Submit".
<% $jshead %>
<p>
<% $start %><% $state %>
Enter your name: <% $field{name}{field}.$field{name}{comment} %>
Select your <% $field{color}{label} %>: <select name="color" multiple>
<%  my $ret = '';
    for (@{$field{color}{options}}) {
        if (ref $_) {
            $ret .= qq(  <b><option VALUE="$_->[0]">$_->[1]</option></b>\n);
        } else {
            my $chk =  $_ eq $field{color}{value} ? 'selected="selected"' : '';
            $ret .= qq(  <option $chk value="$_">$_</option>\n);
        }
    }
    $ret;
%>
</select>
<%  my $ret = "$field{sex}{label} = ";
    for (@{$field{sex}{options}}) {
        $ret .= qq(<radio name="sex" value="$_->[0]">$_->[1]<br>);
    }
    $ret;
%>
FYI, your dress size is <% $field{size}{value}.$field{size}{comment} %><br>
<% $submit %>
<% $end %>
EOT

# What options we want to use, and what we expect to see
my @test = (
    {
        opt => { fields => [qw/name color/],
                 submit => 'No esta una button del resetto',
                 template => { type => 'Text', TYPE => 'STRING', template => $template, },
                 validate => { name => 'NAME' },
               },
        mod => { color => { options => [qw/red green blue/],
                            label => 'Best Color', value => 'red' },
                 size  => { value => 42 },
                 sex   => { options => [[M=>'Male'],[F=>'Female']] }
               },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // name: standard text, hidden, password, or textarea box
    var name = form.elements['name'].value;
    if (name == null || ! name.match(/^[a-zA-Z]+$/)) {
        alertstr += '- Invalid entry for the "Name" field\n';
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
</script>
<p>
<form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" />
Enter your name: <input id="name" name="name" type="text" />
Select your Best Color: <select name="color" multiple>
  <option selected="selected" value="red">red</option>
  <option  value="green">green</option>
  <option  value="blue">blue</option>

</select>
Sex = <radio name="sex" value="M">Male<br><radio name="sex" value="F">Female<br>
FYI, your dress size is 42<br>
<input id="_submit" name="_submit" type="submit" value="No esta una button del resetto" />
</form>
),

    },

    {
        opt => { fields => [qw/name color size/],
                 template => { type => 'Text', TYPE => 'STRING', template => $template, },
                 values => {color => [qw/purple/], size => 8},
                 submit => 'Start over, boob!',
               },

        mod => { color => { options => [[white=>'White'],[black=>'Black'],[red=>'Green']],
                            label => 'Mom', },
                 name => { size => 80, maxlength => 80, comment => 'Fuck off' },
                 sex   => { options => [[1=>'Yes'], [0=>'No'], [-1=>'Maybe']],
                            label => 'Fuck me?<br>' },
               },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".

<p>
<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" />
Enter your name: <input id="name" maxlength="80" name="name" size="80" type="text" />Fuck off
Select your Mom: <select name="color" multiple>
  <b><option VALUE="white">White</option></b>
  <b><option VALUE="black">Black</option></b>
  <b><option VALUE="red">Green</option></b>

</select>
Fuck me?<br> = <radio name="sex" value="1">Yes<br><radio name="sex" value="0">No<br><radio name="sex" value="-1">Maybe<br>
FYI, your dress size is 8<br>
<input id="_submit" name="_submit" type="submit" value="Start over, boob!" />
</form>
),
    },

    {
        opt => { fields => [qw/name color email/], submit => [qw/Update Delete/], reset => 0,
                 template => { type => 'Text', TYPE => 'STRING', template => $template, },
                 values => {color => [qw/yellow green orange/]},
                 validate => { sex => [qw(1 3 5)] },
               },

        mod => { color => {options => [[red => 1], [blue => 2], [yellow => 3], [pink => 4]] },
                 size  => {comment => '(unknown)', value => undef, force => 1 } ,
                 sex   => {label => 'glass EYE fucker', options => [[1,2],[3,4],[5,6]] },
               },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // sex: radio group or multiple checkboxes
    var sex = null;
    var selected_sex = 0;
    for (var loop = 0; loop < form.elements['sex'].length; loop++) {
        if (form.elements['sex'][loop].checked) {
            sex = form.elements['sex'][loop].value;
            selected_sex++;
            if (sex == null || (sex != '1' && sex != '3' && sex != '5')) {
                alertstr += '- Choose one of the "glass EYE fucker" options\n';
                invalid++;
            }
        } // if
    } // for sex
    if (! selected_sex) {
        alertstr += '- Choose one of the "glass EYE fucker" options\n';
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
</script>
<p>
<form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" />
Enter your name: <input id="name" name="name" type="text" />
Select your Color: <select name="color" multiple>
  <b><option VALUE="red">1</option></b>
  <b><option VALUE="blue">2</option></b>
  <b><option VALUE="yellow">3</option></b>
  <b><option VALUE="pink">4</option></b>

</select>
glass EYE fucker = <radio name="sex" value="1">2<br><radio name="sex" value="3">4<br><radio name="sex" value="5">6<br>
FYI, your dress size is (unknown)<br>
<input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Delete" />
</form>
),
    },


);

# Cycle thru and try it out
for (@test) {
    my $form = CGI::FormBuilder->new(action => 'TEST', %{ $_->{opt} }, debug => $DEBUG );
    while(my($f,$o) = each %{$_->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }

    # just compare the output of render with what's expected
    my $out;
    eval "\$out = \$form->render";
    my $ok = skip($SKIP, $out, $_->{res});

    if (! $ok && $ENV{LOGNAME} eq 'nwiger') {
        open(O, ">/tmp/fb.1.out");
        print O $_->{res};
        close O;

        open(O, ">/tmp/fb.2.out");
        print O $out;
        close O;

        system "diff /tmp/fb.1.out /tmp/fb.2.out";
        exit 1;
    }
}

# MORE TESTS DOWN HERE

# from eszpee for tmpl_param
skip($SKIP, do{
    my $form2 = CGI::FormBuilder->new(
                    template => { type => 'Text', engine => {TYPE => 'STRING', SOURCE => '<% $test %>'} }
                );
    $form2->tmpl_param(test => "this message should appear");
    my $out;
    eval "\$out = \$form2->render";
    $out;
}, 'this message should appear');

