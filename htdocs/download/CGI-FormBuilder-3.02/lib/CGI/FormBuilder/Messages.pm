
package CGI::FormBuilder::Messages;

=head1 NAME

CGI::FormBuilder::Messages - Localized message support for FormBuilder

=head1 SYNOPSIS

    use CGI::FormBuilder::Messages;

    my $mesg = CGI::FormBuilder::Messages->new($file || \%hash);

    print $mesg->js_invalid_text;

=cut

use Carp;
use strict;
use vars qw($VERSION %MESSAGES $AUTOLOAD);

$VERSION = '3.02';

use CGI::FormBuilder::Util;

# Default messages, since all can be customized. These are used when
# the person does not specify any special ones (the normal case).
%MESSAGES = (
    js_invalid_start      => '%s error(s) were encountered with your submission:',
    js_invalid_end        => 'Please correct these fields and try again.',

    js_invalid_input      => '- Invalid entry for the "%s" field',
    js_invalid_select     => '- Select an option from the "%s" list',
    js_invalid_multiple   => '- Select one or more options from the "%s" list',
    js_invalid_checkbox   => '- Check one or more of the "%s" options',
    js_invalid_radio      => '- Choose one of the "%s" options',
    js_invalid_password   => '- Invalid entry for the "%s" field',
    js_invalid_textarea   => '- Please fill in the "%s" field',
    js_invalid_file       => '- Invalid filename for the "%s" field',
    js_invalid_default    => '- Invalid entry for the "%s" field',

    js_noscript           => '<p><font color="red"><b>Please enable JavaScript or '
                           . 'use a newer browser.</b></font></p>',

    form_required_text    => '<p>Fields that are %shighlighted%s are required.</p>',
    form_required_opentag => '<b>',
    form_required_closetag=> '</b>',

    form_invalid_text     => '<p>%s error(s) were encountered with your submission. '
                           . 'Please correct the fields %shighlighted%s below.</p>',
    form_invalid_opentag  => '<font color="red"><b>',
    form_invalid_closetag => '</b></font>',
    form_invalid_color    => 'red',

    form_invalid_input    => 'Invalid entry',
    form_invalid_select   => 'Select an option from this list',
    form_invalid_checkbox => 'Check one or more options',
    form_invalid_radio    => 'Choose an option',
    form_invalid_password => 'Invalid entry',
    form_invalid_textarea => 'Please fill this in',
    form_invalid_file     => 'Invalid filename',
    form_invalid_default  => 'Invalid entry',

    form_grow_default     => 'Additional %s',
    form_select_default   => '-select-',
    form_other_default    => 'Other:',
    form_submit_default   => 'Submit',
    form_reset_default    => 'Reset',
    
    form_confirm_text     => 'Success! Your submission has been received %s.',

    mail_confirm_subject  => '%s Submission Confirmation',
    mail_confirm_text     => <<EOT,
Your submission has been received %s,
and will be processed shortly.

If you have any questions, please contact our staff by replying
to this email.
EOT
    mail_results_subject  => '%s Submission Results',
);

sub new {
    my $self = shift;
    my $class = ref($self) || $self;
    my $src   = shift;
    my %hash  = %MESSAGES;

    return bless \%hash, $class unless $src;

    if (my $ref = ref $src) {
        # hashref, get values directly
        puke "Argument to 'messages' option must be a filename or hashref"
            unless $ref eq 'HASH';
        while(my($k,$v) = each %$src) {
            $hash{$k} = $v;     # just override selectively
        }
    } else {
        # filename, just *warn* on missing, and use defaults
        if (-f $src && -r _ && open(M, "<$src")) {
            while(<M>) {
                next if /^\s*#/ || /^\s*$/;
                chomp;
                my($k,$v) = split ' ', $_, 2;
                $hash{$k} = $v;
            }
            close M;
        } else {
            belch "Could not read messages file $src: $!";
        }
    }
    return bless \%hash, $class;
}

*messages = \&message;
sub message {
    my $self = shift;
    my $key  = shift;
    unless ($key) {
        if (ref $self) {
            return wantarray ? %$self : $self;
        } else {
            # requesting a byname dump
            for my $k (sort keys %MESSAGES) {
                printf "    %-20s\t%s\n", $k, $MESSAGES{$k};
            }
            exit;
        }
    }
    $self->{$key} = shift if @_;
    belch "No message string found for '$key'" unless exists $self->{$key};
    if (ref $self->{$key} eq 'ARRAY') {
        # hack catch for external file
        $self->{$key} = join ', ', @{$self->{$key}};
    }
    return $self->{$key} || '';
}

sub DESTROY { 1 }
sub AUTOLOAD {
    # This allows direct addressing by name, for subclassable usage
    my $self = shift;
    my($name) = $AUTOLOAD =~ /.*::(.+)/;
    return $self->message($name, @_);
}

