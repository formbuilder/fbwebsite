
package CGI::FormBuilder::Template::TT2;

=head1 NAME

CGI::FormBuilder::Template::TT2 - FormBuilder interface to Template Toolkit

=head1 SYNOPSIS

    my $form = CGI::FormBuilder->new(
                    fields   => \@whatever,
                    template => {
                        type => 'TT2',
                        arg1 => val1,
                    },
               );

=cut

use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '3.01';

use CGI::FormBuilder::Util;
use Template;

sub render {
    my $form = shift;

    my %tmplopt = @_;
    my %tmplvar;

    # Template Toolkit can access complex data pretty much unaided
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

    my($tt2engine, $tt2template, $tt2data, $tt2var, $tt2output);
    $tt2engine = $tmplopt{engine} || {};
    $tt2engine = Template->new($tt2engine)
        || puke $Template::ERROR unless UNIVERSAL::isa($tt2engine, 'Template');
    $tt2template = $tmplopt{template}
        || puke "Template Toolkit template not specified";
    $tt2data = $tmplopt{data} || {};
    $tt2var  = $tmplopt{variable};      # optional var for nesting

    # special fields
    $tmplvar{'title'}  = $form->title;
    $tmplvar{'start'}  = $form->start . $form->statetags . $form->keepextras;
    $tmplvar{'submit'} = $form->submit;
    $tmplvar{'reset'}  = $form->reset;
    $tmplvar{'end'}    = $form->end;
    $tmplvar{'jshead'} = $form->script;
    $tmplvar{'invalid'}= $form->invalid;
    $tmplvar{'fields'} = [ map $tmplvar{field}{$_}, $form->field ];
    if ($tt2var) {
        $tt2data->{$tt2var} = \%tmplvar;
    } else {
        $tt2data = { %$tt2data, %tmplvar };
    }

    $tt2engine->process($tt2template, $tt2data, \$tt2output)
        || puke $tt2engine->error();

    return $form->header . $tt2output;
}


# End of Perl code
1;

=head1 DESCRIPTION

This engine adapts B<FormBuilder> to use C<Template Toolkit>. Documentation
is actually under L<CGI::FormBuilder::Template> or L<Template>, so
please refer to those for more information.

=head1 SEE ALSO

L<CGI::FormBuilder>, L<CGI::FormBuilder::Template>, L<Template>

=head1 REVISION

$Id: TT2.pm,v 1.7 2005/02/10 20:15:52 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

Template Tookit support is due to a large patch from Andy Wardley. Thanks.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
