
package CGI::FormBuilder::Field;

=head1 NAME

CGI::FormBuilder::Field - Internally used to create a FormBuilder field

=head1 SYNOPSIS

    use CGI::FormBuilder::Field;

    # delegated straight from FormBuilder
    my $f = CGI::FormBuilder::Field->new($form, name => 'whatever');

    # attribute functions
    my $n = $f->name;         # name of field
    my $n = "$f";             # stringify to $f->name

    my $t = $f->type;         # auto-type
    my @v = $f->value;        # auto-stickiness
    my @o = $f->options;      # options, aligned and sorted

    my $l = $f->label;        # auto-label
    my $h = $f->tag;          # field XHTML tag (name/type/value)
    my $s = $f->script;       # per-field JS validation script

    my $m = $f->message;      # error message if invalid
    my $m = $f->jsmessage;    # JavaScript error message

    my $r = $f->required;     # required?
    my $k = $f->validate;     # run validation check

    my $v = $f->tag_value;    # value in tag (stickiness handling)
    my $v = $f->cgi_value;    # CGI value if any
    my $v = $f->def_value;    # manually-specified value

    $f->field(opt => 'val');  # FormBuilder field() call

=cut

use Carp;
use strict;
use vars qw($VERSION @TAGATTR %VALIDATE $AUTOLOAD);

$VERSION = '3.02';

use CGI::FormBuilder::Util;

# what to generate for tag
@TAGATTR = qw(name type multiple jsclick);

# Catches for special validation patterns
# These are semi-Perl patterns; they must be usable by JavaScript
# as well so they do not take advantage of features JS can't use
# If the value is an arrayref, then the second arg is a tag to
# spit out at the person after the field label to help with format

%VALIDATE = (
    WORD     => '/^\w+$/',
    NAME     => '/^[a-zA-Z]+$/',
    NUM      => '/^-?\s*[0-9]+\.?[0-9]*$|^-?\s*\.[0-9]+$/',    # 1, 1.25, .25
    INT      => '/^-?\s*[0-9]+$/',
    FLOAT    => '/^-?\s*[0-9]+\.[0-9]+$/',
    PHONE    => '/^\d{3}\-\d{3}\-\d{4}$|^\(\d{3}\)\s+\d{3}\-\d{4}$/',
    INTPHONE => '/^\+\d+[\s\-][\d\-\s]+$/',
    EMAIL    => '/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/',
    CARD     => '/^\d{4}[\- ]?\d{4}[\- ]?\d{4}[\- ]?\d{4}$|^\d{4}[\- ]?\d{6}[\- ]?\d{5}$/',
    MMYY     => '/^(0?[1-9]|1[0-2])\/?[0-9]{2}$/',
    MMYYYY   => '/^(0?[1-9]|1[0-2])\/?[0-9]{4}$/',
    DATE     => '/^(0?[1-9]|1[0-2])\/?(0?[1-9]|[1-2][0-9]|3[0-1])\/?[0-9]{4}$/',
    EUDATE   => '/^(0?[1-9]|[1-2][0-9]|3[0-1])\/?(0?[1-9]|1[0-2])\/?[0-9]{4}$/',
    TIME     => '/^[0-9]{1,2}:[0-9]{2}$/',
    AMPM     => '/^[0-9]{1,2}:[0-9]{2}\s*([aA]|[pP])[mM]$/',
    ZIPCODE  => '/^\d{5}$|^\d{5}\-\d{4}$/',
    STATE    => '/^[a-zA-Z]{2}$/',
    COUNTRY  => '/^[a-zA-Z]{2}$/',
    IPV4     => '/^([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])$/',
    NETMASK  => '/^([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])$/',
    FILE     => '/^[\/\w\.\-_]+$/',
    WINFILE  => '/^[a-zA-Z]:\\[\\\w\s\.\-]+$/',
    MACFILE  => '/^[:\w\.\-_]+$/',
    USER     => '/^[-a-zA-Z0-9_]{4,8}$/',
    HOST     => '/^[a-zA-Z0-9][-a-zA-Z0-9]*$/',
    DOMAIN   => '/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/',
    ETHER    => '/^[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}$/i',
    # Many thanks to Mark Belanger for these additions
    FNAME    => '/^[a-zA-Z]+[- ]?[a-zA-Z]*$/',
    LNAME    => '/^[a-zA-Z]+[- ]?[a-zA-Z]+\s*,?([a-zA-Z]+|[a-zA-Z]+\.)?$/',
    CCMM     => '/^0[1-9]|1[012]$/',
    CCYY     => '/^[1-9]{2}$/',
);

# stringify to name
use overload '""'   => sub { $_[0]->name },
             '0+'   => sub { $_[0]->name },
             'bool' => sub { $_[0]->name },
             'eq'   => sub { $_[0]->name eq $_[1] };

sub new {
    puke "Not enough arguments for Field->new()" unless @_ > 1;
    my $self = shift;

    my $form = shift;       # need for top-level attr
    my %opt  = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    $opt{_form} = $form;    # parental ptr
    puke "Missing name for field() in Field->new()" unless $opt{name};

    my $class = ref($self) || $self;
    return bless \%opt, $class;
}

