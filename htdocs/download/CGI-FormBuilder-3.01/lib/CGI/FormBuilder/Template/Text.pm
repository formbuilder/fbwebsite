
package CGI::FormBuilder::Template::Text;

=head1 NAME

CGI::FormBuilder::Template::Text - FormBuilder interface to Text::Template

=head1 SYNOPSIS

    my $form = CGI::FormBuilder->new(
                    fields   => \@whatever,
                    template => {
                        type => 'Text',
                        arg1 => val1,
                    },
               );

=cut

use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '3.01';

use CGI::FormBuilder::Util;
use Text::Template;

# This sub helps us to support all of Text::Template's argument naming conventions
sub tt_param_name {
    my ($arg, %h) = @_;
    my ($key) = grep { exists $h{$_} } ($arg, "\u$arg", "\U$arg", "-$arg", "-\u$arg", "-\U$arg");
    return $key || $arg;
}

sub render {
    my $form = shift;

    my %tmplopt = @_;
    my %tmplvar;

    # Like Template Toolkit, Text::Template can directly access Perl data
    for my $field ($form->field) {

        # Extract value since used often
        my @value = $field->tag_value;

        # Create a struct for each field
        $tmplvar{field}{"$field"} = {
             %$field,
             field   => $field->tag,
             value   => $value[0],
             values  => \@value,
             options => [$field->options],
             label   => $field->label,
             comment => $field->comment,
        };
        $tmplvar{field}{"$field"}{error} = $field->message if $field->invalid;
    }

    my ($tt_engine, $tt_data, $tt_var, $tt_output, $tt_fill_in);
    $tt_engine = $tmplopt{engine} || { };
    unless (UNIVERSAL::isa($tt_engine, 'Text::Template')) {
        $tt_engine->{&tt_param_name('type',%$tt_engine)}   ||= 'FILE';
        $tt_engine->{&tt_param_name('source',%$tt_engine)} ||= $tmplopt{template} ||
            puke "Text::Template source not specified, use the 'template' option";
        $tt_engine->{&tt_param_name('delimiters',%$tt_engine)} ||= [ '<%','%>' ];
        $tt_engine = Text::Template->new(%$tt_engine)
            || puke $Text::Template::ERROR;
    }

    if (ref($tmplopt{data}) eq 'ARRAY') {
        $tt_data = $tmplopt{data};
    } else {
        $tt_data = [ $tmplopt{data} ];
    }
    $tt_var  = $tmplopt{variable};      # optional var for nesting

    # special fields
    $tmplvar{'title'}  = $form->title;
    $tmplvar{'start'}  = $form->start . $form->statetags . $form->keepextras;
    $tmplvar{'submit'} = $form->submit;
    $tmplvar{'reset'}  = $form->reset;
    $tmplvar{'end'}    = $form->end;
    $tmplvar{'jshead'} = $form->script;
    $tmplvar{'invalid'}= $form->invalid;
    $tmplvar{'fields'} = [ map $tmplvar{field}{$_}, $form->field ];
    if ($tt_var) {
        push @$tt_data, { $tt_var => \%tmplvar };
    } else {
        push @$tt_data, \%tmplvar;
    }

    $tt_fill_in = $tmplopt{fill_in} || {};
    my $tt_fill_in_hash = $tt_fill_in->{&tt_param_name('hash',%$tt_fill_in)} || {};
    if (ref($tt_fill_in_hash) eq 'ARRAY') {
        push @$tt_fill_in_hash, @$tt_data;
    } else {
        $tt_fill_in_hash = [ $tt_fill_in_hash, @$tt_data ];
    }

    $tt_fill_in_hash = {} unless scalar(@$tt_fill_in_hash);
    $tt_fill_in->{&tt_param_name('hash',%$tt_fill_in)} = $tt_fill_in_hash;
    $tt_output = $tt_engine->fill_in(%$tt_fill_in)
        || puke "Text::Template expansion failed: $Text::Template::ERROR";

    return $form->header . $tt_output;
}




# End of Perl code
1;

=head1 DESCRIPTION

This engine adapts B<FormBuilder> to use C<Text::Template>. Documentation
is actually under L<CGI::FormBuilder::Template> or L<Text::Template>, so
please refer to those for more information.

=head1 SEE ALSO

L<CGI::FormBuilder>, L<CGI::FormBuilder::Template>, L<Text::Template>

=head1 REVISION

$Id: Text.pm,v 1.7 2005/02/10 20:15:52 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

Text::Template support is mainly due to huge contributions by Jonathan Buhacoff.
Thanks man.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
