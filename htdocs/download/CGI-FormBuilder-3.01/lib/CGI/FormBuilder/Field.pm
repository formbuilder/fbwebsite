
package CGI::FormBuilder::Field;

=head1 NAME

CGI::FormBuilder::Field - internally used to create a FormBuilder field

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

$VERSION = '3.01';

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
    puke "Not enough arguments for Field->new()" unless @_ >= 2;
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

sub cgi_value {
    my $self = shift;
    puke "Cannot set the CGI value manually" if @_;
    debug 2, "called \$field->cgi_value";
    if (my @v = $self->{_form}{params}->param($self->name)) {
        local $" = ',';
        debug 2, "$self->{name}: cgi value = (@v)";
        return wantarray ? @v : $v[0];
    }
    return;
}

sub def_value {
    my $self = shift;
    debug 2, "called \$field->def_value";
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
    debug 2, "called \$field->value";
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
    debug 2, "called \$field->tag_value";
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
    debug 2, "called \$field->type";

    # catch for old way of saying type => 'static'
    if ($self->{type} eq 'static') {
        $self->{static} = 1;
        delete $self->{type};   # still auto-generate a type
    }

    # manually set
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
        } elsif ($self->{_form}->smartness >= 2) {
            debug 2, "$name: smartness >= 2, auto-inferring type based on value";
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
    return $self->{label} if $self->{label};    # manually set
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
            next if $k eq 'validate';   # don't invoke validate
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
    return $self->{message} if $self->{message};    # manually set
    my $type = shift || $self->type;
    my $et = 'form_invalid_' . ($type eq 'text' ? 'input' : $type);
    return $self->{_form}{messages}->$et || $self->{_form}{messages}->form_invalid_default;
}

sub jsmessage {
    my $self = shift;
    $self->{jsmessage} = shift if @_;
    return $self->{jsmessage} if $self->{jsmessage};
    my $type = shift || $self->type;
    my $et = 'js_invalid_' . ($type eq 'text' ? 'input' : $type);
    return $self->{_form}{messages}->$et || $self->{_form}{messages}->js_invalid_default;
}

sub jstype {
    my $self = shift;
    my $type = shift || $self->type;
    return ($type eq 'radio' || $type eq 'checkbox') ? 'onClick' : 'onChange';
}