sub field {
    my $self = shift;
    my %opt  = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    while (my($k,$v) = each %opt) {
        next if $k eq 'name';   # segfault??
        $self->{$k} = $v;
    }
    return $self->value;    # needed for @v = $form->field('name')
}

*override = \&force;    # CGI.pm
sub force {
    my $self = shift;
    $self->{force} = shift if @_;
    return $self->{force} || $self->{override};
}

# grab the field_other field if other => 1 specified
sub other {
    my $self = shift;
    $self->{other} = shift if @_;
    return unless $self->{other};
    $self->{other} = {} unless ref $self->{other};
    $self->{other}{name} = $self->othername;
    return wantarray ? %{$self->{other}} : $self->{other};
}

sub othername {
    my $self = shift;
    return $self->{_form}->othername . '_' . $self->name;
}

sub growname {
    my $self = shift;
    return $self->{_form}->growname . '_' . $self->name;
}

sub cgi_value {
    my $self = shift;
    debug 2, "$self->{name}: called \$field->cgi_value";
    puke "Cannot set \$field->cgi_value manually" if @_;
    if (my @v = $self->{_form}{params}->param($self->name)) {
        if ($self->other && $v[0] eq $self->othername) {
            debug 1, "$self->{name}: redoing value from _other field";
            @v = $self->{_form}{params}->param($self->othername);
        }
        local $" = ',';
        debug 2, "$self->{name}: cgi value = (@v)";
        return wantarray ? @v : $v[0];
    }
    return;
}

sub def_value {
    my $self = shift;
    debug 2, "$self->{name}: called \$field->def_value";
    if (@_) {
        $self->{value} = cleanargs(@_);  # manually set
        delete $self->{_cache}{type};    # clear auto-type
    }
    my @v = autodata $self->{value};
    local $" = ',';
    debug 2, "$self->{name}: def value = (@v)";
    return wantarray ? @v : $v[0];
}

# CGI.pm happiness
*default  = \&value;
*defaults = \&value;
*values   = \&value;
sub value {
    my $self = shift;
    debug 2, "$self->{name}: called \$field->value";
    if (@_) {
        $self->{value} = cleanargs(@_);  # manually set
        delete $self->{_cache}{type};    # clear auto-type
    }
    unless ($self->force) {
        # CGI wins if stickiness is set
        debug 2, "$self->{name}: sticky && ! force";
        if (my @v = $self->cgi_value) {
            local $" = ',';
            debug 1, "$self->{name}: returning value (@v)";
            return wantarray ? @v : $v[0];
        }
    }
    debug 2, "no cgi found, returning def_value";
    # no CGI value, or value was forced, or not sticky
    return $self->def_value;
}

# The value in the <tag> may be different than in code (sticky)
sub tag_value {
    my $self = shift;
    debug 2, "$self->{name}: called \$field->tag_value";
    if (@_) {
        # setting the tag_value manually is odd...
        $self->{tag_value} = cleanargs(@_);
        delete $self->{_cache}{type};
    }
    return $self->{tag_value} if $self->{tag_value};

    if ($self->sticky && ! $self->force) {
        # CGI wins if stickiness is set
        debug 2, "$self->{name}: sticky && ! force";
        if (my @v = $self->cgi_value) {
            local $" = ',';
            debug 1, "$self->{name}: returning value (@v)";
            return wantarray ? @v : $v[0];
        }
    }
    debug 2, "no cgi found, returning def_value";
    # no CGI value, or value was forced, or not sticky
    return $self->def_value;
}

sub type {
    local $^W = 0;    # -w sucks
    my $self = shift;
    $self->{type} = lc shift if @_;

    # catch for old way of saying type => 'static'
    if ($self->{type} =~ /^(static|disabled)$/i) {
        $self->{lc($1)} = 1;
        delete $self->{type};   # still auto-generate a type
    }

    # manually set
    debug 2, "$self->{name}: called \$field->type (current = $self->{type})";
    return lc $self->{type} if $self->{type};

    # The $field->type method is called so often that it really slows
    # things down. As such, we cache the type and use it *unless* the
    # value has been updated manually (we assume one CGI instance).
    # See value() for its deletion of this cache
    return $self->{_cache}{type} if $self->{_cache}{type};

    # Unless the type has been set explicitly, we make a guess based on how many items
    # there are to display, which is basically, how many options we have
    # Our 'jsclick' option is now changed down in the javascript section, fixing a bug
    my $type;
    my $name = $self->name;
    if ($self->{_form}->smartness) {
        debug 1, "$name: input type not set, checking for options"; 
        if (my $n = $self->options) {
            debug 2, "$name: has options, so setting to select|radio|checkbox";
            if ($n >= $self->selectnum) {
                debug 2, "$name: has more than selectnum (", $self->selectnum, ") options, setting to 'select'";
                $type = 'select';
            } else {
                # Something is a checkbox if it is a multi-valued box.
                # However, it is *also* a checkbox if only single-valued options,
                # otherwise you can't unselect it.
                my @v = $self->def_value;   # only on manual, not dubious CGI
                if ($self->multiple || @v > 1 || $n == 1) {
                    debug 2, "$name: has multiple select < selectnum, setting to 'checkbox'";
                    $type = 'checkbox';
                } else {
                    debug 2, "$name: has singular select < selectnum, setting to 'radio'";
                    $type = 'radio';
                }
            }
        } elsif ($self->{_form}->smartness > 1) {
            debug 2, "$name: smartness > 1, auto-inferring type based on value";
            # only autoinfer field types based on values with high smartness
            my @v = $self->def_value;   # only on manual, not dubious CGI
            if ($name =~ /passw[or]*d/i) {
                $type = 'password';
            } elsif ($name =~ /(?:details?|comments?)$/i
                    || grep /\n|\r/, @v || $self->cols || $self->rows) {
                $type = 'textarea';
            } elsif ($name =~ /\bfile/i) {
                $type = 'file';
            }
        }
    }
    $type ||= 'text';   # default if no fancy settings matched or no smartness

    # Store type in cache for speediness
    $self->{_cache}{type} = $type;

    debug 1, "$name: field set to type '$type'";
    return $type;
}

