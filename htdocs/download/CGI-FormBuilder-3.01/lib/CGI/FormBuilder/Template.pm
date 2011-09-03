
# Copyright (c) 2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.
# Use "perldoc CGI::FormBuilder::Template" to read full documentation.

package CGI::FormBuilder::Template;

=head1 NAME

CGI::FormBuilder::Template - template adapters for FormBuilder

=head1 SYNOPSIS

    # Define a template engine

    package CGI::FormBuilder::Template::Type;

    sub render {
        my $form = shift;   # first arg is form object
        my %args = @_;      # remaining args are 'template' opts

        # ... code ...

        return $html;       # scalar HTML is returned
    }

=cut

use strict;
use vars qw($VERSION);

$VERSION = '3.01';

=head1 DESCRIPTION

This documentation describes the usage of B<FormBuilder> templates,
as well as how to write your own template adapter.

The template engines serve as adapters between CPAN template modules
and B<FormBuilder>. A template engine is invoked by using the C<template>
option to the top-level C<new()> method:

    my $form = CGI::FormBuilder->new(
                    template => 'filename.tmpl'
               );

This example points to a filename that contains an C<HTML::Template>
compatible template to use to layout the HTML. You can also specify
the C<template> option as a reference to a hash, allowing you to
further customize the template processing options, or use other
template engines.

For example, you could turn on caching in C<HTML::Template> with
something like the following:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        filename => 'form.tmpl',
                        shared_cache => 1
                    }
               );

As mentioned, specifying a hashref allows you to use an alternate template
processing system like the C<Template Toolkit>.  A minimal configuration
would look like this:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        type => 'TT2',      # use Template Toolkit
                        template => 'form.tmpl',
                    },
               );

The C<type> option specifies the name of the engine. Currently accepted
types are:

    HTML  -   HTML::Template (default)
    Text  -   Text::Template
    TT2   -   Template Toolkit

All other options besides C<type> are passed to the constructor for that
templating system verbatim, so you'll need to consult those docs to see what
all the different options do.

Let's look at each template solution in turn.

=head2 HTML::Template

C<HTML::Template> is the default template option and is activated
one of two ways. Either:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => $filename
               );

Or, you can specify any options which C<< HTML::Template->new >>
accepts by using a hashref:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        filename => $filename,
                        die_on_bad_params => 0,
                        shared_cache => 1,
                        loop_context_vars => 1
                    }
                );

In your template, each of the form fields will correspond directly to
a C<< <tmpl_var> >> of the same name prefixed with "field-" in the
template. So, if you defined a field called "email", then you would
setup a variable called C<< <tmpl_var field-email> >> in your template,
and this would be expanded to the complete HTML C<< <input> >> tag.

In addition, there are a couple special fields:

    <tmpl_var js-head>     -  JavaScript to stick in <head>
    <tmpl_var form-title>  -  The <title> of the HTML form
    <tmpl_var form-start>  -  Opening <form> tag and internal fields
    <tmpl_var form-submit> -  The submit button(s)
    <tmpl_var form-reset>  -  The reset button
    <tmpl_var form-end>    -  Just the closing </form> tag

Let's look at an example C<userinfo.tmpl> template we could use:

    <html>
    <head>
    <title>User Information</title>
    <tmpl_var js-head><!-- this holds the JavaScript code -->
    </head>
    <tmpl_var form-start><!-- this holds the initial form tag -->
    <h3>User Information</h3>
    Please fill out the following information:
    <!-- each of these tmpl_var's corresponds to a field -->
    <p>Your full name: <tmpl_var field-name>
    <p>Your email address: <tmpl_var field-email>
    <p>Choose a password: <tmpl_var field-password>
    <p>Please confirm it: <tmpl_var field-confirm_password>
    <p>Your home zipcode: <tmpl_var field-zipcode>
    <p>
    <tmpl_var form-submit><!-- this holds the form submit button -->
    </form><!-- can also use "tmpl_var form-end", same thing -->

As you see, you get a C<< <tmpl_var> >> for each for field you define.

However, you may want even more control. That is, maybe you want
to specify every nitty-gritty detail of your input fields, and
just want this module to take care of the statefulness of the
values. This is no problem, since this module also provides
several other C<< <tmpl_var> >> tags as well:

    <tmpl_var value-[field]>   - The value of a given field
    <tmpl_var label-[field]>   - The human-readable label
    <tmpl_var comment-[field]> - Any optional comment
    <tmpl_var error-[field]>   - Error text if validation fails

This means you could say something like this in your template:

    <tmpl_var label-email>:
    <input type="text" name="email" value="<tmpl_var value-email>">
    <font size="-1"><i><tmpl_var error-email></i></font>