1;
__END__

=head1 DESCRIPTION

This module handles multilingual messaging for B<FormBuilder>. It is invoked
by specifying the C<messages> option to the top-level C<new()> method. Each
message that B<FormBuilder> outputs is given a unique key. If you specify a
custom message for a given key, then that message is used. Otherwise, the
default is printed. Note that it is up to you to figure out what to
pass in - there is no magic C<LC_MESSAGES> mysterium to this module.

For example, let's say you wrote a script that needed to display custom
JavaScript error messages. You could do something like this:

    # Get language requested
    my $lang = $ENV{HTTP_ACCEPT_LANGUAGE} || 'en';

    # Get the appropriate file
    my $langfile = "/languages/formbuilder/messages.$lang";

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    messages => $langfile,
               );

    print $form->render;

Your language file would then contain something like the following:

    # FormBuilder messages for "en" locale
    js_invalid_start      %s error(s) were found in your form:\n
    js_invalid_end        Fix these fields and try again!
    js_invalid_select     - You must choose an option for the "%s" field\n

Alternatively, you could specify this directly as a hashref:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    messages => {
                        js_invalid_start  => '%s error(s) were found in your form:\n',
                        js_invalid_end    => 'Fix these fields and try again!',
                        js_invalid_select => '- Choose an option from the "%s" list\n',
                    }
               );

Although in practice this is rarely useful, unless you just want to
tweak one or two things.

This system is easy, and there are many many messages that can be customized.
Here is a list of messages, along with their default values:

    form_invalid_checkbox	Check one or more options
    form_invalid_color  	red
    form_invalid_default	Invalid entry
    form_invalid_file   	Invalid filename
    form_invalid_input  	Invalid entry
    form_invalid_opentag	<font color="red"><b>
    form_invalid_radio  	Choose an option
    form_invalid_select 	Select an option from this list
    form_invalid_textarea	Please fill this in

    form_invalid_text   	<p>%s error(s) were encountered with your submission.
                            Please correct the fields %shighlighted%s below.</p>
    form_invalid_closetag	</b></font>
    form_invalid_password	Invalid entry

    form_required_text  	<p>Fields that are %shighlighted%s are required.</p>
    form_required_closetag	</b>
    form_required_opentag	<b>

    form_confirm_text   	Success! Your submission has been received %s.

    form_select_default 	-select-
    form_grow_default   	Additional %s
    form_other_default  	Other:
    form_reset_default  	Reset
    form_submit_default 	Submit

    js_noscript         	<p><font color="red"><b>Please enable JavaScript or use a newer browser.</b></font></p>
    js_invalid_start    	%s error(s) were encountered with your submission:
    js_invalid_end      	Please correct these fields and try again.

    js_invalid_checkbox 	- Check one or more of the "%s" options
    js_invalid_default  	- Invalid entry for the "%s" field
    js_invalid_file     	- Invalid filename for the "%s" field
    js_invalid_input    	- Invalid entry for the "%s" field
    js_invalid_multiple 	- Select one or more options from the "%s" list
    js_invalid_password 	- Invalid entry for the "%s" field
    js_invalid_radio    	- Choose one of the "%s" options
    js_invalid_select   	- Select an option from the "%s" list
    js_invalid_textarea 	- Please fill in the "%s" field

    mail_confirm_subject	%s Submission Confirmation
    mail_confirm_text   	Your submission has been received %s, and will be processed shortly.

The C<js_> tags are used in JavaScript alerts, whereas the C<form_> tags
are used in HTML and templates managed by FormBuilder.

In some of the messages, you will notice a C<%s> C<printf> format. This
is because these messages will include certain details for you. For example,
the C<js_invalid_start> tag will print the number of errors if you include
the C<%s> format tag. Of course, this is optional, and you can leave it out.

The best way to get an idea of how these work is to experiment a little.
It should become obvious really quickly.

=head1 SUBCLASSING MESSAGES

In addition, this module can be used as a base class which you can override to
create arbitrarily complicated message handling routines. For each message
type, B<FormBuilder> calls an accessor method for that message. For example:

    my $select_error = $mesg->form_invalid_select;

As such, you could create a sub class, say C<My::Messages>, that overrode
this message:

    package My::Messages;
    use base 'CGI::FormBuilder::Messages';

    sub form_invalid_select {
        return 'oopsie! the "%s" field is broken!';
    }

Then, you would instantiate an object from this class and pass that to 
the top-level C<new()> method:

    use CGI::FormBuilder;
    use My::Messages;

    my $mesg = My::Messages->new;   # provided in base class
    my $form = CGI::FormBuilder->new(
                    messages => $mesg
               );

If this doesn't make immediate sense, just stick to using a messages file.

=head1 SEE ALSO

L<CGI::FormBuilder>

=head1 REVISION

$Id: Messages.pm,v 1.16 2005/04/12 21:38:59 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