sub label {
    my $self = shift;
    $self->{label} = shift if @_;
    return $self->{label} if defined $self->{label};    # manually set
    return toname($self->name);
}

sub attr {
    my $self = shift;
    if (my $k = shift) {
        $self->{$k} = shift if @_;
        return exists $self->{$k} ? $self->{$k} : $self->{_form}->$k;
    } else {
        # exhaustive expansion, but don't invoke validate().
        my %ret;
        for my $k (@TAGATTR, keys %$self) {
            my $v;
            next if $k =~ /^_/ || $k eq 'validate';   # don't invoke validate
            if ($k eq 'jsclick') {
                # always has to be a special fucking case
                $v = $self->{$k};
                $k = $self->jstype;
            } elsif (exists $self->{$k}) {
                # flat val
                $v = $self->{$k};
            } else {
                $v = $self->$k;
            }
            next unless defined $v;

            debug 3, "$self->{name}: \$attr{$k} = '$v'";
            $ret{$k} = $v;
        }
        return wantarray ? %ret : \%ret;
    }
}

sub multiple {
    my $self = shift;
    if (@_) {
        $self->{multiple} = shift;       # manually set
        delete $self->{_cache}{type};    # clear auto-type
    }
    return 'multiple' if $self->{multiple};         # manually set
    my @v = $self->tag_value;
    return 'multiple' if @v > 1;
    return;
}

sub options {
    my $self = shift;
    if (@_) {
        $self->{options} = shift;        # manually set
        delete $self->{_cache}{type};    # clear auto-type
    }
    return unless $self->{options};

    # align options per internal settings
    my @opt = optalign($self->{options});

    # scalar is just counting length, so skip sort
    return @opt unless wantarray;

    # sort if requested
    @opt = optsort($self->sortopts, @opt) if $self->sortopts;

    return @opt;
}

# per-field messages
sub message {
    my $self = shift;
    $self->{message} = shift if @_;
    my $mess = $self->{message};
    unless ($mess) {
        my $type = shift || $self->type;
        my $et = 'form_invalid_' . ($type eq 'text' ? 'input' : $type);
        $et    = 'form_invalid_input' if $self->other;     # other fields assume text
        $mess  = sprintf(($self->{_form}{messages}->$et
                    || $self->{_form}{messages}->form_invalid_default), $self->label);
    }
    return $mess;
}

sub jsmessage {
    my $self = shift;
    $self->{jsmessage} = shift if @_;
    my $mess = $self->{jsmessage} || $self->{message};
    unless ($mess) {
        my $type = shift || $self->type;
        my $et = 'js_invalid_' . ($type eq 'text' ? 'input' : $type);
        $et    = 'js_invalid_input' if $self->other;       # other fields assume text
        $mess  =  sprintf(($self->{_form}{messages}->$et
                    || $self->{_form}{messages}->js_invalid_default), $self->label);
    }
    return $mess
}

# simple error wrapper (why wasn't this here?)
sub error {
    my $self = shift;
    return $self->invalid ? $self->message : '';
}

sub jstype {
    my $self = shift;
    my $type = shift || $self->type;
    return ($type eq 'radio' || $type eq 'checkbox') ? 'onclick' : 'onchange';
}