And B<FormBuilder> would take care of the value stickiness for you,
while you have control over the specifics of the C<< <input> >> tag.
A sample expansion may create HTML like the following:

    Email:
    <input type="text" name="email" value="nate@wiger">
    <font size="-1"><i>You must enter a valid value</i></font>

Note, though, that this will only get the I<first> value in the case
of a multi-value parameter (for example, a multi-select list). To
remedy this, if there are multiple values you will also get a
C<< <tmpl_var> >> prefixed with "loop-". So, if you had:

    myapp.cgi?color=gray&color=red&color=blue

This would give the C<color> field three values. To create a select
list, you would do this in your template:

    <select name="color" multiple>
    <tmpl_loop loop-color>
        <option value="<tmpl_var value>"><tmpl_var label></option>
    </tmpl_loop>
    </select>

With C<< <tmpl_loop> >> tags, each iteration gives you several
variables:

    Inside <tmpl_loop>, this...  Gives you this
    ---------------------------  -------------------------------
    <tmpl_var value>             value of that option
    <tmpl_var label>             label for that option
    <tmpl_var checked>           if selected, the word "checked"
    <tmpl_var selected>          if selected, the word "selected"

Please note that C<< <tmpl_var value> >> gives you one of the I<options>,
not the values. Why? Well, if you think about it you'll realize that
select lists and radio groups are fundamentally different from input
boxes in a number of ways. Whereas in input tags you can just have
an empty value, with lists you need to iterate through each option
and then decide if it's selected or not.

When you need precise control in a template this is all exposed to you;
normally B<FormBuilder> does all this magic for you. If you don't need
exact control over your lists, simply use the C<< <tmpl_var field-[name]> >>
tag and this will all be done automatically, which I strongly recommend.

But, let's assume you need exact control over your lists. Here's an
example select list template:

    <select name="color" multiple>
    <tmpl_loop loop-color>
    <option value="<tmpl_var value>" <tmpl_var selected>><tmpl_var label>
    </tmpl_loop>
    </select>

Then, your Perl code would fiddle the field as follows:

    $form->field( 
              name => 'color', nameopts => 1,
              options => [qw(red green blue yellow black white gray)]
           );

Assuming query string as shown above, the template would then be expanded
to something like this:

    <select name="color" multiple>
    <option value="red" selected>Red
    <option value="green" >Green
    <option value="blue" selected>Blue
    <option value="yellow" >Yellow
    <option value="black" >Black
    <option value="white" >White
    <option value="gray" selected>Gray
    </select>

Notice that the C<< <tmpl_var selected> >> tag is expanded to the word
"selected" when a given option is present as a value as well (i.e.,
via the CGI query). The C<< <tmpl_var value> >> tag expands to each option
in turn, and C<< <tmpl_var label> >> is expanded to the label for that
value. In this case, since C<nameopts> was specified to C<field()>, the
labels are automatically generated from the options.

Let's look at one last example. Here we want a radio group that allows
a person to remove themself from a mailing list. Here's our template:

    Do you want to be on our mailing list?
    <p><table>
    <tmpl_loop loop-mailopt>
    <td bgcolor="silver">
      <input type="radio" name="mailopt" value="<tmpl_var value>">
    </td>
    <td bgcolor="white"><tmpl_var label></td>
    </tmpl_loop>
    </table>

Then, we would twiddle our C<mailopt> field via C<field()>:

    $form->field(
              name => 'mailopt',
              options => [
                 [ 1 => 'Yes, please keep me on it!' ],
                 [ 0 => 'No, remove me immediately.' ]
              ]
           );

When the template is rendered, the result would be something like this:

    Do you want to be on our mailing list?
    <p><table>

    <td bgcolor="silver">
      <input type="radio" name="mailopt" value="1">
    </td>
    <td bgcolor="white">Yes, please keep me on it!</td>

    <td bgcolor="silver">
      <input type="radio" name="mailopt" value="0">
    </td>
    <td bgcolor="white">No, remove me immediately</td>

    </table>

When the form was then sumbmitted, you would access the values just
like any other field:

    if ($form->field('mailopt')) {
        # is 1, so add them
    } else {
        # is 0, remove them
    }

Finally, you can also loop through each of the fields using the top-level
C<fields> loop in your template. This allows you to reuse the
same template even if your parameters change. The following template
code would loop through each field, creating a table row for each:

    <table>
    <tmpl_loop fields>
    <tr>
    <td class="small"><tmpl_var label></td>
    <td><tmpl_var field></td>
    </tr>
    </tmpl_loop>
    </table>

Each loop will have a C<label>, C<field>, C<value>, etc, just like above.

For more information on templates, see L<HTML::Template>.

=head2 Template Toolkit

