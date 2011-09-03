#!/usr/bin/perl -I.

use strict;
use vars qw($TESTING $DEBUG);
$TESTING = 1;
$DEBUG = $ENV{DEBUG} || 0;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN {
    # try to load template engine so absent template does
    # not cause all tests to fail
    eval "require HTML::Template";
    if ($@) {
        # eval failed, skip all tests
        print "1..1\nok 1\n";
        exit 0;
    } else {
        plan tests => 3;
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
        opt => { fields => [qw/name color/], submit => 0, reset => 'No esta una button del submito',
                 template => { scalarref => \$template, die_on_bad_params => 0 },
               },
        mod => { color => { options => [qw/red green blue/], nameopts => 1 },
                 size  => { value => 42 } },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<p>
<form action="03htmltemplate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" />
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
                 template => { scalarref => \$template, die_on_bad_params => 0 },
                 values => {color => [qw/purple/], size => 8},
                 reset => 'Start over, boob!',
               },

        mod => { color => { options => [qw/white black other/] },
                 name => { size => 80 } },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<p>
<form action="03htmltemplate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" />
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
                 template => { scalarref => \$template, die_on_bad_params => 0 },
                 values => {color => [qw/yellow green orange/]},
               },

        mod => { color => {options => [[red => 1], [blue => 2], [yellow => 3], [pink => 4]] },
                 size  => {value => '(unknown)' } 
               },

        res => q(<html>
<title>User Info</title>
Please update your info and hit "Submit".
<p>
<form action="03htmltemplate.t" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" /><input id="_sessionid" name="_sessionid" type="hidden" value="" />
Enter your name: <input id="name" name="name" type="text" />
<select name="color" multiple>
    
    <option value="red" >1</option>
    
    <option value="blue" >2</option>
    
    <option value="yellow" selected>3</option>
    
    <option value="pink" >4</option>
    
</select>
FYI, your dress size is (unknown)<br>
 <input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onClick="this.form._submit.value = this.value;" type="submit" value="Delete" />
</form>
),
    },

);

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