sub script {
    my $self = shift;
    my $name = $self->name;
    my $pattern = $self->{validate};
    return '' unless $self->{_form}->javascript && ($pattern || $self->required);

    debug 1, "$name: generating JavaScript validation code";
    my $jsfunc  = '';
    my $helptag = '';

    # Special catch, since many would assume this would work
    if (ref $pattern eq 'Regexp') {
        puke "To use a regex in a 'validate' option you must specify ".
             "it in single quotes, like '/^\\w+\$/' - failed on '$name' field";
    }

    # Check our hash to see if it's a special pattern
    ($pattern, $helptag) = autodata $VALIDATE{$pattern} if $VALIDATE{$pattern};

    # Holders for different parts of JS code
    my $close_brace = '';
    my $idt = 0;
    my $is_select = 0;
    my $in = indent($idt);

    # make field name JS-safe
    (my $jsfield = $name) =~ s/\W+/_/g;

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
    my $alertstr = sprintf $self->jsmessage, $self->label;
    $alertstr =~ s/'/\\'/g;     # handle embedded '
    $alertstr .= '\n';

    debug 2, "$name: type is '$type', generating JavaScript";
    if ($type eq 'select') {

        # Get value for field from select list
        # Always assume it is a multiple to guarantee we get all values
        $jsfunc .= <<EOF;
$in    // select list: always assume it's multiple to get all values
$in    var selected_$jsfield = 0;
$in    for (var loop = 0; loop < form.elements['$name'].options.length; loop++) {
$in        if (form.elements['$name'].options[loop].selected) {
$in            var $jsfield = form.elements['$name'].options[loop].value;
$in            selected_$jsfield++;
EOF
        $close_brace = <<EOF;

$in        }
$in    } // close for loop;
$in    if (! selected_$jsfield) {
$in        alertstr += '$alertstr';
$in        invalid++;
$in    }
EOF
        $in = indent($idt += 2);
        $is_select++;

    } elsif ($type eq 'radio' || $type eq 'checkbox') {

        # Get field from radio buttons or checkboxes
        # Must cycle through all again to see which is checked. yeesh.
        # However, this only works if there are MULTIPLE checkboxes!
        # The fucking JS DOM *changes* based on one or multiple boxes!?!?!
        # Damn damn damn I have the JavaScript DOM so damn much!!!!!!
        $jsfunc .= <<EOF;
$in    // radio group or checkboxes
$in    var $jsfield = '';
$in    if (form.elements['$name'][0]) {
$in        for (var loop = 0; loop < form.elements['$name'].length; loop++) {
$in            if (form.elements['$name']\[loop].checked) {
$in                $jsfield = form.elements['$name']\[loop].value;
$in            }
$in        }
$in    } else {
$in        if (form.elements['$name'].checked) {
$in            $jsfield = form.elements['$name'].value;
$in        }
$in    }
EOF
    } else {

        # get value from text or other straight input
        # at least this part makes some sense
        $jsfunc .= <<EOF;
$in    // standard text, hidden, password, or textarea box
$in    var $jsfield = form.elements['$name'].value;
EOF
    }

    # Our fields are only required if the required option is set
    # So, if not set, add a not-null check to the if below
    my $nn = $self->required ? ''
           : qq{($jsfield || $jsfield === 0) &&\n$in       };

    # hashref is a grouping per-language
    if (ref $pattern eq 'HASH') {
        $pattern = $pattern->{javascript} || return;
    }

    if ($pattern =~ m#^m?(\S)(.*)\1$#) {
        # JavaScript regexp
        ($pattern = $2) =~ s/\\\//\//g;
        $pattern =~ s/\//\\\//g;
        $jsfunc .= qq($in    if ($nn (! $jsfield.match(/$pattern/)) ) {\n);
    } elsif (ref $pattern eq 'ARRAY') {
        # must be w/i this set of values
        # can you figure out how this piece of Perl works? ha ha ha ha ....
        $jsfunc .= "$in    if ($nn ($jsfield != '"
                 . join("' && $jsfield != '", @{$pattern}) . "') ) {\n";
    } elsif ($pattern eq 'VALUE' || ($self->required && (! $pattern || ref $pattern eq 'CODE'))) {
        # Not null (for required sub refs, just check for a value)
        $jsfunc .= qq($in    if ($nn ((! $jsfield && $jsfield != 0) || $jsfield === "")) {\n);
    } else {
        # literal string is a literal comparison, but provide
        # a warning just in case
        belch "Validation string '$pattern' may be a typo of a builtin pattern"
            if $pattern =~ /^[A-Z]+$/;
        $jsfunc .= qq($in    if ($nn ! ($jsfield $pattern)) {\n);
    }

    # add on our alert message, which is unfortunately always generic
    $jsfunc .= <<EOF;
$in        alertstr += '$alertstr';
$in        invalid++;
$in    }$close_brace
EOF

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

    # Setup class for stylesheets
    $attr{class} ||= $self->{_form}{styleclass} . $type if $self->{_form}{stylesheet};

    my $tag   = '';
    my @value = $self->tag_value;   # sticky is different in <tag>

    if ($type eq 'select') {
        # First the top-level select
        delete $attr{type};     # type="select" invalid
        $attr{multiple} = $self->multiple if $self->multiple;
        $tag .= htmltag($type, %attr);

        # Now all our options
        my @opt = $self->options;
        debug 2, "my (" . @opt . ") = \$field->options";
        unshift @opt, ['', $self->{_form}->{messages}->form_select_default]
                if $self->{_form}->smartness && ! $attr{multiple};  # set above
        
        for my $opt (@opt) {
            # Since our data structure is a series of ['',''] things,
            # we get the name from that. If not, then it's a list
            # of regular old data that we toname() if nameopts => 1
            my($o,$n) = optval($opt);
            $n ||= $attr{labels}{$o} || ($self->nameopts ? toname($o) : $o);
            my %slct = ismember($o, @value) ? (selected => 'selected') : ();
            $slct{value} = $o;
            $tag .= htmltag('option', %slct) . escapehtml($n) . '</option>';
        }
        $tag .= '</select>';
    }
    elsif ($type eq 'radio' || $type eq 'checkbox') {
        my $checkbox_table = 0;  # toggle
        my $checkbox_col = 0;
        if ($self->columns > 0) {
            $checkbox_table = 1;
            $tag .= htmltag('table', { $self->{_form}->table, border => 0 });
        }

        # Get our options
        my @opt = $self->options;
        debug 2, "my @opt = \$field->options";

        for my $opt (@opt) {
            #  Divide up checkboxes in a user-controlled manner
            if ($checkbox_table) {
                $tag .= "<tr>\n" if $checkbox_col % $self->columns == 0;
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
            $attr{id} = "$attr{name}_$o";

            $tag .= htmltag('input', %attr, @slct) . ' ' . 
                       htmltag('label', for => $attr{id}) . escapehtml($n) . '</label> ';
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
        for my $value (@value) {
            # setup the value
            $attr{value} = $value;      # override
            delete $attr{value} unless defined $value;

            # render the tag
            $tag .= htmltag('input', %attr);

            # print the value out too when in a static context, EXCEPT for
            # manually hidden fields (those that the user hid themselves)
            my $tagcom = escapehtml($value);
            $tag .= $tagcom . ' ' if $self->static && $tagcom && $usertype ne 'hidden';
            debug 2, "if ", $self->static, " && $tagcom && $usertype ne 'hidden';";
            $tag .= '<br />' if $self->linebreaks;
        }

        # special catch to make life easier (too action-at-a-distance?)
        # if there's a 'file' field, set the form enctype if they forgot
        if ($type eq 'file' && $self->{_form}->smartness) {
            $self->{_form}{enctype} ||= 'multipart/form-data';
            debug 2, "verified enctype => 'multipart/form-data' for 'file' field";
        }
    }
    debug 2, "generation done, got tag = $tag";
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

    debug 1, "called \$field->validate(@_) for field '$field'";

    # Fail or success?
    my $bad = 0;

    # only continue if field is required or filled in
    if ($self->required) {
        debug 1, "$field: is required per 'required' param";
    } else {
        debug 1, "$field: is optional per 'required' param";
        return 1 unless length $self->field($field) && defined $pattern;
        debug 1, "$field: ...but is defined, so still checking";
    }

    # loop thru, and if something isn't valid, we tag it
    my $atleastone = 0;
    $self->{invalid} ||= 0;
    for my $value ($self->value) {
        my $thisfail = 0;
        $atleastone++;

        # Check our hash to see if it's a special pattern
        ($pattern) = autodata($VALIDATE{$pattern}) if $VALIDATE{$pattern};

        # hashref is a grouping per-language
        if (ref $pattern eq 'HASH') {
            $pattern = $pattern->{perl} || next;
        }

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
        $self->{invalid} = $thisfail;
    }

    # If not $atleastone and they asked for validation, then we
    # know that we have an error since this means no values
    if ($bad || ! $atleastone) {
        debug 1, "$field: validation FAILED";
        return;
    } else {
        debug 1, "$field: validation passed";
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

# End of Perl code
1;

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

=head1 SEE ALSO

L<CGI::FormBuilder>

=head1 REVISION

$Id: Field.pm,v 1.22 2005/02/10 20:15:52 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2000-2005 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