Thanks to a huge patch from Andy Wardley, B<FormBuilder> also supports
C<Template Toolkit>. Recall the first example way back at the top where
we introduced C<HTML::Template>. You can also do a similar thing using
the Template Toolkit (http://template-toolkit.org/) to generate the
form. This time, specify the C<template> option as a hashref which
includes the C<type> option set to C<TT2> and the C<template> option to
denote the name of the template you want processed. You can also add
C<variable> as an option (among others) to denote the variable name that
you want the form data to be referenced by.

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        type => 'TT2',
                        template => 'userinfo.tmpl',
                        variable => 'form',
                    }
               );

The template might look something like this:

    <html>
    <head>
      <title>[% form.title %]</title>
      [% form.jshead %]
    </head>
    <body>
      [% form.start %]
      <table>
        [% FOREACH field = form.fields %]
        <tr valign="top">
          <td>
            [% field.required
                  ? "<b>$field.label</b>"
                  : field.label
            %]
          </td>
          <td>
            [% IF field.invalid %]
            Missing or invalid entry, please try again.
        <br/>
        [% END %]

        [% field.field %]
      </td>
    </tr>
        [% END %]
        <tr>
          <td colspan="2" align="center">
            [% form.submit %] [% form.reset %]
          </td>
        </tr>
      </table>
      [% form.end %]
    </body>
    </html>

By default, the Template Toolkit makes all the form and field
information accessible through simple variables.

    [% jshead %]  -  JavaScript to stick in <head>
    [% title  %]  -  The <title> of the HTML form
    [% start  %]  -  Opening <form> tag and internal fields
    [% submit %]  -  The submit button(s)
    [% reset  %]  -  The reset button
    [% end    %]  -  Closing </form> tag
    [% fields %]  -  List of fields
    [% field  %]  -  Hash of fields (for lookup by name)

You can specify the C<variable> option to have all these variables
accessible under a certain namespace.  For example:

    my $form = CGI::FormBuilder->new(
        fields => \@fields,
        template => {
             type => 'TT2',
             template => 'form.tmpl',
             variable => 'form'
        },
    );

With C<variable> set to C<form> the variables are accessible as:

    [% form.jshead %]
    [% form.start  %]
    etc.

You can access individual fields via the C<field> variable.

    For a field named...  The field data is in...
    --------------------  -----------------------
    job                   [% form.field.job   %]
    size                  [% form.field.size  %]
    email                 [% form.field.email %]

Each field contains various elements.  For example:

    [% myfield = form.field.email %]

    [% myfield.label    %]  # text label
    [% myfield.field    %]  # field input tag
    [% myfield.value    %]  # first value
    [% myfield.values   %]  # list of all values
    [% myfield.option   %]  # first value
    [% myfield.options  %]  # list of all values
    [% myfield.required %]  # required flag
    [% myfield.invalid  %]  # invalid flag

The C<fields> variable contains a list of all the fields in the form.
To iterate through all the fields in order, you could do something like
this:

    [% FOREACH field = form.fields %]
    <tr>
     <td>[% field.label %]</td> <td>[% field.field %]</td>
    </tr>
    [% END %]

If you want to customise any of the Template Toolkit options, you can
set the C<engine> option to contain a reference to an existing
C<Template> object or hash reference of options which are passed to
the C<Template> constructor.  You can also set the C<data> item to
define any additional variables you want accesible when the template
is processed.

    my $form = CGI::FormBuilder->new(
        fields => \@fields,
        template => {
             type => 'TT2',
             template => 'form.tmpl',
             variable => 'form'
             engine   => {
                  INCLUDE_PATH => '/usr/local/tt2/templates',
             },
             data => {
                  version => 1.23,
                  author  => 'Fred Smith',
             },
        },
    );

For further details on using the Template Toolkit, see C<Template> or
www.template-toolkit.org

=head2 Text::Template

Also thanks to a user contribution, this time by Jonathan Buhacoff,
C<Text::Template> is also supported. Usage is very similar to Template Toolkit:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        type => 'Text',           # use Text::Template
                        template => 'form.tmpl',
                    }
               );

The default options passed into C<Text::Template->new()> with this
calling form are:

    TYPE   => 'FILE'
    SOURCE => 'form.tmpl'
    DELIMITERS => ['<%','%>']

As these params are passed for you, your template will look very similar to
ones used by Template Toolkit and C<HTML::Mason> (the Text::Template default
delimiters are C<{> and C<}>, but using alternative delimiters speeds it up by
about 25%, and the C<< <% >> and C<< %> >> delimiters are good,
familiar-looking alternatives).

    <% $jshead %>  -  JavaScript to stick in <head>
    <% $title  %>  -  The <title> of the HTML form
    <% $start  %>  -  Opening <form> tag and internal fields
    <% $submit %>  -  The submit button(s)
    <% $reset  %>  -  The reset button
    <% $end    %>  -  Closing </form> tag
    <% $fields %>  -  List of fields
    <% $field  %>  -  Hash of fields (for lookup by name)