sub script {
    my $self = shift;
    my $name = $self->name;
    my $pattern = $self->{validate};
    return '' unless $self->javascript && ($pattern || $self->required);

    debug 1, "$name: generating JavaScript validation code";
    my $jsfunc = '';

    # Special catch, since many would assume this would work
    if (ref $pattern eq 'Regexp') {
        puke "To use a regex in a 'validate' option you must specify ".
             "it in single quotes, like '/^\\w+\$/' - failed on '$name' field";
    }

    # Check our hash to see if it's a special pattern
    $pattern = $VALIDATE{$pattern} if $VALIDATE{$pattern};

    # Holders for different parts of JS code
    my $close_brace = '';
    my $in = indent(my $idt = 1);   # indent

    # make field name JS-safe
    my $jsfield = tovar($name);

    # Need some magical JavaScript crap to figure out the type of value
    # God the DOM sucks so much ass!!!! I can't believe the value element
    # changes based on the type of field!!
    #
    # Note we have to use form.elements['name'] instead of just form.name
    # as the JAPH using this module may have defined fields like "u.type"
    #
    # Finally, we expand our error message above, way up here, so that
    # we can simply integrate the custom message with the predefined text

    my $type = shift || $self->type;
    my $alertstr = escapejs($self->jsmessage);  # handle embedded '
    $alertstr .= '\n';

    debug 2, "$name: type is '$type', generating JavaScript";
    if ($type eq 'select') {

        # Get value for field from select list
        # Always assume it's multiple to guarantee we get all values
        $jsfunc .= <<EOJS;
    // $name: select list, always assume it's multiple to get all values
    var $jsfield = null;
    var selected_$jsfield = 0;
    for (var loop = 0; loop < form.elements['$name'].options.length; loop++) {
        if (form.elements['$name'].options[loop].selected) {
            $jsfield = form.elements['$name'].options[loop].value;
            selected_$jsfield++;
EOJS

        # Add catch for "other" if applicable
        if ($self->other) {
            my $oth = $self->othername;
            $jsfunc .= <<EOJS;
            if ($jsfield == '$oth') $jsfield = form.elements['$oth'].value;
EOJS
        }

        $close_brace = <<EOJS;

        } // if
    } // for $name
EOJS
        $close_brace .= <<EOJS if $self->required;
    if (! selected_$jsfield) {
        alertstr += '$alertstr';
        invalid++;
    }
EOJS
        # indent the very last if/else tests so they're in the for loop
        $in = indent($idt += 2);

    } elsif ($type eq 'checkbox' && $self->options == 1) {

        # Simple single-element on/off checkbox
        $jsfunc .= <<EOJS;
    // $name: single-element checkbox
    var $jsfield = null;
    if (document.getElementById('$name') != null && form.elements['$name'].checked) {
        $jsfield = form.elements['$name'].value;
    }
EOJS

    } elsif ($type eq 'radio' || $type eq 'checkbox') {

        # Get field from radio buttons or checkboxes
        # Must cycle through all again to see which is checked. yeesh.
        # However, this only works if there are MULTIPLE checkboxes!
        # The fucking JS DOM *changes* based on one or multiple boxes!?!?!
        # Damn damn damn I hate the JavaScript DOM so damn much!!!!!!

        $jsfunc .= <<EOJS;
    // $name: radio group or multiple checkboxes
    var $jsfield = null;
    var selected_$jsfield = 0;
    for (var loop = 0; loop < form.elements['$name'].length; loop++) {
        if (form.elements['$name']\[loop].checked) {
            $jsfield = form.elements['$name']\[loop].value;
            selected_$jsfield++;
EOJS

        # Add catch for "other" if applicable
        if ($self->other) {
            my $oth = $self->othername;
            $jsfunc .= <<EOJS;
            if ($jsfield == '$oth') $jsfield = form.elements['$oth'].value;
EOJS
        }

        $close_brace = <<EOJS;

        } // if
    } // for $name
EOJS
        # required?
        $close_brace .= <<EOJS if $self->required;
    if (! selected_$jsfield) {
        alertstr += '$alertstr';
        invalid++;
    }
EOJS
        # indent the very last if/else tests so they're in the for loop
        $in = indent($idt += 2);

    } elsif ($self->growable) {
        # special handling for growable, have to dynamically
        # find out how many have been created
        $jsfunc .= <<EOJS;
    // $name: growable text or file box
    var $jsfield = null;
    var entered_$jsfield = 0;
    var i = 0;
    while (1) {
        var growel = document.getElementById('$jsfield'+'_'+i);
        if (growel == null) break;  // last element
        $jsfield = growel.value;
        entered_$jsfield++;
        i++;
EOJS

        $close_brace = <<EOJS;

    } // while $name
EOJS

        # required?
        $close_brace .= <<EOJS if $self->required;
    if (! entered_$jsfield) {
        alertstr += '$alertstr';
        invalid++;
    }
EOJS
        # indent the very last if/else tests so they're in the while loop
        $in = indent($idt += 1);

    } else {

        # get value from text or other straight input
        # at least this part makes some sense
        $jsfunc .= <<EOJS;
    // $name: standard text, hidden, password, or textarea box
    var $jsfield = form.elements['$name'].value;
EOJS

    }

    # Our fields are only required if the required option is set
    # So, if not set, add a not-null check to the if below
    my $notnull = $self->required 
                     ? qq[$jsfield == null ||]                     # must have or error
                     : qq[$jsfield != null && $jsfield != "" &&];  # only care if filled in

    # hashref is a grouping per-language
    if (ref $pattern eq 'HASH') {
        $pattern = $pattern->{javascript} || return;
    }

    if ($pattern =~ m#^m?(\S)(.*)\1$#) {
        # JavaScript regexp
        ($pattern = $2) =~ s/\\\//\//g;
        $pattern =~ s/\//\\\//g;
        $jsfunc .= qq[${in}if ($notnull ! $jsfield.match(/$pattern/)) {\n];
    }
    elsif (ref $pattern eq 'ARRAY') {
        # Must be w/i this set of values
        # Can you figure out how this piece of Perl works? No, seriously, I forgot.
        $jsfunc .= qq[${in}if ($notnull ($jsfield != ']
                 . join("' && $jsfield != '", @{$pattern}) . "')) {\n";
    }
    elsif ($pattern eq 'VALUE' || ($self->required && (! $pattern || ref $pattern eq 'CODE'))) {
        # Not null (for required sub refs, just check for a value)
        $jsfunc .= qq[${in}if ($notnull $jsfield === "") {\n];
    }
    else {
        # Literal string is literal code to execute, but provide
        # a warning just in case
        belch "Validation string '$pattern' may be a typo of a builtin pattern"
            if $pattern =~ /^[A-Z]+$/;
        $jsfunc .= qq[${in}if ($notnull $jsfield $pattern) {\n];
    }

    # add on our alert message, but only if it's required
    $jsfunc .= <<EOJS;
$in    alertstr += '$alertstr';
$in    invalid++;
$in}$close_brace
EOJS

    return $jsfunc;
}

*render = \&tag;
sub tag {
    local $^W = 0;    # -w sucks
    my $self = shift;
    my $type = shift || $self->type;
    $type = 'hidden' if $self->static;

    # Get attr from tag
    my %attr = $self->attr;

    # Type handling (maze)
    my $usertype = $attr{type} || ''; # user's type
    $attr{type} = $type;     # override
    delete $attr{value};     # useless in all tags

    # Disable field/form
    $attr{disabled} = 'disabled' if $self->disabled;

    # Setup class for stylesheets and JS vars
    $attr{class} ||= $self->{_form}{styleclass} . $type if $self->{_form}{stylesheet};
    my $jspre = $self->{_form}->jsprefix;

    my $tag   = '';
    my @value = $self->tag_value;   # sticky is different in <tag>
    my @opt   = $self->options;
    debug 2, "my(@opt) = \$field->options";

    # Add in our "Other:" option if applicable
    push @opt, [$self->othername, $self->{_form}{messages}->form_other_default]
             if $self->other;

    debug 2, "$self->{name}: generating $type input type";
    if ($type eq 'select') {
        # First the top-level select
        delete $attr{type};     # type="select" invalid
        $attr{multiple} = $self->multiple if $self->multiple;

        # Prefix options with "-select-"
        unshift @opt, ['', $self->{_form}{messages}->form_select_default]
                if $self->{_form}->smartness && ! $attr{multiple};  # set above

        # Special event handling for our _other field
        if ($self->other && $self->javascript) {
            my $n = @opt - 1;           # last element
            my $b = $self->othername;   # box
            # w/o newlines
            $attr{onChange} = "if (this.selectedIndex == $n) { "
                            . "${jspre}other_on('$b') } else { ${jspre}other_off('$b') }";
        }

        # render <select> tag
        $tag .= htmltag($type, %attr);

        belch "No options specified for field '$self->{name}' of type '$type'" unless @opt;
        for my $opt (@opt) {
            # Since our data structure is a series of ['',''] things,
            # we get the name from that. If not, then it's a list
            # of regular old data that we toname() if nameopts => 1
            my($o,$n) = optval($opt);
            $n ||= $attr{labels}{$o} || ($self->nameopts ? toname($o) : $o);
            my %slct = ismember($o, @value) ? (selected => 'selected') : ();
            $slct{value} = $o;
            $tag .= htmltag('option', %slct)
                  . ($self->cleanopts ? escapehtml($n) : $n)
                  . '</option>';
        }
        $tag .= '</select>';
    }
    elsif ($type eq 'radio' || $type eq 'checkbox') {
        my $checkbox_table = 0;  # toggle
        my $checkbox_col = 0;
        if ($self->columns > 0) {
            $checkbox_table = 1;
            $tag .= $self->{_form}->table(border => 0);
        }

        belch "No options specified for field '$self->{name}' of type '$type'" unless @opt;
        for my $opt (@opt) {
            #  Divide up checkboxes in a user-controlled manner
            if ($checkbox_table) {
                $tag .= "\n<tr>" if $checkbox_col % $self->columns == 0;
                $tag .= '<td>' . $self->{_form}->font;
            }
            # Since our data structure is a series of ['',''] things,
            # we get the name from that. If not, then it's a list
            # of regular old data that we toname() if nameopts => 1
            my($o,$n) = optval($opt);
            $n ||= $attr{labels}{$o} || ($self->nameopts ? toname($o) : $o);
            my @slct = ismember($o, @value) ? (checked => 'checked') : ();

            # reset some attrs
            $attr{value} = $o;
            if (@opt == 1) {
                # single option checkboxes do not modify id
                $attr{id} ||= $attr{name};
            } else {
                # all others add the current option name
                $attr{id} = $o eq $self->othername ? "_$attr{name}" 
                                                   : "$attr{name}_$o";
            }

            # Special event handling for our _other field
            if ($self->other && $self->javascript) {
                my $b = $self->othername;   # box
                if ($n eq $self->{_form}{messages}->form_other_default) {
                    # w/o newlines
                    $attr{onclick} = "var box = document.getElementById('$b'); "
                                   . "box.removeAttribute('disabled');";
                    $attr{onclick} = "${jspre}other_on('$b')";
                } else {
                    # w/o newlines
                    $attr{onclick} = "var box = document.getElementById('$b'); "
                                   . "box.setAttribute('disabled', 'disabled');";
                    $attr{onclick} = "${jspre}other_off('$b')";
                }
            }

            # Each radio/checkbox gets a human thingy with <label> around it
            $tag .= htmltag('input', %attr, @slct);
            $tag .= $checkbox_table ? ('</td><td>'.$self->{_form}->font) : ' ';
            $tag .= htmltag('label', for => $attr{id})
                  . ($self->cleanopts ? escapehtml($n) : $n)
                  . '</label> ';

            $tag .= '<br />' if $self->linebreaks;

            if ($checkbox_table) {
                $checkbox_col++;
                $tag .= '</td>';
                $tag .= '</tr>' if $checkbox_col % $self->columns == 0;
            }
        }
        $tag .= '</table>' if $checkbox_table;
    }
    elsif ($type eq 'textarea') {
        my $text = join "\n", @value;
        delete $attr{value};
        $tag .= htmltag('textarea', %attr) . escapehtml($text) . '</textarea>';
    }
    else {
        # We iterate over each value - this is the only reliable
        # way to handle multiple form values of the same name
        # (i.e., multiple <input> or <hidden> fields)
        @value = (undef) unless @value; # this creates a single-element array

        # growable handling
        my $count = 0;  # for tracking the size of growable fields
        my $limit;      # for providing (optional) limits to growable fields 
        my $at_limit;   # have we reached the limit of a growable field?
        if ($self->growable && $self->growable ne 1) {
            $limit = $self->growable;
        }

        for my $value (@value) {
            if ($limit && $count == $limit) {
                belch "Number of supplied values (" . @value . ")"
                    . " for '$attr{name}' exceeds growable limit $limit - discarding excess";
                $at_limit = 1;
                last;
            }
            
            # setup the value
            $attr{value} = $value;      # override
            delete $attr{value} unless defined $value;

            if ($self->growable && $self->javascript) {
                # the inputs in growable fields need a unique id for fb_grow()
                $attr{id} = "$attr{name}_$count";
                $count++;
            }

            # render the tag
            $tag .= htmltag('input', %attr);

            # if have options, lookup the label instead of the true value
            for (@opt) {
                my($o,$n) = optval($_);
                $n ||= $attr{labels}{$o} || ($self->nameopts ? toname($o) : $o);
                $value = $n, last if $n;
            }

            # print the value out too when in a static context, EXCEPT for
            # manually hidden fields (those that the user hid themselves)
            my $tagcom = escapehtml($value);
            $tag .= $tagcom . ' ' if $self->static && $tagcom && $usertype ne 'hidden';
            debug 2, "if ", $self->static, " && $tagcom && $usertype ne 'hidden';";

            if ($self->growable && $self->javascript) {
                # put linebreaks between the input tags in growable fields
                # this puts the "Additonal [label]" button on the same line
                # as the last input tag
                $tag .= '<br />' unless $count == @value;
            } else {
                $tag .= '<br />' if $self->linebreaks;
            }
        }
        # check to see if we just hit the limit
        $at_limit = 1 if $limit && $count == $limit;

        # add the "Additional [label]" button
        if ($self->growable && $self->javascript) {
            $tag .= ' ' . htmltag('input',
                id      => $self->growname,
                type    => 'button',
                onclick => "${jspre}grow('$attr{name}')",
                value   => sprintf($self->{_form}{messages}->form_grow_default, $self->label),
                ( $at_limit ? ( disabled => 'disabled') : () ),
            );
        }

        # special catch to make life easier (too action-at-a-distance?)
        # if there's a 'file' field, set the form enctype if they forgot
        if ($type eq 'file' && $self->{_form}->smartness) {
            $self->{_form}{enctype} ||= 'multipart/form-data';
            debug 2, "verified enctype => 'multipart/form-data' for 'file' field";
        }
    }

    if ($self->other) {
        # add an additional tag for our _other field
        my %oa = $self->other;  # other attr
        # default settings
        $oa{type}  ||= 'text';
        $oa{disabled} = 'disabled' if $self->javascript;   # fanciness
        if ($self->sticky and my $v = $self->{_form}->cgi_param($self->othername)) {
            $oa{value} = $v;
        }
        $tag .= ' ' . htmltag('input', %oa);
    }

    debug 2, "$self->{name}: generated tag = $tag";
    return $tag;       # always return scalar tag
}

sub validate () {

    # This function does all the validation on the Perl side.
    # It doesn't generate JavaScript; see render() for that...

    my $self = shift;
    my $form = $self->{_form};   # alias for examples (paint-by-numbers)
    local $^W = 0;               # -w sucks

    my $pattern = shift || $self->{validate};
    my $field   = $self->name;

    debug 1, "$self->{name}: called \$field->validate(@_) for field '$field'";

    # Check our hash to see if it's a special pattern
    ($pattern) = autodata($VALIDATE{$pattern}) if $VALIDATE{$pattern};

    # Hashref is a grouping per-language
    if (ref $pattern eq 'HASH') {
        $pattern = $pattern->{perl} || return 1;
    }

    # Counter for fail or success
    my $bad = 0;

    # Loop thru, and if something isn't valid, we tag it
    my $atleastone = 0;
    $self->{invalid} ||= 0;
    for my $value ($self->value) {
        my $thisfail = 0;

        # only continue if field is required or filled in
        if ($self->required) {
            debug 1, "$field: is required per 'required' param";
        } else {
            debug 1, "$field: is optional per 'required' param";
            next unless length($value) && defined($pattern);
            debug 1, "$field: ...but is defined, so still checking";
        }

        $atleastone++;
        debug 1, "$field: validating ($value) against pattern '$pattern'";

        if ($pattern =~ m#^m(\S)(.*)\1$# || $pattern =~ m#^(/)(.*)\1$#) {
            # it be a regexp, handle / escaping
            (my $tpat = $2) =~ s#\\/#/#g;
            $tpat =~ s#/#\\/#g;
            debug 2, "$field: does '$value' =~ /$tpat/ ?";
            unless ($value =~ /$tpat/) {
                $thisfail = ++$bad;
            }
        } elsif (ref $pattern eq 'ARRAY') {
            # must be w/i this set of values
            debug 2, "$field: is '$value' in (@{$pattern}) ?";
            unless (ismember($value, @{$pattern})) {
                $thisfail = ++$bad;
            }
        } elsif (ref $pattern eq 'CODE') {
            # eval that mofo, which gives them $form
            debug 2, "$field: does $pattern($value) ret true ?";
            unless (&{$pattern}($value)) {
                $thisfail = ++$bad;
            }
        } elsif ($pattern eq 'VALUE') {
            # Not null
            debug 2, "$field: length '$value' > 0 ?";
            unless (defined($value) && length($value)) {
                $thisfail = ++$bad;
            }
        } else {
            # literal string is a literal comparison, but warn of typos...
            belch "Validation string '$pattern' may be a typo of a builtin pattern"
                if ($pattern =~ /^[A-Z]+$/); 
            # must reference to prevent serious problem if $value = "'; system 'rm -f /'; '"
            debug 2, "$field: '$value' $pattern ? 1 : 0";
            unless (eval qq(\$value $pattern ? 1 : 0)) {
                $thisfail = ++$bad;
            }
            belch "Literal code eval error in validate: $@" if $@;
        }

        # Just for debugging's sake
        $thisfail ? debug 2, "$field: pattern FAILED"
                  : debug 2, "$field: pattern passed";
    }

    # If not $atleastone and they asked for validation, then we
    # know that we have an error since this means no values
    if ($bad || (! $atleastone && $self->required)) {
        debug 1, "$field: validation FAILED";
        $self->{invalid} = $bad || 1;
        return;
    } else {
        debug 1, "$field: validation passed";
        delete $self->{invalid};    # in case of previous run
        return 1;
    }
}

sub invalid () {
    my $self = shift;
    # return stored value, assume validate run first
    @_ ? $self->{invalid} = shift : $self->{invalid};
}

sub static () {
    my $self = shift;
    $self->{static} = shift if @_;
    return $self->{static} if exists $self->{static};
    # check parent for this as well
    return $self->{_form}{static};
}

sub disabled () {
    my $self = shift;
    $self->{disabled} = shift if @_;
    return $self->{disabled} if exists $self->{disabled};
    # check parent for this as well
    return $self->{_form}{disabled};
}

sub javascript () {
    my $self = shift;
    $self->{javascript} = shift if @_;
    return $self->{javascript} if exists $self->{javascript};
    # check parent for this as well
    return $self->{_form}{javascript};
}

sub growable () {
    my $self = shift;
    $self->{growable} = shift if @_;
    return unless $self->{growable};
    # check to make sure we're only a text or file type
    unless ($self->type eq 'text' || $self->type eq 'file') {
        belch "The 'growable' option only works with 'text' or 'file' fields";
        return;
    }
    return $self->{growable};
}

sub name () {
    my $self = shift;
    $self->{name} = shift if @_;
    confess "[".__PACKAGE__."::name] Fatal: Attempt to manipulate unnamed field"
        unless exists $self->{name};
    return $self->{name};
}

sub DESTROY { 1 }

sub AUTOLOAD {
    # This allows direct addressing by name, for quicker usage
    my $self = shift;
    my($name) = $AUTOLOAD =~ /.*::(.+)/;

    debug 3, "-> dispatch to \$field->{$name} = @_";
    croak "self not ref in AUTOLOAD" unless ref $self; # nta

    $self->{$name} = shift if @_;
    return $self->{$name};
}

1;
__END__

=head1 DESCRIPTION

This module is internally used by B<FormBuilder> to create and maintain
field information. Usually, you will not want to directly access this
set of data structures. However, one big exception is if you are going
to micro-control form rendering. In this case, you will need to access
the field objects directly.

To do so, you will want to loop through the fields in order:

    for my $field ($form->field) {

        # $field holds an object stringified to a field name
        if ($field =~ /_date$/) {
            $field->sticky(0);  # clear CGI value
            print "Enter $field here:", $field->tag;
        } else {
            print $field->label, ': ', $field->tag;
        }
    }

As illustrated, each C<$field> variable actually holds a stringifiable
object. This means if you print them out, you will get the field name,
allowing you to check for certain fields. However, since it is an object,
you can then run accessor methods directly on that object.

The most useful method is C<tag()>. It generates the HTML input tag
for the field, including all option and type handling, and returns a 
string which you can then print out or manipulate appropriately.

Second to this method is the C<script> method, which returns the appropriate
JavaScript validation routine for that field. This is useful at the top of
your form rendering, when you are printing out the leading C<< <head> >> section
of your HTML document. It is called by the C<$form> method of the same name.

The following methods are provided for each C<$field> object.

=head1 METHODS

=head2 new($form, %args)

This creates a new C<$field> object. The first argument must be a reference
to the top-level C<$form> object, for callbacks. The remaining arguments
should be hash, of which one C<key/value> pair must specify the C<name> of
the field. Normally you should not touch this method. Ever.

=head2 field(%args)

This is a delegated field call. This is how B<FormBuilder> tweaks its fields.
Once you have a C<$field> object, you call this method the exact same way
that you would call the main C<field()> method, minus the field name. Again
you should use the top-level call instead.

=head2 jsfunc()

Returns the appropriate JavaScript validation code (see above).

=head2 label($str)

This sets and returns the field's label. If unset, it will be generated
from the name of the field.

=head2 tag($type)

Returns an XHTML form input tag (see above). By default it renders the
tag based on the type set from the top-level field method:

    $form->field(name => 'poetry', type => 'textarea');

However, if you are doing custom rendering you can override this temporarily
by passing in the type explicitly. This is usually not useful unless you
have a custom rendering module that forcibly overrides types for certain
fields.

=head2 type($type)

This sets and returns the field's type. If unset, it will automatically 
generate the appropriate field type, depending on the number of options and
whether multiple values are allowed:

    Field options?
        No = text (done)
        Yes:
            Less than 'selectnum' setting?
                No = select (done)
                Yes:
                    Is the 'multiple' option set?
                    Yes = checkbox (done)
                    No:
                        Have just one single option?
                            Yes = checkbox (done)
                            No = radio (done)

For an example, view the inside guts of this module.

=head2 validate($pattern)

This returns 1 if the field passes the validation pattern(s) and C<required>
status previously set via required() and (possibly) the top-level new()
call in FormBuilder. Usually running per-field validate() calls is not
what you want. Instead, you want to run the one on C<$form>, which in
turn calls each individual field's and saves some temp state.

=head2 invalid

This returns the opposite value that C<validate()> would return, with
some extra magic that keeps state for form rendering purposes.

=head2 value($val)

This sets the field's value. It also returns the appropriate value: CGI if
set, otherwise the manual default value. Same as using C<field()> to
retrieve values.

=head2 tag_value()

This obeys the C<sticky> flag to give a different interpretation of CGI
values. B<Use this to get the value if generating your own tag.> Otherwise,
ignore it completely.

=head2 cgi_value()

This always returns the CGI value, regardless of C<sticky>.

=head2 def_value()

This always returns the default value, regardless of C<sticky>.

=head2 accessors

In addition to the above methods, accessors are provided for directly 
manipulating values as if from a C<field()> call:

    Accessor                Same as...                        
    ----------------------- -----------------------------------
    $f->force(0|1)          $form->field(force => 0|1)
    $f->options(\@opt)      $form->field(options => \@opt)
    $f->multiple(0|1)       $form->field(multiple => 0|1)
    $f->message($mesg)      $form->field(message => $mesg)
    $f->jsmessage($mesg)    $form->field(jsmessage => $mesg)
    $f->jsclick($code)      $form->field(jsclick => $code)
    $f->sticky(0|1)         $form->field(sticky => 0|1);
    $f->force(0|1)          $form->field(force => 0|1);
    $f->growable(0|1)       $form->field(growable => 0|1);
    $f->other(0|1)          $form->field(other => 0|1);

=head1 SEE ALSO

L<CGI::FormBuilder>

=head1 REVISION

$Id: Field.pm,v 1.39 2005/04/15 18:33:11 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
