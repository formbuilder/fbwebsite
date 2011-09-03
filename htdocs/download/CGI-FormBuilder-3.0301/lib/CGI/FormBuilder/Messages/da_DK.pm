
# Copyright (c) 2005 Nate Wiger <nate@wiger.org>. All Rights Reserved.
# Use "perldoc CGI::FormBuilder::Messages" to read full documentation.

package CGI::FormBuilder::Messages::locale;

=head1 NAME

CGI::FormBuilder::Messages::da_DK - Danish messages for FormBuilder

=head1 SYNOPSIS

    use CGI::FormBuilder;

    my $form = CGI::FormBuilder->new(messages => 'auto');

=cut

use strict;
use utf8;

our $VERSION = '3.03';

# First, create a hash of messages for this language
# Then, change "locale" to the 2-letter country code, such as "en" or "de"
our %MESSAGES = (
    lang                  => 'da_DK',
    charset               => 'utf-8',

    js_invalid_start      => '%s fejl fundet i din indsendelse:',
    js_invalid_end        => 'Ret venligst disse felter og prøv igen.',

    js_invalid_input      => '- Forkert indhold i feltet "%s"',
    js_invalid_select     => '- Vælg en mulighed fra listen "%s"',
    js_invalid_multiple   => '- Vælg een eller flere muligheder fra listen "%s"',
    js_invalid_checkbox   => '- Markér een eller flere af "%s"\'s muligheder',
    js_invalid_radio      => '- Vælg een af "%s"\'s muligheder',
    js_invalid_password   => '- Forkert indhold i feltet "%s"',
    js_invalid_textarea   => '- Udfyld venligst feltet "%s"',
    js_invalid_file       => '- Forkert filnavn angivet for "%s"',
    js_invalid_default    => '- Forkert indhold i feltet "%s"',

    js_noscript           => 'Aktivér venligst JavaScript eller brug en nyere web-browser.',

    form_required_text    => 'Krævede felter er %sfremhævet%s.',

    form_invalid_text     => '%s fejl blev fundet i dine oplysninger. Ret venligst felterne %sfremhævet%s nedenfor.',

    form_invalid_input    => 'Forkert indhold',
    form_invalid_hidden   => 'Forkert indhold',
    form_invalid_select   => 'Vælg en mulighed fra listen',
    form_invalid_checkbox => 'Markér een eller flere muligheder',
    form_invalid_radio    => 'Vælg en mulighed',
    form_invalid_password => 'Forkert indhold',
    form_invalid_textarea => 'Udfyld venligst denne',
    form_invalid_file     => 'Forkert filnavn',
    form_invalid_default  => 'Forkert indhold',

    form_grow_default     => 'Yderligere %s',
    form_select_default   => '-vælg-',
    form_other_default    => 'Andet:',
    form_submit_default   => 'Indsend',
    form_reset_default    => 'Nulstil',
    
    form_confirm_text     =>  'Tillykke! Dine oplysninger er modtaget %s.',

    mail_confirm_subject  => '%s indsendelsesbekræftelse',
    mail_confirm_text     => <<EOT,
Dine oplysninger er modtaget %s
og vil blive ekspederet hurtigst muligt.

Hvis du har spørgsmål, så kontakt venligst vore medarbejdere
ved at besvare denne email.
EOT
    mail_results_subject  => '%s indsendelsesresultat',
);

# This method should remain unchanged
sub messages {
    return wantarray ? %MESSAGES : \%MESSAGES;
}

1;
__END__

=head1 DESCRIPTION

This module contains Danish messages for FormBuilder.

If the C<messages> option is set to C<auto> (the recommended but NOT
default setting), these messages will automatically be displayed to
Danish clients:

    my $form = CGI::FormBuilder->new(messages => 'auto');

To force display of these messages, use the following option:

    my $form = CGI::FormBuilder->new(messages => ':da_DK');

Thanks to Jonas Smedegaard for the Danish translation.

=head1 VERSION

$Id: da_DK.pm,v 1.13 2006/02/24 01:42:29 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2005-2006 Nate Wiger <nate@wiger.org>, Jonas Smedegaard <dr@jones.dk>.
All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
