
###########################################################################
# Copyright (c) 2000-2006 Nate Wiger <nate@wiger.org>. All Rights Reserved.
# Please visit www.formbuilder.org for tutorials, support, and examples.
###########################################################################

package CGI::FormBuilder::Messages::locale;

use strict;
use utf8;

our $REVISION = do { (my $r='$Revision: 100 $') =~ s/\D+//g; $r };
our $VERSION = '3.0501';

# First, create a hash of messages for this language

our %MESSAGES = (
    lang                  => 'es_ES',
    charset               => 'utf-8',

    js_invalid_start      => '%s error(es) fueron encontrados en su formulario:',
    js_invalid_end        => 'Por favor corrija en el/los campo(s) e intente de nuevo\n', 
    js_invalid_input      => 'Introduzca un valor v�lido para el campo: "%s"',
    js_invalid_select     => 'Escoja una opci�n de la lista: "%s"', 
    js_invalid_multiple   => '- Escoja una o m�s opciones de la lista: "%s"',
    js_invalid_checkbox   => '- Revise una o m�s de las opciones: "%s"',
    js_invalid_radio      => '- Escoja una de las opciones de la lista: "%s"',
    js_invalid_password   => '- Valor incorrecto para el campo: "%s"',
    js_invalid_textarea   => '- Por favor, rellene el campo: "%s"',
    js_invalid_file       => '- El nombre del documento es inv�lido para el campo: "%s"',
    js_invalid_default    => 'Introduzca un valor v�lido para el campo: "%s"',

    js_noscript           => 'Por favor habilite Javascript en su navegador o use una versi�n m�s reciente',

    form_required_text    => 'Los campos %sresaltados%s son obligatorios',
    form_invalid_text     => 'Se encontraron %s error(es) al realizar su pedido. Por favor corrija los valores en los campos %sresaltados%s y vuelva a intentarlo.',

    form_invalid_input    => 'Valor inv�lido',
    form_invalid_hidden   => 'Valor inv�lido',
    form_invalid_select   => 'Escoja una opci�n de la lista',
    form_invalid_checkbox => 'Escoja una o m�s opciones',
    form_invalid_radio    => 'Escoja una opci�n',
    form_invalid_password => 'Valor incorrecto',
    form_invalid_textarea => 'Por favor, rellene el campo',
    form_invalid_file     => 'Nombre del documento inv�lido',
    form_invalid_default  => 'Valor inv�lido',

    form_grow_default     => 'M�s %s',
    form_select_default   => '-Seleccione-',
    form_other_default    => 'Otro:',
    form_submit_default   => 'Enviar',
    form_reset_default    => 'Borrar',
    form_confirm_text     => '�Lo logr�! �El sistema ha recibido sus datos! %s.',

    mail_confirm_subject  => '%s Confirmaci�n de su pedido.',
    mail_confirm_text     => '�El sistema ha recibido sus datos! %s., Si desea hacer alguna pregunta, por favor responda a �ste correo electr�nico.',
    mail_results_subject  => '%s Resultado de su pedido.'
    );

# This method should remain unchanged
sub messages {
    return wantarray ? %MESSAGES : \%MESSAGES;
}

1;
__END__