Note that you refer to variables with a preceding C<$>, just like in Perl.
Like Template Toolkit, you can specify a variable to place fields under:

    my $form = CGI::FormBuilder->new(
        fields => \@fields,
        template => {
             type => 'Text',
             template => 'form.tmpl',
             variable => 'form'
        },
    );

Unlike Template Toolkit, though, these will not be placed in OO-style,
dot-separated vars. Instead, a hash will be created which you then reference:

    <% $form{jshead} %>
    <% $form{start}  %>
    etc.

And field data is in a hash-of-hashrefs format:

    For a field named...  The field data is in...
    --------------------  -----------------------
    job                   <% $form{field}{job}   %]
    size                  <% $form{field}{size}  %]
    email                 <% $form{field}{email} %]

Since C<Text::Template> looks so much like Perl, you can access individual
elements and create variables like so:

    <%
        my $myfield = $form{field}{email};
        $myfield->{label};  # text label
        $myfield->{field}; # field input tag
        $myfield->{value}; # first value
        $myfield->{values}; # list of all values
        $myfield->{option}; # first option
        $myfield->{options}; # list of all options
        $myfield->{required}; # required flag
        $myfield->{invalid}; # invalid flag
    %>

    <%
        for my $field (@{$form{fields}}) {
            $OUT .= "<tr>\n<td>" . $field->{label} . "</td> <td>" . $field->{field} . "</td>\n<tr>";
        }
    %>

In addition, when using the engine option, as in Template Toolkit, you can
supply an existing Text::Template object or a hash of parameters to be passed
to C<new()>. For example, you can ask for different delimiters yourself:

    my $form = CGI::FormBuilder->new(
        fields => \@fields,
        template => {
             type => 'Text',
             template => 'form.tmpl',
             variable => 'form',
             engine   => {
                DELIMITERS => [ '[@--', '--@]' ],
             },
             data => {
                  version => 1.23,
                  author  => 'Fred Smith',
             },
        },
    );

If you pass a hash of parameters, you can override the C<TYPE> and C<SOURCE> parameters,
as well as any other C<Text::Template> options. For example, you can pass in a string
template with C<< TYPE => STRING >> instead of loading it from a file. You must
specify B<both> C<TYPE> and C<SOURCE> if doing so.  The good news is this is trivial:

    my $form = CGI::FormBuilder->new(
        fields => \@fields,
        template => {
             type => 'Text',
             variable => 'form',
             engine   => {
                  TYPE => 'STRING',
                  SOURCE => $string,
                  DELIMITERS => [ '[@--', '--@]' ],
             },
             data => {
                  version => 1.23,
                  author  => 'Fred Smith',
             },
        },
    );

If you get the crazy idea to let users of your application pick the template file
(strongly discouraged) and you're getting errors, look at the C<Text::Template>
documentation for the C<UNTAINT> feature.

Also, note that C<Text::Template>'s C<< PREPEND => 'use strict;' >> option is not
recommended due to the dynamic nature for C<FormBuilder>.  If you use it, then you'll
have to declare each variable that C<FormBuilder> puts into your template with
C<< use vars qw($jshead' ... etc); >>

If you're really stuck on this, though, a workaround is to say:

    PREPEND => 'use strict; use vars qw(%form);'

and then set the option C<< variable => 'form' >>. That way you can have strict Perl
without too much hassle, except that your code might be exhausting to look at :-).
Things like C<$form{field}{your_field_name}{field}> end up being all over the place,
instead of the nicer short forms.

Finally, when you use the C<data> template option, the keys you specify will be available
to the template as regular variables. In the above example, these would be
C<< <% $version %> >> and C<< <% $author %> >>. And complex datatypes are easy:

    data => {
            anArray => [ 1, 2, 3 ],
            aHash => { orange => 'tangy', chocolate => 'sweet' },
    }

This becomes the following in your template:

    <%
        @anArray;    # you can use $myArray[1] etc.
        %aHash;      # you can use $myHash{chocolate} etc.
    %>

For more information, please consult the C<Text::Template> documentation.

=head1 SUBCLASSING

In addition to the above included template engines, it is also possible to write
your own rendering module. If you come up with something cool, please let the
mailing list know!

To do so, you need to write a module which has a sub called C<render()>. This
sub will be called by B<FormBuilder> when C<< $form->render >> is called. This
sub can do basically whatever it wants, the only thing it has to do is return
a scalar string which is the HTML to print out. The best thing to do is look
through the guys of one of the existing template engines and go from there.

=cut

1;

=head1 SEE ALSO

L<CGI::FormBuilder>, L<CGI::FormBuilder::Template::HTML>,
L<CGI::FormBuilder::Template::Text>, L<CGI::FormBuilder::Template::TT2>

=head1 REVISION

$Id: Template.pm,v 1.7 2005/02/10 20:15:52 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
