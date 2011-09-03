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
    eval "require CGI::FastTemplate";
    $SKIP = $@ ? 'skip: CGI::FastTemplate not installed here' : 0;

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
$JS_HEAD
$START_FORM
$FIELDS
$SUBMIT
$FORM_END
EOT

my $fieldtmpl = <<'EOT';
<tr class="$REQUIRED"><th>$LABEL</th><td>$FIELD $COMMENT</td></tr>
EOT

my $fieldinv = <<'EOT';
<tr class="$REQUIRED invalid"><th>$LABEL</th><td>$FIELD $COMMENT $ERROR</td></tr>
EOT

# What options we want to use, and what we expect to see
my @test = (
    {
        opt => { fields => [qw/name color/],
                 submit => 'No esta una button del resetto',
                 template => {
                        type => 'Fast',
                        define_nofile => {
                            form => $template,
                            field => $fieldinv,
                            field_invalid => $fieldinv,
                        }
                 },
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
<form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" />
<tr class="required invalid"><th>Name</th><td><input id="name" name="name" type="text" />  </td></tr>
<tr class="optional invalid"><th>Best Color</th><td><input checked="checked" id="color_red" name="color" type="radio" value="red" /> <label for="color_red">red</label> <input id="color_green" name="color" type="radio" value="green" /> <label for="color_green">green</label> <input id="color_blue" name="color" type="radio" value="blue" /> <label for="color_blue">blue</label>   </td></tr>
<tr class="optional invalid"><th>Sex</th><td><input id="sex_M" name="sex" type="radio" value="M" /> <label for="sex_M">Male</label> <input id="sex_F" name="sex" type="radio" value="F" /> <label for="sex_F">Female</label>   </td></tr>
<tr class="optional invalid"><th>Size</th><td><input id="size" name="size" type="text" value="42" />  </td></tr>

<input id="_submit" name="_submit" type="submit" value="No esta una button del resetto" />

),

    },

    {
        opt => { fields => [qw/name color size/],
                 template => {
                        type => 'Fast',
                        define_nofile => {
                            form => $template,
                            field => $fieldinv,
                            field_invalid => $fieldinv,
                        }
                 },
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

<form action="TEST" method="GET"><input id="_submitted" name="_submitted" type="hidden" value="1" />
<tr class="optional invalid"><th>Name</th><td><input id="name" maxlength="80" name="name" size="80" type="text" /> Fuck off </td></tr>
<tr class="optional invalid"><th>Mom</th><td><input id="color_white" name="color" type="radio" value="white" /> <label for="color_white">White</label> <input id="color_black" name="color" type="radio" value="black" /> <label for="color_black">Black</label> <input id="color_red" name="color" type="radio" value="red" /> <label for="color_red">Green</label>   </td></tr>
<tr class="optional invalid"><th>Size</th><td><input id="size" name="size" type="text" value="8" />  </td></tr>
<tr class="optional invalid"><th>Fuck me?<br></th><td><input id="sex_1" name="sex" type="radio" value="1" /> <label for="sex_1">Yes</label> <input id="sex_0" name="sex" type="radio" value="0" /> <label for="sex_0">No</label> <input id="sex_-1" name="sex" type="radio" value="-1" /> <label for="sex_-1">Maybe</label>   </td></tr>

<input id="_submit" name="_submit" type="submit" value="Start over, boob!" />

),
    },

    {
        opt => { fields => [qw/name color email/], submit => [qw/Update Delete/], reset => 0,
                 template => {
                        type => 'Fast',
                        define_nofile => {
                            form => $template,
                            field => $fieldinv,
                            field_invalid => $fieldinv,
                        }
                 },
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
<form action="TEST" method="GET" onsubmit="return validate(this);"><input id="_submitted" name="_submitted" type="hidden" value="1" />
<tr class="optional invalid"><th>Name</th><td><input id="name" name="name" type="text" />  </td></tr>
<tr class="optional invalid"><th>Color</th><td><input id="color_red" name="color" type="checkbox" value="red" /> <label for="color_red">1</label> <input id="color_blue" name="color" type="checkbox" value="blue" /> <label for="color_blue">2</label> <input checked="checked" id="color_yellow" name="color" type="checkbox" value="yellow" /> <label for="color_yellow">3</label> <input id="color_pink" name="color" type="checkbox" value="pink" /> <label for="color_pink">4</label>   </td></tr>
<tr class="optional invalid"><th>Email</th><td><input id="email" name="email" type="text" />  </td></tr>
<tr class="required invalid"><th>glass EYE fucker</th><td><input id="sex_1" name="sex" type="radio" value="1" /> <label for="sex_1">2</label> <input id="sex_3" name="sex" type="radio" value="3" /> <label for="sex_3">4</label> <input id="sex_5" name="sex" type="radio" value="5" /> <label for="sex_5">6</label>   </td></tr>
<tr class="optional invalid"><th>Size</th><td><input id="size" name="size" type="text" /> (unknown) </td></tr>

<input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Update" /><input id="_submit" name="_submit" onclick="this.form._submit.value = this.value;" type="submit" value="Delete" />

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
                     template => {
                        type => 'Fast',
                        define_nofile => {
                            form => '$TEST',
                        }
                     },
                );
    $form2->tmpl_param(TEST => "this message should appear");
    my $out;
    eval "\$out = \$form2->render";
    $out;
}, 'this message should appear');

