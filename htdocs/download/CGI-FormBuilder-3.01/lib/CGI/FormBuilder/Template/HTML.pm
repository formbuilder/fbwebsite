
package CGI::FormBuilder::Template::HTML;

=head1 NAME

CGI::FormBuilder::Template::HTML - FormBuilder interface to HTML::Template

=head1 SYNOPSIS

    my $form = CGI::FormBuilder->new(
                    fields   => \@whatever,
                    template => {
                        type => 'HTML',
                        arg1 => val1,
                    },
               );

=cut

use Carp;
use strict;
use vars qw($VERSION);

$VERSION = '3.01';

use CGI::FormBuilder::Util;
use HTML::Template;

sub render {
    my $form = shift;

    my %tmplopt  = @_;
    $tmplopt{die_on_bad_params} = 0;    # force to avoid blow-ups
    my $tmpl = HTML::Template->new(%tmplopt);

    # a couple special fields
    my %tmplvar;
    $tmplvar{'form-title'}  = $form->title;
    $tmplvar{'form-start'}  = $form->start . $form->statetags . $form->keepextras;
    $tmplvar{'form-submit'} = $form->submit;
    $tmplvar{'form-reset'}  = $form->reset;
    $tmplvar{'form-end'}    = $form->end;
    $tmplvar{'js-head'}     = $form->script;

    # for HTML::Template, each data struct is manually assigned
    # to a separate <tmpl_var> and <tmpl_loop> tag
    for my $field ($form->field) {

        # Extract value since used often
        my @value = $field->tag_value;

        # assign the field tag
        $tmplvar{"field-$field"} = $field->tag;
        debug 2, "<tmpl_var field-$field> = " . $tmplvar{"field-$field"};

        # and the value tag - can only hold first value!
        $tmplvar{"value-$field"} = $value[0];
        debug 2, "<tmpl_var value-$field> = " . $tmplvar{"value-$field"};

        # and the label tag for the field
        $tmplvar{"label-$field"} = $field->label;
        debug 2, "<tmpl_var label-$field> = " . $tmplvar{"value-$field"};

        # and the comment tag
        $tmplvar{"comment-$field"} = $field->comment;

        # and any error
        $tmplvar{"error-$field"} = $field->message if $field->invalid;

        # create a <tmpl_loop> for multi-values/multi-opts
        # we can't include the field, really, since this would involve
        # too much effort knowing what type
        my @tmpl_loop = ();
        for my $opt ($field->options) {
            # Since our data structure is a series of ['',''] things,
            # we get the name from that. If not, then it's a list
            # of regular old data that we _toname if nameopts => 1 
            my($o,$n) = optval $opt;
            $n ||= $field->nameopts ? toname($o) : $o;
            my($slct, $chk) = ismember($o, @value) ? ('selected', 'checked') : ('','');
            debug 2, "<tmpl_loop loop-$field> = adding { label => $n, value => $o }";
            push @tmpl_loop, {
                label => $n,
                value => $o,
                checked => $chk,
                selected => $slct,
            };
        }

        # now assign our loop-field
        $tmplvar{"loop-$field"} = \@tmpl_loop;

        # finally, push onto a top-level loop named "fields"
        push @{$tmplvar{fields}}, {
            field   => $field->tag,
            value   => $value[0],
            values  => \@value,
            options => [ $field->options ],
            label   => $field->label,
            comment => $field->comment,
            error   => $field->error,
            loop    => \@tmpl_loop
        }
    }

    # loop thru each field we have and set the tmpl_param
    while(my($param, $tag) = each %tmplvar) {
        $tmpl->param($param => $tag);
    }

    # prepend header to template rendering
    return $form->header . $tmpl->output;
}



# End of Perl code
1;

=head1 DESCRIPTION

This engine adapts B<FormBuilder> to use C<HTML::Template>. Documentation
is actually under L<CGI::FormBuilder::Template> or L<HTML::Template>, so
please refer to those for more information.

=head1 SEE ALSO

L<CGI::FormBuilder>, L<CGI::FormBuilder::Template>, L<HTML::Template>

=head1 REVISION

$Id: HTML.pm,v 1.7 2005/02/10 20:15:52 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
