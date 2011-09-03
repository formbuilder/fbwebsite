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
    eval "require HTML::Template";
    $SKIP = $@ ? 'skip: HTML::Template not installed here' : 0;   # eval failed, skip all tests

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
my $template = <<EOT;
<html>
<title>User Info</title>
Please update your info and hit "Submit".
<tmpl_var js-head>
<p>
<tmpl_var form-start><tmpl_var form-state>
Enter your name: <tmpl_var field-name>
<select name="color" multiple>
    <tmpl_loop loop-color>
    <option value="<tmpl_var value>" <tmpl_var selected>><tmpl_var label></option>
    </tmpl_loop>
</select>
FYI, your dress size is <tmpl_var value-size><br>
<tmpl_var form-reset> <tmpl_var form-submit>
<tmpl_var form-end>
EOT

# What options we want to use, and what we expect to see
my @test = (
    {
        opt => { fields => [qw/name color/], 
                 submit => 0, 
                 reset  => 'No esta una button del submito',
                 template => { scalarref => \$template },
                 validate => { name => 'NAME' },
                 
               },
        mod => { color => { options => [qw/red green blue/], nameopts => 1 },
                 size  => { value => 42 } },

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
<select name="color" multiple>
    
    <option value="red" >Red</option>
    
    <option value="green" >Green</option>
    
    <option value="blue" >Blue</option>
    
</select>
FYI, your dress size is 42<br>
<input id="_reset" name="_reset" type="reset" value="No esta una button del submito" /> 
</form>
),

    },

    {
        opt => { fields => [qw/name color size/],
                 template => { scalarref => \$template },
                 values => {color => [qw/purple/], size => 8},
                 reset => 'Start over, boob!',
                 validate => {},    # should be empty
               },

        mod => { color => { options => [qw/white black other/] },
                 name => { size => 80 } },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".

<p>
<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" />
Enter your name: <input id="name" name="name" size="80" type="text" />
<select name="color" multiple>
    
    <option value="white" >white</option>
    
    <option value="black" >black</option>
    
    <option value="other" >other</option>
    
</select>
FYI, your dress size is 8<br>
<input id="_reset" name="_reset" type="reset" value="Start over, boob!" /> <input id="_submit" name="_submit" type="submit" value="Submit" />
</form>
),
    },

    {
        opt => { fields => [qw/name color email/], submit => [qw/Update Delete/], reset => 0,
                 template => { scalarref => \$template },
                 values => {color => [qw/yellow green orange/]},
                 validate => { color => [qw(red blue yellow pink)] },
               },

        mod => { color => {options => [[red => 1], [blue => 2], [yellow => 3], [pink => 4]] },
                 size  => {value => '(unknown)' } 
               },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<script language="JavaScript1.3" type="text/javascript"><!-- hide from old browsers
function validate (form) {
    var alertstr = '';
    var invalid  = 0;

    // color: radio group or multiple checkboxes
    var color = null;
    var selected_color = 0;
    for (var loop = 0; loop < form.elements['color'].length; loop++) {
        if (form.elements['color'][loop].checked) {
            color = form.elements['color'][loop].value;
            selected_color++;
            if (color == null || (color != 'red' && color != 'blue' && color != 'yellow' && color != 'pink')) {
                alertstr += '- Check one or more of the "Color" options\n';
                invalid++;
            }
        } // if
    } // for color
    if (! selected_color) {
        alertstr += '- Check one or more of the "Color" options\n';
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
<select name="color" multiple>
    
    <option value="red" >1</option>
    
    <option value="blue" >2</option>
    
    <option value="yellow" selected>3</option>
    
    <option value="pink" >4</option>
    
</select>
FYI, your dress size is (unknown)<br>
 <input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Delete" />
</form>
),
    },


);

# Cycle thru and try it out
for (@test) {
    my $form = CGI::FormBuilder->new(action => 'TEST',  %{ $_->{opt} }, debug => $DEBUG );
    while(my($f,$o) = each %{$_->{mod} || {}}) {
        $o->{name} = $f;
        $form->field(%$o);
    }

    # just compare the output of render with what's expected
    my $out = '';
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
                    template => { scalarref => \'<TMPL_VAR test>' }
                );
    $form2->tmpl_param(test => "this message should appear");
    my $out;
    eval "\$out = \$form2->render";
    $out;
}, 'this message should appear');

