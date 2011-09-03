
# Copyright (c) 2001-2004 Nathan Wiger <nate@sun.com>
# Please visit www.formbuilder.org for support and examples
# Use "perldoc FormBuilder.pod" for documentation

package CGI::FormBuilder;

use Carp;
use strict;
use vars qw($VERSION $CGIMOD $CGI $AUTOLOAD);
$VERSION = do { my @r=(q$Revision: 2.13 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };

# We used to try to use CGI::Minimal for better speed, but
# unfortunately its support for file uploads it unsuitable
# for continued use. Sorry.

use CGI;
$CGIMOD = 'CGI';
$CGI::USE_PARAM_SEMICOLONS = 0;   # use "&" not ";"

# For debug(), the value is set in new()
my $DEBUG;

# Catches for special validation patterns
# These are semi-Perl patterns; they must be usable by JavaScript
# as well so they do not take advantage of features JS can't use
# If the value is an arrayref, then the second arg is a tag to
# spit out at the person after the field label to help with format

my %VALID = (
    WORD  => '/^\w+$/',
    NAME  => '/^[a-zA-Z]+$/',
    NUM   => '/^-?\s*[0-9]+\.?[0-9]*$|^-?\s*\.[0-9]+$/',    # 1, 1.25, .25
    INT   => '/^-?\s*[0-9]+$/',
    FLOAT => '/^-?\s*[0-9]+\.[0-9]+$/',
    PHONE => ['/^\d{3}\-\d{3}\-\d{4}$|^\(\d{3}\)\s+\d{3}\-\d{4}$/', '123-456-7890'],
    INTPHONE => ['/^\+\d+[\s\-][\d\-\s]+$/', '+prefix local-number'],
    ALLPHONE => ['/^(\d{3}[\-\.]?\s*|\(\d{3}\)\s*)\d{3}[\-\.]?\s*\d{4}$/', '(123) 456-7890'],
    EMAIL => ['/^[\w\-\+\._]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/', 'name@host.domain'],
    CARD  => '/^\d{4}[\- ]?\d{4}[\- ]?\d{4}[\- ]?\d{4}$|^\d{4}[\- ]?\d{6}[\- ]?\d{5}$/',
    MMYY  => ['/^(0?[1-9]|1[0-2])\/?[0-9]{2}$/', 'MM/YY'],
    MMYYYY=> ['/^(0?[1-9]|1[0-2])\/?[0-9]{4}$/', 'MM/YYYY'],
    DATE  => ['/^(0?[1-9]|1[0-2])\/?(0?[1-9]|[1-2][0-9]|3[0-1])\/?[0-9]{4}$/', 'MM/DD/YYYY'],
    TIME  => ['/^[0-9]{1,2}:[0-9]{2}$/', 'HH:MM (24-hour)' ],
    AMPM  => ['/^[0-9]{1,2}:[0-9]{2}\s*([aA]|[pP])[mM]$/', 'HH:MM AM/PM' ],
    ZIPCODE=> '/^\d{5}$|^\d{5}\-\d{4}$/',
    STATE => ['/^[a-zA-Z]{2}$/', 'two-letter abbr'],
    COUNTRY => ['/^[a-zA-Z]{2}$/', 'two-letter abbr'],
    IPV4  => ['/^([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])$/', 'IP address'],
    NETMASK => ['/^([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])\.([0-1]??\d{1,2}|2[0-4]\d|25[0-5])$/', 'IP netmask'],
    FILE  => ['/(^[\w\+_\040\#\(\)\{\}\[\]\/\-\^,\.:;&%@\\~]+\$?$)/ ', 'UNIX format'],
    WINFILE => ['/^(([a-zA-Z]:)?\\?[\w\+_\040\(\)\{\}\[\]\/\-\^,\.;&%@\$!\\~\#]+)$/', 'Windows format'],
    MACFILE => ['/^[:\w\.\-_]+$/', 'Mac format'],
    USER  => ['/^[-a-zA-Z0-9_]{4,8}$/', '4-8 characters'],  # require a 4-8 char username
    HOST  => ['/^[a-zA-Z0-9][-a-zA-Z0-9]*$/', 'valid hostname'],
    DOMAIN=> ['/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/', 'DNS domain'],   # mostly correct, but allows "dom.c-o.uk"
    ETHER => ['/^[\dA-Fa-f]{1,2}[.:][\dA-Fa-f]{1,2}[.:][\dA-Fa-f]{1,2}[.:][\dA-Fa-f]{1,2}[.:][\dA-Fa-f]{1,2}[.:][\dA-Fa-f]{1,2}$|^[\dA-Fa-f]{12}$/', 'ethernet' ],
    # Many thanks to Mark Belanger for these additions
    FNAME => '/^[a-zA-Z]+[- ]?[a-zA-Z]*$/',
    LNAME => '/^[a-zA-Z]+[- ]?[a-zA-Z]+\s*,?([a-zA-Z]+|[a-zA-Z]+\.)?$/',
    CCMM  => '/^0[1-9]|1[012]$/',
    CCYY  => '/^[1-9]{2}$/', 
);

# To clean up the HTML, instead of just allowing the HTML tags that
# we interpret are "valid", instead we yank out all the options and
# stuff that we use internally. This allows arbitrary tags to be
# specified in the generation of HTML tags, and also means that this
# module doesn't go out of date when the HTML spec changes next week.
my @OURATTR = qw(
    attr body checknum comment debug delete fieldattr fields fieldtype font
    force header invalid javascript keepextras label labels lalign
    linebreaks nameopts options override params radionum required
    reset selectnum smartness sortopts static sticky submit table
    template title type_orig validate valign value_orig values messages 
    columns ulist
);

# trick for speedy lookup
my %OURATTR = map { $_ => 1 } @OURATTR;

# Default messages, since all can be customized. These are used when
# the person does not specify any special ones (the normal case).
my %MESSAGES = (
    js_invalid_start      => '%s error(s) were encountered with your submission:',
    js_invalid_end        => 'Please correct these fields and try again.',

    js_invalid_input      => '- You must enter a valid value for the "%s" field',
    js_invalid_select     => '- You must choose an option for the "%s" field',
    js_invalid_checkbox   => '- You must choose an option for the "%s" field',
    js_invalid_radio      => '- You must choose an option for the "%s" field',
    js_invalid_password   => '- You must enter a valid value for the "%s" field',
    js_invalid_textarea   => '- You must fill in the "%s" field',
    js_invalid_file       => '- You must specify a valid file for the "%s" field',

    form_required_text    => '<p>Fields shown in <b>bold</b> are required.',
    form_invalid_text     => '<p>%s error(s) were encountered with your submission. '
                           . 'Please correct the fields <font color="%s">'
                           . '<b>highlighted</b></font> below.',
    form_invalid_color    => 'red',

    form_invalid_input    => 'You must enter a valid value',
    form_invalid_select   => 'You must choose an option from this list',
    form_invalid_checkbox => 'You must choose an option from this group',
    form_invalid_radio    => 'You must choose an option from this group',
    form_invalid_password => 'You must enter a valid value',
    form_invalid_textarea => 'You must fill in this field',
    form_invalid_file     => 'You must specify a valid filename',

    form_select_default   => '-select-',
    form_submit_default   => 'Submit',
    form_reset_default    => 'Reset',
    
    form_confirm_text     => 'Success! Your submission has been received %s.',
);

# How about this? Built-in options for commonly used fields. So cool.
my %OPTIONS = (
    STATE => [qw(AL AK AZ AR CA CO CT DE DC FL GE HI ID IL IN IA KS
                 KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC
                 ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY)],
);

# Begin internal functions
sub debug ($;@) {
    return unless $DEBUG >= $_[0];  # first arg is debug level
    shift;  # using $_[0] directly above is just a little faster...
    my($func) = (caller(1))[3];
    warn "[$func] (debug) ", @_, "\n";
}

sub belch (@) {
    my($func) = (caller(1))[3];
    carp "[$func] Warning: ", @_;
}

sub puke (@) {
    my($func) = (caller(1))[3];
    croak "[$func] Fatal: ", @_;
}

sub _args (;@) {
    belch "Odd number of arguments passed into ", (caller(1))[3]
        unless (@_ % 2 == 0);
    # strip off any leading '-opt' crap
    my @args;
    while (@_) {
        (my $k = shift) =~ s/^-//;
        push @args, $k, shift;
    }
    return @args;
}

sub _data ($) {
    # auto-derefs appropriately
    my $data = shift;
    if (my $ref = ref $data) {
        if ($ref eq 'ARRAY') {
            return wantarray ? @{$data} : $data;
        } elsif ($ref eq 'HASH') {
            return wantarray ? %{$data} : $data;
        } else {
            puke "Sorry, can't handle odd data ref '$ref'";
        }
    } else {
        return $data;   # return as-is
    }
}

sub _ismember ($@) {
    # returns 1 if is in set, undef otherwise
    # do so case-insensitively
    my $test = lc shift;
    for (@_) {
        return 1 if $test eq lc $_;
    }
    return;
}
 
sub _indent (;$) {
    # return proper spaces to indent x 4
    return "    " x shift();
}

sub _toname ($) {
    # creates a name from a var/file name (like file2name)
    my $name = shift;
    $name =~ s!\.\w+$!!;        # lose trailing ".cgi" or whatever
    $name =~ s![^a-zA-Z0-9.-/]+! !g;
    $name =~ s!\b(\w)!\u$1!g;
    return $name;
}

sub _opt ($) {
    # This creates and returns the options needed based
    # on an $opt array/hash shifted in
    my $opt = shift;

    # "options" are the options for our select list
    my @opt = ();
    if (my $ref = ref $opt) {
        # we turn any data into ( ['key', 'val'], ['key', 'val'] )
        # have to check sub-data too, hence why this gets a little nasty
        @opt = ($ref eq 'HASH')
                  ? map { [$_, $opt->{$_}] } keys %{$opt}
                  : map { (ref $_ eq 'HASH')  ? [each %{$_}] : $_ } _data $opt;
    } else {
        # this code should not be reached, but is here for safety
        @opt = ($opt);
    }

    return @opt;
}

sub _sort (\@$) {
    # pass in the sort and ref to opts
    my @opt  = @{ shift() };        # must deref to reorg
    my $sort = shift;

    debug 1, "_sort($sort, @opt) called for field";

    # Currently we can only sort on the value, which sucks if the value
    # and label are substantially different. This is caused by the fact
    # that options as specified by the user only have one element, not two
    # as hashes or generated options do. This should really be an option,
    # since sometimes you want the values sorted too. Patches welcome.
    if ($sort eq 'alpha' || $sort eq 'name' || $sort eq 'NAME' || $sort eq '1') {
        @opt = sort { (_data($a))[0] cmp (_data($b))[0] } @opt;
    } elsif ($sort eq 'numeric' || $sort eq 'num' || $sort eq 'NUM') {
        @opt = sort { (_data($a))[0] <=> (_data($b))[0] } @opt;
    } else {
        puke "Unsupported sort type '$sort' specified - must be 'NAME' or 'NUM'";
    }

    # return our options
    return @opt;
}

sub _initfields () {
    my $self = shift;
    local $^W = 0;      # -w sucks

    # Resolve the fields and values, called by new() as:
    #
    #    $self->_initfields(fields => [array ref], values => {hash or obj ref});
    #
    # OR
    #
    #    $self->_initfields(fields => {hash ref of key/val pairs});
    #
    # The values are *always* taken to be the assigned values of
    # the thingy. If you need to assign other options, you need
    # to do so via the field() method.

    my %args = _args(@_);
    my %val  = ();
    my @val  = ();

    # Safety catch
    $self->{fields} ||= {};
    $self->{field_names} ||= [];

    debug 1, "called _initfields(@_)";

    # check to see if 'fields' is a hash or array ref
    if (ref $args{fields} eq 'HASH') {
        # with a hash ref, we setup keys/values
        $self->{field_names} = [ sort keys %{$args{fields}} ];
        while(my($k,$v) = each %{$args{fields}}) {
            $k = lc $k;     # must lc to ignore case
            $val{$k} = [_data $v]; 
        }
        # now we lie about what $args{fields} contained so 
        # that the below data struct assembly works
        $args{fields} = $self->{field_names};
    } elsif ($args{fields}) {
        # setup our ordering
        $self->{field_names} = [ _data $args{fields} ];
    } else {
        # not resetting our fields; we're just setting up values
        $args{fields} = $self->{field_names} || [keys %{$args{values} || {}}];
    }

    # We currently make two passes, first getting the values
    # and storing them into a temp hash, and then going thru
    # the fields and picking up the values.

    if ($args{values}) {
        debug 1, "args{values} = $args{values}";
        if (UNIVERSAL::can($args{values}, 'param')) {
            # it's a blessed CGI ref or equivalent, so use its param() method
            for my $key ($args{values}->param) {
                # always assume an arrayref of values...
                $val{$key} = [ $args{values}->param($key) ];
                debug 2, "setting values from param(): $key => @{$val{$key}}";
            }
        } elsif (ref $args{values} eq 'HASH') {
            # must lc all the keys since we're case-insensitive, then
            # we turn our values hashref into an arrayref on the fly
            my @v = _data($args{values});
            while (@v) {
                my $key = lc shift @v;
                $val{$key} = [_data shift @v];
                debug 2, "setting values from HASH: $key => @{$val{$key}}";
            }
        } elsif (ref $args{values} eq 'ARRAY') {
            # also accept an arrayref which is walked sequentially below
            @val = _data $args{values};
        } else {
            puke "Unsupported operand to 'values' attribute - must be hashref or object";
        }
    }

    # Now setup our data structure. Hmm, is this the right way to
    # do this? I mean, philosophically speaking...
    for my $k (_data($args{fields})) {
        debug 1, "initializing field '$k'";
        # We no longer "pre-catch" CGI. Instead, we allow stickiness
        # meaning that CGI values override our default values from above
        my @v = ();
        @v = $CGI->param($k) if $CGI;   # get it from CGI if object exists

        # There is a stupid fucking Netscrape bug that occurs if you have a
        # hidden field w/o explicit value= attr. This catches that. If it
        # causes you problems, set smartness => 0 to override this trick.
        if ($self->{opt}{smartness} && "@v" eq '  ') {
            debug 1, "CGI browser bug caught, ignoring $k values";
            undef @v;
        }

        if (@v) {
            if (length "@v" > 0) {
                # if any values are found, add to the tag
                debug 1, "CGI yielded $k = '" . join(', ', @v) . "'";
                $self->{fields}{$k}{value} = \@v;
                $self->{field_cgivals}{$k} = 1;
            } else {
                # field was defined, but set to "", so clear out
                debug 1, "CGI cleared out $k";
                $self->{fields}{$k}{value} = [];
                $self->{field_cgivals}{$k} = [];
            }
        } elsif (! $self->{field_inited}{$k}) {
            # we do not set the value here if it's already been 
            # manually initialized, say through a field() call
            if (keys %val) {
                # 'values' hashref arg
                debug 1, "CGI has no value, using values hashref = ", $val{lc($k)};
                $self->{fields}{$k}{value} = $val{lc($k)};
            } elsif (@val) {
                # now accept an arrayref to 'values' as well; walk sequentially
                debug 1, "CGI has no value, shifting values array = ", $val{lc($k)};
                $self->{fields}{$k}{value} = [_data shift @val];
            } else {
                debug 1, "CGI has no value, no defaults found, so clearing";
                $self->{fields}{$k}{value} = [];
            }
    
            # first time around, save "original" value; this is used
            # later to resolve conflicts between sticky => 0 and values => $ref 
            $self->{fields}{$k}{value_orig} = $self->{fields}{$k}{value};
        }
        # Check for any options specified
        if (my $o = delete $self->{opt}{options}{$k}) {
            $self->{fields}{$k}{options} = $o;
        }

        debug 1, "set value $k = '" . join(', ', @{$self->{fields}{$k}{value}}) . "'"
                    if $self->{fields}{$k}{value};

    }

    # Finally, if the user asked for "realsmart", then we try to automatically
    # figure out some validation stuff (among other things)...
    if ($self->{opt}{smartness} >= 2) {
        for my $field (@{$self->{field_names}}) {
            next if $self->{opt}{validate}{$field};
            if ($field =~ /email/i) {
                $self->{opt}{validate}{$field} ||= 'EMAIL'; 
            } elsif ($field =~ /phone/i) {
                $self->{opt}{validate}{$field} ||= 'PHONE';
            } elsif ($field =~ /date/i) {
                $self->{opt}{validate}{$field} ||= 'DATE';
            } elsif ($field =~ /credit.*card/i) {
                $self->{opt}{validate}{$field} ||= 'CARD';
            } elsif ($field =~ /^zip(?:code)?$/i) {
                $self->{opt}{validate}{$field} ||= 'ZIPCODE';
            } elsif ($field =~ /^state$/i) {
                $self->{opt}{validate}{$field} ||= 'STATE';
                # the options are the names of the US states + DC (51)
                $self->{fields}{$field}{options} ||= $OPTIONS{STATE};
                debug 2, "via 'smartness' auto-determined options for '$field' field";
            } elsif ($field =~ /^countr/i) {    # "country" or "countries"
                $self->{opt}{validate}{$field} ||= 'COUNTRY';
                # the options are the currently-valid country codes, US first, of course :-)
                $self->{fields}{$field}{options} ||= $OPTIONS{COUNTRY};
                debug 2, "via 'smartness' auto-determined options for '$field' field";
            } elsif ($field =~ /^file/i) {
                # guess based on the browser the user is running!
                if ($ENV{HTTP_USER_AGENT} =~ /\bwin|\bdos/i) {
                    $self->{opt}{validate}{$field} ||= 'WINFILE';
                } elsif ($ENV{HTTP_USER_AGENT} =~ /\bmac/i) {
                    $self->{opt}{validate}{$field} ||= 'MACFILE';
                } else {
                    # UNIX by default, hehe :-)
                    $self->{opt}{validate}{$field} ||= 'FILE';
                }
            } elsif ($field =~ /^domain/i) {
                $self->{opt}{validate}{$field} ||= 'DOMAIN';
            } elsif ($field =~ /^host|host$/i) {
                $self->{opt}{validate}{$field} ||= 'HOST';
            } elsif ($field =~ /^user|user$/i) {
                $self->{opt}{validate}{$field} ||= 'USER';
            } elsif ($field =~ /^name/i) {
                $self->{opt}{validate}{$field} ||= 'NAME';
            } else {
                next;   # skip below message
            }
            debug 2, "via 'smartness' set validation for '$field' field ",
                     "to '$self->{opt}{validate}{$field}'";
        }
    }

    return 1;
}

sub _escapeurl ($) {
    # minimalist, not 100% correct, URL escaping
    my $toencode = shift;
    $toencode =~ s!([^a-zA-Z0-9_,.-/])!sprintf("%%%02x",ord($1))!eg;
    return $toencode;
}

sub _escapehtml ($) {
    my $toencode = shift;
    # must do these in order or the browser won't decode right
    $toencode =~ s!&!&amp;!g;
    $toencode =~ s!<!&lt;!g;
    $toencode =~ s!>!&gt;!g;
    $toencode =~ s!"!&quot;!g;
    return $toencode;
}

sub _tag ($;@) {
    # called as _tag('tagname', %attr)
    # creates an HTML tag on the fly, quick and dirty
    my $name = shift || return;
    my @tag;
    while (@_) {
        # this cleans out all the internal junk kept in each data
        # element, returning everything else (for an html tag)
        my $key = shift;
        # Eeek, I used "text" here and body takes a text attr!!
        if ($OURATTR{$key} || ($key eq 'text' && $name ne 'body')
                           || ($key eq 'multiple' && $name ne 'select')) {
            shift; next;
        }
        my $val = _escapehtml shift;    # minimalist HTML escaping
        push @tag, qq($key="$val");
    }
    my $htag = join(' ', $name, sort @tag);
    $htag .= ' /' if $name eq 'input';  # XHTML self-closing
    return '<' . $htag . '>';
}

sub _expreqd ($$) {
    # As of v1.97, our 'required' option semantics have become much more
    # complicated. We now have to create an intersection between required
    # and validate. To do so, we make it so that required has a list of
    # the required fields, which is then used by validate.
    my %need = ();
    my $self = shift;
    my $reqd = shift;
    my $vald = shift || {};
    if ($reqd) {
        if ($reqd eq 'ALL') {
            debug 1, "fields deemed as required: ALL";
            $reqd = $self->{field_names};     # point to field_names
        } elsif ($reqd eq 'NONE') {
            debug 1, "fields deemed as required: NONE";
            $reqd = [];
        }
        unless (ref $reqd eq 'ARRAY') {
            puke("Argument to 'required' option must be an arrayref, 'ALL', or 'NONE'");
        }
        # create a hash for easy lookup
        debug 1, "fields deemed as required: @$reqd";
        $need{$_} = 1 for @{$reqd};
    } else {
        $need{$_} = 1 for keys %{$vald};
    }
    return wantarray ? %need : \%need;
}

sub new () {
    my $class = shift;
    local $^W = 0;      # -w sucks

    # handle ->new($method) and ->new(method => $method)
    my $method = shift unless (@_ % 2 == 0);
    my %args = _args(@_);
    $args{method} ||= $method if $method;

    # Warning to try and catch user error
    #belch "You won't be able to get at any form values unless you specify 'fields' to new()"
        #unless $args{fields};

    $DEBUG = delete $args{debug} || 0;   # recall that delete returns the val deleted

    # Redo our magical CGI object if specified
    # This is the *only* option that must be specified in new and not render
    if (my $r = delete $args{params}) {
        # in mod_perl, we can't do anything without a manual params => arg
        # since otherwise POST params magically disappear
        puke "Argument to 'params' option must be an object with a param() method"
            unless UNIVERSAL::can($r, 'param');
        $CGI = $r;
    } else {
        # initialize our CGI object
        $CGI = $CGIMOD->new;
    }

    # New for 2.07, add in customized messages support
    if ($args{messages}) {
        if (my $ref = ref $args{messages}) {
            # hashref, get values directly
            croak "Argument to 'messages' option must be a filename or hashref"
                unless $ref eq 'HASH';
            while(my($k,$v) = each %MESSAGES) {
                $args{messages}{$k} = $v unless exists $args{messages}{$k};
            }
        } else {
            # filename, just *warn* on missing, and use defaults
            if (-f $args{messages} && -r _ && open(M, "<$args{messages}")) {
                $args{messages} = \%MESSAGES;
                while(<M>) {
                    next if /^\s*#/ || /^\s*$/;
                    chomp;
                    my($k,$v) = split ' ', $_, 2;
                    $args{messages}{$k} = $v;
                }
                close M;
            } else {
                belch "Could not read messages file $args{messages}: $!";
                $args{messages} = \%MESSAGES;
            }
        }
    } else {
        $args{messages} = \%MESSAGES;
    }

    # These options default to 1
    for my $def2one (qw/sticky labels smartness/) {
        $args{$def2one} = 1 unless exists $args{$def2one};
    }

    # Now bless all our options into ourself
    my $self = bless {}, ref($class) || $class;
    $self->{opt} = \%args;

    # Process any fields specified, if applicable
    if (my $fields = delete $self->{opt}{fields}) {
        $self->_initfields(fields => $fields,
                           values => delete $self->{opt}{values});
    } elsif (my $values = delete $self->{opt}{values}) {
        $self->_initfields(values => $values);
    }

    return $self;
}

*fields = \&field;
sub field () {
    my $self = shift;
    local $^W = 0;      # -w sucks
    debug 2, "called \$form->field(@_)";

    # handle either ->field($name) or ->field(name => $name)
    my $name = (@_ % 2 == 0) ? '' : shift();
    my %args = _args(@_);
    $args{name} ||= $name;

    # must catch this here each time
    $self->{fields} ||= {};
    $self->{field_names} ||= [];

    # no name - return ala $cgi->param
    unless ($args{name}) {
        # return an array of the names in list context, and a
        # hashref of name/value pairs in a scalar context
        if (wantarray) {
            return @{$self->{field_names}};
        } else {
            # Unfortunately, this only returns a single value for each field
            my %ret = map { $_ => scalar $self->field($_) } @{$self->{field_names}};
            return \%ret;
        }
    }

    # push onto our order only if we don't have yet... also init
    # the field value from CGI if it exists...
    if (! defined $self->{fields}{"$args{name}"} && keys(%args) > 1) {
        if ($CGI && length $CGI->param($args{name})) {
            debug 1, "sticky $args{name} from CGI = " . $CGI->param($args{name});
            $self->{fields}{"$args{name}"}{value} = [ $CGI->param($args{name}) ];
            $self->{field_cgivals}{"$args{name}"} = 1;
        }
        push @{$self->{field_names}}, $args{name};
    }

    # we use this to mess around with a single field
    while(my($k,$v) = each %args) {
        next if $k eq 'name';
        # special catch for value
        debug 2, "walking field() args: $k => $v";
        if ($k eq 'value') {
            # don't set value if CGI already has!
            if ($self->{field_cgivals}{"$args{name}"}) {
                next unless $args{force} || $args{override};
                # force CGI value, including thru param, this only matters for multi-forms
            }
            debug 1, "manually forcing field $args{name} value => $v";
            $self->{field_inited}{"$args{name}"} = 1;
            $v = [_data $v];

            # save any manually initied values here
            # the actual {value} element is set at the bottom of the while()
            #$CGI->param(-name => $args{name}, -value => $v, -override => 1);
            $self->{fields}{"$args{name}"}{value_orig} = $v;
        } elsif ($k eq 'delete') {
            # wipe field value out entirely
            my @fn = ();
            for (@{$self->{field_names}}) {
                push @fn, $_ unless $_ eq $args{name};
            }
            $self->{field_names} = \@fn;
            delete $self->{field_inited}{"$args{name}"};
            delete $self->{field_cgivals}{"$args{name}"};
            delete $self->{fields}{"$args{name}"};
            $CGI->delete($args{name});
            return;
        } elsif ($k eq 'validate') {
            # per-field validation; can clear with validate => undef
            $self->{opt}{$k}{"$args{name}"} = $v;
        } elsif ($k eq 'required') {
            # per-field validation; can clear with validate => undef
            if (exists $self->{opt}{$k}) {
                if (ref $self->{opt}{$k}) {
                    push @{$self->{opt}{$k}}, $args{name};
                } elsif ($self->{opt}{$k}) {
                    belch "Cannot override required option in field() if set to 'ALL' or 'NONE'";
                }
            } elsif ($v) {
                push @{$self->{opt}{$k}}, $args{name};
            } else {
                belch "Setting required => 0 in field() does not currently work right";
            }
        }
        $self->{fields}{"$args{name}"}{$k} = $v;
        #debug 2, "\$self->{fields}{$args{name}}{$k} = $v";
    }

    # return the value
    my @v = _data($self->{fields}{"$args{name}"}{value});
    debug 1, "return field($args{name}) = (", join(', ', @v), ") [len = ", scalar(@v), "]";
    return wantarray ? @v : $v[0];
}

*output = \&render;  # unpublished, but works
sub render () {
    my $self = shift;
    local $^W = 0;      # -w sucks

    # We create our hash based on the variables set from our
    # global options, followed by those from our local sub call
    my %args = ( %{$self->{opt}}, _args(@_) );

    # Thanks to Randy Kobes for this patch fixing $0 on Win32
    my($basename) = ($^O =~ /Win32/i)
                         ? ($0 =~ m!.*\\(.*)\??!)
                         : ($0 =~ m!.*/(.*)\??!);
    $basename ||= $0;
    debug 2, "derived basename = $basename from $0";

    # We manually set these to the "defaults" because browers suck
    unless ($args{action} ||= $ENV{SCRIPT_NAME}) {
        $args{action} = $basename;
    }
    delete $args{action} unless $args{action};
    $args{method} ||= 'GET';

    puke "You can only specify the 'params' option to ".__PACKAGE__."->new"
        if $args{params};

    # Remove validation if we're static, since that makes no sense
    if ($args{static}) {
        delete $args{required};
        delete $args{validate};
    }

    # Per request of Peter Billam, auto-determine javascript setting
    # based on user agent
    if (! exists $args{javascript} || $args{javascript} eq 'auto') {
        if (exists $ENV{HTTP_USER_AGENT}
                && $ENV{HTTP_USER_AGENT} =~ /lynx|mosaic/i)
        {
            # Turn off for old/non-graphical browsers
            $args{javascript} = 0;    
        } else {
            # Turn on for all other browsers by default.
            # I suspect this process should be reversed, only
            # showing JavaScript on those browsers we know accept
            # it, but maintaining a full list will result in this
            # module going out of date and having to be updated.
            $args{javascript} = 1;
        }
    }

    # Process any fields specified, if applicable
    $self->{opt}{smartness} = $args{smartness};   # XXX kludge
    
    if (my $fields = delete $args{fields}) {
        belch "Specifying 'fields' to render() is deprecated and unsupported";
        $self->_initfields(fields => $fields,
                           values => delete $args{values});
    } elsif (my $values = delete $args{values}) {
        $self->_initfields(values => $values);
    }

    # Defaults for native HTML
    unless($args{title}) {
        # Here we generate the title based on the executable! nifty!
        $args{title} = _toname($basename);
        debug 1, "auto-created title as '$args{title}' from script name ($basename)";
    }
    $args{text}  ||= '';  # shut up "uninit in concat" in heredoc
    $args{body}  ||= { bgcolor => 'white' };

    # Thresholds for radio, checkboxes, and selects (in # of items)
    carp "Warning: 'radionum' option is deprecated and will be ignored"
        if $args{radionum};
    $args{selectnum} = 5 unless defined $args{selectnum};

    my %tmplvar = %{$self->{tmplvar} || {}};  # holds stuff for HTML::Template
    my $outhtml = '';
    my $font = '';
    if ($args{font}) {
        $font = (ref $args{font} eq 'HASH')
                    ? _tag('font', %{$args{font}})
                    : _tag('font', face => $args{font});
    }

    # XXX This is a major fucking hack. the only way that we
    # XXX can reliably keep state is by saving the whole
    # XXX fields part of the object and restoring it later,
    # XXX since this sub currently alters it. Yeeeesh!
    # XXX Yes, this has to be anonymous so it ends up a copy
    my $oldfn = [ @{$self->{field_names} ||= []} ];
    my $oldfv = { %{$self->{fields} ||= {}} };

    # we can also put stuff inside a table if so requested...
    my($to, $tc, $tdl, $tdo, $td2, $tdc, $tro, $trc, $co, $cc) = ('' x 9);
    unless (exists $args{table}) {
        $args{table} = {} if @{$self->{field_names}} > 1;
    }
    if ($args{table}) { 
        # Strictly speaking, these should all use _tag, but this is faster.
        # Currently, table/tr/td attrs are not supported. Should they be?
        # Or should we just tell people to use a fucking template?
        $to  = (ref $args{table} eq 'HASH') ? _tag('table', %{$args{table}}) : '<table>';
        $tc  = '</table>';
        $tdl = '<td align="' . ($args{lalign} || 'left') . '">' . $font;
        $tdo = '<td>' . $font;
        $td2 = '<td colspan="2">' . $font;
        $tdc = '</td>';
        # we cannot use _tag() for <tr>, because @OURATTR filters
        # out valign (otherwise all tags would have it)
        $tro = '<tr valign="' . ($args{valign} || 'middle') . '">';
        $trc = '</tr>';
        $co  = '<center>';
        $cc  = '</center>';
    } else {
        # Forge some of the table markers as spacers instead
        $tdc = ' ';
    }

    # Auto-sense linebreaks if not set
    $args{linebreaks} = 1 if $args{table};

    # How to handle line breaks - include <br> only if not a table
    my $br = $args{linebreaks}
                ? ($args{table} ? "\n" : "<br />\n") : '';

    # For holding the JavaScript validation code
    my $jsfunc = '';
    my $jsname = $args{name} ? "validate_$args{name}" : 'validate';

    # User-specified jsfunc options
    my $ajsf = delete $args{jsfunc} || '';

    if ($args{javascript} && ($args{validate} || $args{required})) {
        $jsfunc  = "function $jsname (form) {\n"
                 . "    var alertstr = '';\n"
                 . "    var invalid  = 0;\n\n";
        $jsfunc .= $ajsf;
    }

    # As of v1.97, now have a sub to handle expansion of 'required'
    # since the same thing must be done in validate() function
    my %need = $self->_expreqd($args{required}, $args{validate});

    # import all our fields from our data structure and make 'em tags
    for my $field ($self->field) {

        # any attributes?
        my $attr = $self->{fields}{$field} || {};
        debug 2, "$field: attr = $attr / attr->{value} = $attr->{value}";

        # XHTML requires multiple="multiple". I just work here.
        $attr->{multiple} &&= 'multiple';
        delete $attr->{multiple} unless $attr->{multiple};
        debug 1, "multiple = $attr->{multiple}" if $attr->{multiple};

        # print a label unless it's 0
        my $label = '';
        if ($args{labels} || ! exists $args{labels}) {
            $args{labels} = {} unless ref $args{labels} eq 'HASH';
            $label = _escapehtml($attr->{label} || $args{labels}{$field} || _toname($field));
            debug 1, "label for '$field' field set to '$label'";
        }

        # figure out how to render our little taggy-poo
        my $tag = '';

        # We setup the value separately, delete it, then reinstate later
        my $vattr = delete $attr->{value};
        my @value = defined $vattr ? @{$vattr} : ();
        debug 2, "$field: retrieved value '@value' from \$attr->{value}";

        # Kill the value if we're not sticky (sticky => 0), but
        # only if we got the value from CGI (manual values aren't affected)
        if (! $args{sticky} && defined($self->{field_cgivals}{$field})) {
            @value = _data $attr->{value_orig};
            debug 2, "$field: reset value to '@value' as src was CGI and sticky => 0";
        }

        # set default field type to fieldtype if exists
        $attr->{type} ||= $args{fieldtype} if $args{fieldtype};

        # Pre-catch setting type to 'static', by twiddling an extra flag, which
        # then tells our else statement below to also print out the value
        my $static = $attr->{type} eq 'static' || $args{static};

        # in fact, allow a whole fieldattr thing to work globally
        if ($args{fieldattr} && ref $args{fieldattr} eq 'HASH') {
            while(my($k,$v) = each %{ $args{fieldattr} }) {
                $attr->{$k} ||= $v;
            }
        }

        # Check for text value specifying builtin options
        if ($attr->{options} && ! ref $attr->{options}) {
            if (my $dt = $OPTIONS{"$attr->{options}"}) {
                $attr->{options} = $dt;
            } else {
                belch "Options string '$attr->{options}' may be a typo of a builtin option";
                $attr->{options} = [$attr->{options}];
            }
        }

        # Unless the type has been set explicitly, we make a guess based on how many items
        # there are to display, which is basically, how many options we have
        # Our 'jsclick' option is now changed down in the javascript section, fixing a bug
        if (! $attr->{type} && $args{smartness}) {
            debug 1, "input type not set for '$field', checking for options";
            if (my $ref = ref $attr->{options}) {
                debug 2, "field '$field' has multiple options, so setting to select|radio|checkbox";
                my $n = 0;
                if ($ref eq 'HASH') {
                    $n = keys %{$attr->{options}};
                } elsif ($ref eq 'ARRAY') {
                    $n = @{$attr->{options}};
                } else {
                    puke "Unsupported data structure type '$ref' supplied to 'options' argument";
                }
                $n ||= 0;
                if ($n >= $args{selectnum}) {
                    $attr->{type} = 'select';
                } else {
                    # Something is a checkbox if it is a multi-valued box.
                    # However, it is *also* a checkbox if only single-valued options,
                    # otherwise you can't unselect it.
                    if ($attr->{multiple} || @value > 1 || $n == 1) {
                        $attr->{type} = 'checkbox';
                    } else {
                        $attr->{type} = 'radio';
                    }
                }
            } elsif ($args{smartness} >= 2) {
                debug 2, "smartness >= 2, auto-determining field type for '$field'";
                # as of 2.07, only autodetermine field types with high smartness
                if ($field =~ /passw[or]*d/i) {
                    $attr->{type} = 'password';
                } elsif ($field =~ /(?:details?|comments?)$/i
                        || grep /\n|\r/, @value || $attr->{cols} || $attr->{rows}) {
                    $attr->{type} = 'textarea';
                    # this is dicey, because textareas suck by default
                    $attr->{cols} ||= 60;
                    $attr->{rows} ||= 10;
                } elsif ($field =~ /\bfile/i) {
                    $attr->{type} = 'file';
                }
            }
            $attr->{type} ||= 'text';   # default if no fancy settings matched
            debug 2, "field '$field' set to type '$attr->{type}' automagically";
        }

        # override the type if we're printing them out statically
        if ($static) {
            $attr->{type_orig} = $attr->{type};  # store for later
            $attr->{type} = 'hidden';
        }

        $attr->{type} &&= lc $attr->{type};      # catch for type => 'TEXT'
        debug 1, "generating '$field' field as type '$attr->{type}' (@value)";

        # We now create the validation JavaScript, if it was requested
        # and we have a validation criterion for that specific field
        my $helptag = '';
        my $pattern = $args{validate}{$field};
        if (($args{validate} && $pattern) || $need{$field}) {

            debug 2, "now generating JavaScript validation code for '$field'";

            # Special catch, since many would assume this would work
            if (ref $pattern eq 'Regexp') {
                puke "To use a regex in a 'validate' option you must specify ".
                     "it in single quotes, like '/^\\w+\$/' - failed on '$field' field";
            }

            # Touch a special element so that this element's label prints out bold
            # This is actually an HTML feature that must be nested here...
            $self->{fields}{$field}{required} = 1 if $need{$field};

            # Check our hash to see if it's a special pattern
            ($pattern, $helptag) = _data($VALID{$pattern}) if $VALID{$pattern};

            if ($args{javascript}) {

                # Holders for different parts of JS code
                my $close_brace = '';
                my $idt = 0;
                my $is_select = 0;
                my $in = _indent($idt);

                # make field name JS-safe
                (my $jsfield = $field) =~ s/\W+/_/g;

                # Need some magical JavaScript crap to figure out the type of value
                # God the DOM sucks so much ass!!!! I can't believe the value element
                # changes based on the type of field!!
                #
                # Note we have to use form.elements['name'] instead of just form.name
                # as the JAPH using this module may have defined fields like "u.type"
                #
                # Finally, we expand our error message above, way up here, so that
                # we can simply integrate the custom message with the predefined text
                my $et = $attr->{type} || 'text';
                $et = 'input' if $et eq 'text';
                my $alertstr = sprintf $args{messages}{"js_invalid_$et"}, $label;
                $alertstr =~ s/'/\\'/g;     # handle embedded '
                $alertstr .= '\n';

                if ($attr->{type} eq 'select') {

                    # Get value for field from select list
                    # Always assume it is a multiple to guarantee we get all values
                    $jsfunc .= <<EOF;
$in    // select list: always assume it's multiple to get all values
$in    var selected_$jsfield = 0;
$in    for (var loop = 0; loop < form.elements['$field'].options.length; loop++) {
$in        if (form.elements['$field'].options[loop].selected) {
$in            var $jsfield = form.elements['$field'].options[loop].value;
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
                    $in = _indent($idt += 2);
                    $is_select++;

                } elsif ($attr->{type} eq 'radio' || $attr->{type} eq 'checkbox') {

                    # Get field from radio buttons or checkboxes
                    # Must cycle through all again to see which is checked. yeesh.
                    # However, this only works if there are MULTIPLE checkboxes!
                    # Damn damn damn I have the JavaScript DOM so damn much!!!!!!
                    $jsfunc .= <<EOF;
$in    // radio group or checkboxes
$in    var $jsfield = '';
$in
$in    if (form.elements['$field'][0]) {
$in        for (var loop = 0; loop < form.elements['$field'].length; loop++) {
$in            if (form.elements['$field']\[loop].checked) {
$in                $jsfield = form.elements['$field']\[loop].value;
$in            }
$in        }
$in    } else {
$in        if (form.elements['$field'].checked) {
$in            $jsfield = form.elements['$field'].value;
$in        }
$in    }
EOF
                } else {

                    # get value from text or other straight input
                    # at least this part makes some sense
                    $jsfunc .= <<EOF;
$in    // standard text, hidden, password, or textarea box
$in    var $jsfield = form.elements['$field'].value;
EOF
                }

                # As of v1.97, now our fields are only required if %need got set above
                # So, if not set, add a not-null check to the if below
                my $nn = $need{$field} ? ''
                       : qq{($jsfield || $jsfield === 0) &&\n$in       };

                # hashref is a grouping per-language
                if (ref $pattern eq 'HASH') {
                    $pattern = $pattern->{javascript} || goto HTMLGEN;
                }

                if ($pattern =~ m#^m?(\S)(.*)\1$#) {
                    # JavaScript regexp
                    (my $tpat = $2) =~ s/\\\//\//g;
                    $tpat =~ s/\//\\\//g;
                    $jsfunc .= qq($in    if ($nn (! $jsfield.match(/$tpat/)) ) {\n);
                } elsif (ref $pattern eq 'ARRAY') {
                    # must be w/i this set of values
                    # can you figure out how this piece of Perl works? ha ha ha ha ....
                    $jsfunc .= "$in    if ($nn ($jsfield != '"
                             . join("' && $jsfield != '", @{$pattern}) . "') ) {\n";
                } elsif ($pattern eq 'VALUE' || ($need{$field} && (! $pattern || ref $pattern eq 'CODE'))) {
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
            }
        }
        HTMLGEN:

        # Save options for template creation below
        # "options" are the options for our select list
        my @opt = _opt($attr->{options} ||= $vattr);
        @opt = _sort(@opt, $attr->{sortopts}) if $attr->{sortopts};

        # Must catch this to prevent non-existent fault below
        $attr->{labels} = {} unless ref $attr->{labels} eq 'HASH';
        $attr->{sortopts} ||= $args{sortopts} if $args{sortopts};

        # Now we generate the HTML tag for each element 
        if ($attr->{type} eq 'select') {

            $attr->{onChange} = delete $attr->{jsclick} if $attr->{jsclick};

            # handle multiples.
            $attr->{multiple} = 'multiple' if @value > 1;   # auto-detect

            unshift @opt, ['', $args{messages}{form_select_default}]
                if $args{smartness} && ! $attr->{multiple};

            # generate our select tag. 
            delete $attr->{type};     # prevent <select type="select">
            $tag = _tag('select', name => $field, %{$attr});
            for my $opt (@opt) {
                # Since our data structure is a series of ['',''] things,
                # we get the name from that. If not, then it's a list
                # of regular old data that we _toname if nameopts => 1 
                my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
                $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                my @slct = _ismember($o, @value) ? (selected => 'selected') : ();
                $tag .= _tag('option', value => $o, @slct) . _escapehtml($n) . '</option>';
            }
            $tag .= '</select>';
            $attr->{type} = 'select';

        } elsif ($attr->{type} eq 'radio' || $attr->{type} eq 'checkbox') {
            $attr->{onClick} = delete $attr->{jsclick} if $attr->{jsclick};

            # to allow checkboxes/radio buttons to wrap in columns
            my $checkbox_table = 0;  # toggle
            my $col_num = 0;
            if (defined($attr->{columns}) && $attr->{columns} > 0) {
                $checkbox_table = 1;
                $tag .= _tag('table', %{$args{table}});
            }

            # for making an unordered list out of our options (for both checkbox and radio)
            my $checkbox_ulist = 0;
            if ($attr->{ulist}) {
                $checkbox_ulist = 1;
                $tag .= '<ul>';
            }

            for my $opt (@opt) {
                #  Divide up checkboxes in a user-controlled manner
                if ($checkbox_table) {
                    $tag .= '<tr>' if $col_num % $attr->{columns} == 0;
                    $tag .= '<td>' . $font;
                }
                $tag .= '<li>' if $checkbox_ulist;
                # Since our data structure is a series of ['',''] things,
                # we get the name from that. If not, then it's a list
                # of regular old data that we _toname if nameopts => 1 
                my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
                $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                my @slct = _ismember($o, @value) ? (checked => 'checked') : ();
                $tag .= _tag('input', name => $field, value => $o, id => "${field}_$o", %{$attr}, @slct) 
                      . ' ' . _tag('label', for => "${field}_$o") . _escapehtml($n) . '</label> ';
                $tag .= '<br />' if $attr->{linebreaks};
                $tag .= '</td></tr>' if $checkbox_table && 
                                     ($col_num++ % $attr->{columns} == 0 || $col_num == @opt);
                $tag .= "</li>\n" if $checkbox_ulist;
            }
            $tag .= '</table>' if $checkbox_table;
            $tag .= '</ul>' if $checkbox_ulist;
        } elsif ($attr->{type} eq 'textarea') {
            $attr->{onChange} = delete $attr->{jsclick} if $attr->{jsclick};
            my $text = join "\n", @value;
            $tag = _tag('textarea', name => $field, %{$attr}) . _escapehtml($text) . '</textarea>';

        } else {
            $attr->{onChange} = delete $attr->{jsclick} if $attr->{jsclick};
            # handle default size attr
            $attr->{size} ||= $args{attr}{size} if $args{attr}{size};

            # we iterate over each value - this is the only reliable
            # way to handle multiple form values of the same name
            @value = (undef) unless @value; # this creates a single-element array
            for my $value (@value) {
                # setup the value
                my %value = (defined($value) && $attr->{type} ne 'password'
                                             && $attr->{type_orig} ne 'password')
                                ? (value => $value) : ();

                # render the tag
                $tag .= _tag('input', name => $field, %value, %{$attr});

                # Check for passwords
                $value = '********' if $attr->{type_orig} eq 'password' && $args{smartness};

                # This is a static field
                if ($attr->{type} eq 'hidden' && $static) {
                    # Lookup the description of the option, and print it
                    # if available, otherwise it will use whatever value was set to.
                    for my $opt (@opt) {
                        # Since our data structure is a series of ['',''] things,
                        # we get the name from that. If not, then it's a list
                        # of regular old data that we _toname if nameopts => 1 
                        my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);

                        if ($o eq $value) {
                            # We found a matching option.
                            $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                            $tag .= _escapehtml($n) . ' ';
                            last;
                        }
                    }
                }
                $tag .= '<br />' if $attr->{linebreaks};
            }

            # special catch to make life easier
            # if there's a 'file' field, set the form enctype if they forgot
            if ($attr->{type} eq 'file' && $args{smartness}) {
                $args{enctype} ||= 'multipart/form-data';
                debug 2, "verified enctype => 'multipart/form-data' for 'file' field";
            }
        }

        debug 2, "generation done, got opt = @opt; tag = $tag";

        # reset the value attr
        $attr->{value} = $vattr;

        # setup an error, if any
        my $et = $attr->{type} || 'text';
        $et = 'input' if $et eq 'text';
        my $error = '';
        if (exists $self->{fields}{$field}{invalid}) {
            $error = $self->{fields}{$field}{invalid};  # custom message
            if ($error eq 1) {    # hackish but effective
                $error = $args{messages}{"form_invalid_$et"}
                      || $args{messages}{form_invalid_field};
            }
        }
        debug 2, "got error string = $error for form_invalid_$et";

        # if we have a template, then we setup the tag to a tmpl_var of the
        # same name via param(). otherwise, we generate HTML rows and stuff
        # Added support for Text::Template and assigned type Text.
        if (ref $args{template} eq 'HASH' && 
           ( $args{template}{type} eq 'TT2' || $args{template}{type} eq 'Text' ) ) {
            # Template Toolkit can access complex data pretty much unaided
            $tmplvar{field}{$field} = {
                 %{ $self->{fields}{$field} },
                 field   => $tag,
                 value   => $value[0],
                 values  => \@value,
                 options => \@opt,
                 label   => $label,
                 comment => $attr->{comment} || '',
                 error   => $error,
            };
        } elsif ($args{template}) {
            # for HTML::Template, each data struct is manually assigned
            # to a separate <tmpl_var> and <tmpl_loop> tag

            # assign the field tag
            $tmplvar{"field-$field"} = $tag;
            debug 2, "<tmpl_var field-$field> = " . $tmplvar{"field-$field"};

            # and the value tag - can only hold first value!
            $tmplvar{"value-$field"} = $value[0];
            debug 2, "<tmpl_var value-$field> = " . $tmplvar{"value-$field"};

            # and the label tag for the field
            $tmplvar{"label-$field"} = $label;
            debug 2, "<tmpl_var label-$field> = " . $tmplvar{"value-$field"};

            # and the comment tag
            $tmplvar{"comment-$field"} = $attr->{comment} || '';

            # and any error
            $tmplvar{"error-$field"} = $error;

            # create a <tmpl_loop> for multi-values/multi-opts
            # we can't include the field, really, since this would involve
            # too much effort knowing what type
            my @tmpl_loop = ();
            for my $opt (@opt) {
                # Since our data structure is a series of ['',''] things,
                # we get the name from that. If not, then it's a list
                # of regular old data that we _toname if nameopts => 1 
                my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
                $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                my($slct, $chk) = _ismember($o, @value) ? ('selected', 'checked') : ('','');
                debug 2, "<tmpl_loop loop-$field> = adding { label => $n, value => $o }";
                push @tmpl_loop, {
                    label => _escapehtml($n),
                    value => $o,
                    checked => $chk,
                    selected => $slct,
                };
            }

            # now assign our loop-field
            $tmplvar{"loop-$field"} = \@tmpl_loop;

            # finally, push onto a top-level loop named "fields"
            push @{$tmplvar{fields}}, {                                                         
                field   => $tag,                                                                  
                value   => $value[0],
                values  => \@value,
                options => \@opt,
                label   => $label,
                comment => $attr->{comment} || '',
                error   => $error,
                loop    => \@tmpl_loop
            }                                                                                 

        } else {
            # bold it if so necessary
            $label = "<b>$label</b>" if $need{$field};
            my $oops = '';

            # and error it too
            if ($error) {
                $label = qq(<font color="$args{messages}{form_invalid_color}">$label</font>);
                $oops = qq($tdo<font size="-1">$error</font>$tdc);
            }

            # and spacing if aligned right
            $label .= '&nbsp;' if $args{lalign} eq 'right';

            # and postfix the helptag if applicable
            $helptag = '' if $args{nohelp} || $static;
            $helptag = qq( <font size="-1">($helptag)</font>) if $helptag;

            if ($attr->{type} eq 'hidden' && ! $static) {
                # hidden fields in a non-static context get, well, hidden
                $outhtml .= $tag . $br;
            } else {
                my $comment = $attr->{comment} ? (' ' . $attr->{comment}) : '';
                $outhtml .= $tro . $tdl . $label . $tdc . $tdo
                          . $tag . $comment . $helptag . $tdc . $oops
                          . $trc . $br;
            }
        }
    } # end foreach field loop

    # Finally, close our JavaScript if it was opened, wrapping in <script> tags
    if ($jsfunc) {
        (my $alertstart = $args{messages}{js_invalid_start}) =~ s/%s/'+invalid+'/g;
        (my $alertend   = sprintf $args{messages}{js_invalid_end}) =~ s/%s/'+invalid+'/g;
        $jsfunc .= <<EOJS;
    if (invalid > 0 || alertstr != '') {
        if (! invalid) invalid = 'The following';   // catch for programmer error
        alert('$alertstart'+'\\n\\n'+alertstr+'\\n'+'$alertend');
        // reset counters
        alertstr = '';
        invalid  = 0;
        return false;
    }
EOJS
        $jsfunc .= "    return true;  // all checked ok\n}\n";

        # setup our form onSubmit
        # needs to be ||= so user can overrride w/ own tag
        $args{onSubmit} ||= "return $jsname(this);"; 
    }

    # Must do separately to handle jshead
    if (my $ajsh = delete $args{jshead}) {
        $jsfunc .= $ajsh;
    }

    if ($jsfunc) { 
        # Must *prepend* opening <script> tag
        $jsfunc  = "\n" . _tag('script', language => 'JavaScript1.3')
                 . "<!-- hide from old browsers\n"
                 . $jsfunc;

        # Now append closing tag
        $jsfunc .= "//-->\n</script><noscript>"
                 . qq(<font color="$args{messages}{form_invalid_color}"><b>Please enable JavaScript )
                 . q(or use a newer browser</b></font></noscript><p>);
    }

    # handle the submit/reset buttons
    # logic is a little complicated - if set but to a false value,
    # then leave off. otherwise use as the value for the tags.
    my($submit, $reset) = ('', '');
    unless ($args{static}) {
        if ($args{submit} || ! exists $args{submit}) {
            if (ref $args{submit} eq 'ARRAY') {
                # multiple buttons + JavaScript - here we go!
                for my $s (_data $args{submit}) {
                    my @oncl = ($args{submit} && $args{javascript})
                                ? (onClick => 'this.form._submit.value = this.value;')
                                : ();
                    $submit .= _tag('input', type => 'submit', name => '_submit',
                                value => $s, @oncl);
                }
            } else {
                # show the text on the button
                $submit = _tag('input', type => 'submit', name => '_submit',
                                value => ($args{submit} || $args{messages}{form_submit_default}));
            }
        }
        if ($args{reset} || ! exists $args{reset}) {
            $reset = _tag('input', type => 'reset', name => '_reset',
                           value => ($args{reset}  || $args{messages}{form_reset_default}));
        }
    }

    $outhtml .= $tro . $td2 . $co . $reset . $submit . $cc
              . $tdc . $trc . $tc . $br;

    # closing </form> tag
    $outhtml .= "</form>";

    # and body/html
    $outhtml .= "</body></html>\n" if $args{header};

    # Hidden trailer. If you perceive this as annoying, let me know and I
    # may remove it. It's supposed to help.
    my $copy = $::TESTING ? ''
             : "\n<!-- Generated by CGI::FormBuilder v$VERSION available from www.formbuilder.org -->\n";

    # opening <form> tag: this is reversed, because our JavaScript might
    # have added an onSubmit attr. as such we have to add to the front
    # we also include a couple special state tracking tags, _submitted
    # and _sessionid.
    delete $args{sortopts};     # prevent "<form sortopts=1>"
    my $formtag = $copy . _tag('form', %args);

    # suffix _submitted w/ form name if present
    my($sid, $smv) = (0, 0);
    my $smtag = '_submitted' . ($args{name} ? "_$args{name}" : '');
    if ($CGI) {
        $sid = $CGI->param('_sessionid') || '';
        $smv = ($CGI->param($smtag) || 0) + 1;
    }
    $formtag .= _tag('input', type => 'hidden', name => $smtag, value => $smv)
              . _tag('input', type => 'hidden', name => '_sessionid', value => $sid);

    # If we set keepextras, then this means that any extra fields that
    # we've set that are *not* in our fields() will be added to the form
    if ($args{keepextras} && $CGI) {
        my @just_these = ();
        if (my $ref = ref $args{keepextras}) {
            if ($ref eq 'ARRAY') {
                @just_these = @{$args{keepextras}}; 
            } else {
                puke "Unsupported data structure type '$ref' passed to 'keepextras' option";
            }
        }
        for my $k ($CGI->param) {
            # skip leading underscore fields, previously-defined fields, and submit/reset
            next if $self->{fields}{$k} || $k =~ /^_/ || $k eq 'submit' || $k eq 'reset';
            for my $v ($CGI->param($k)) {
                if (! @just_these || _ismember($k, @just_these)) {
                    $formtag .= _tag('input', type => 'hidden', name => $k, value => $v);
                }
            }
        }
    }

    # Now assemble the top of the form
    $outhtml = $formtag . $to . $br . $outhtml;

    # FINAL STEP
    # If we're using a template, then we "simply" setup a bunch of vars
    # in %tmplvar (which is also accessible via $form->tmpl_param) and
    # then use $h->output to render the template. Otherwise, we "print"
    # the HTML we generated above verbatim by returning as a scalar.
    # 
    # NOTE: added code to handle Template Toolkit, abw November 2001
    my $header = $args{header} ? $self->cgi_header : '';

    if ($args{template}) {
        my (%tmplopt, $tmpltype) = ();

        if (ref $args{template} eq 'HASH') {
            %tmplopt = %{$args{template}};
            $tmpltype = delete($tmplopt{type}) || 'HTML';
        } else {
            %tmplopt = (filename => $args{template}, die_on_bad_params => 0);
            $tmpltype = 'HTML';
        }

        if ($tmpltype eq 'HTML') {
            eval { require HTML::Template };
            $tmplopt{die_on_bad_params} = 0;    # force to avoid blow-ups
            puke "Can't use templates because HTML::Template is not installed!" if $@; 
            my $h = HTML::Template->new(%tmplopt);

            # a couple special fields
            $tmplvar{'form-title'}  = $args{title} || '';
            $tmplvar{'form-start'}  = $formtag;
            $tmplvar{'form-submit'} = $submit;
            $tmplvar{'form-reset'}  = $reset;
            $tmplvar{'form-end'}    = '</form>';
            $tmplvar{'js-head'}     = $jsfunc;

            # loop thru each field we have and set the tmpl_param
            while(my($param, $tag) = each %tmplvar) {
                $h->param($param => $tag);
            }

            # prepend header to template rendering
            $outhtml = $header . $h->output;

        } elsif ($tmpltype eq 'TT2') {

            eval { require Template };
            puke "Can't use templates because Template Toolkit is not installed!" if $@; 

            my ($tt2engine, $tt2template, $tt2data, $tt2var, $tt2output);
            $tt2engine = $tmplopt{engine} || { };
            $tt2engine = Template->new($tt2engine) 
                || puke $Template::ERROR unless UNIVERSAL::isa($tt2engine, 'Template');
            $tt2template = $tmplopt{template}
                || puke "Template Toolkit template not specified";
            $tt2data = $tmplopt{data} || {};
            $tt2var  = $tmplopt{variable};      # optional var for nesting

            # special fields
            $tmplvar{'title'}  = $args{title} || '';
            $tmplvar{'start'}  = $formtag;
            $tmplvar{'submit'} = $submit;
            $tmplvar{'reset'}  = $reset;
            $tmplvar{'end'}    = '</form>';
            $tmplvar{'jshead'} = $jsfunc;
            $tmplvar{'invalid'} = $self->{state}{invalid};
            $tmplvar{'fields'} = [ map $tmplvar{field}{$_},
                   @{ $self->{field_names} } ];
            if ($tt2var) {
                $tt2data->{$tt2var} = \%tmplvar;
            } else {
                $tt2data = { %$tt2data, %tmplvar };
            }

            $tt2engine->process($tt2template, $tt2data, \$tt2output)
                || puke $tt2engine->error();

            $outhtml = $header . $tt2output;

      } elsif( $tmpltype eq 'Text' ) {
            # Text::Template support. Similar to Template Toolkit support.
            eval { require Text::Template };
            puke "Can't use templates because Text::Template is not installed!" if $@;
            # This sub taken helps us to support all of Text::Template's argument naming conventions
            my $tt_param_name = sub {
              my ($arg, %h) = @_;
              my ($key) = grep { exists $h{$_} } ($arg, "\u$arg", "\U$arg", "-$arg", "-\u$arg", "-\U$arg");
              return $key || $arg;
            };

            my ($tt_engine, $tt_data, $tt_var, $tt_output, $tt_fill_in);
            $tt_engine = $tmplopt{engine} || { }; 
            unless (UNIVERSAL::isa($tt_engine, 'Text::Template')) {
                $tt_engine->{&$tt_param_name('type',%$tt_engine)}   ||= 'FILE';
                $tt_engine->{&$tt_param_name('source',%$tt_engine)} ||= $tmplopt{template} ||
                    puke "Text::Template source not specified, use the 'template' option";
                $tt_engine->{&$tt_param_name('delimiters',%$tt_engine)} ||= [ '<%','%>' ];
                $tt_engine = Text::Template->new(%$tt_engine)
                    || puke $Text::Template::ERROR;
            }
            if( ref($tmplopt{data}) eq 'ARRAY' ) {
                $tt_data = $tmplopt{data};
            } else {
                $tt_data = [ $tmplopt{data} ];
            }
            $tt_var  = $tmplopt{variable};      # optional var for nesting

            # special fields
            $tmplvar{'title'}  = $args{title} || '';
            $tmplvar{'start'}  = $formtag;
            $tmplvar{'submit'} = $submit;
            $tmplvar{'reset'}  = $reset;
            $tmplvar{'end'}    = '</form>';
            $tmplvar{'jshead'} = $jsfunc;
            $tmplvar{'invalid'} = $self->{state}{invalid};
            $tmplvar{'fields'} = [ map $tmplvar{field}{$_},
                   @{ $self->{field_names} } ];
            if ($tt_var) {
                push @$tt_data, { $tt_var => \%tmplvar };
            } else {
                push @$tt_data, \%tmplvar;
            }

            $tt_fill_in = $tmplopt{fill_in} || {};
            my $tt_fill_in_hash = $tt_fill_in->{&$tt_param_name('hash',%$tt_fill_in)} || {};
            if( ref($tt_fill_in_hash) eq 'ARRAY' ) {
                push @$tt_fill_in_hash, @$tt_data;
            } else {
                $tt_fill_in_hash = [ $tt_fill_in_hash, @$tt_data ];
            }
		
            $tt_fill_in_hash = {} unless scalar(@$tt_fill_in_hash);
            $tt_fill_in->{&$tt_param_name('hash',%$tt_fill_in)} = $tt_fill_in_hash;
            $tt_output = $tt_engine->fill_in(%$tt_fill_in)
                || puke "Text::Template expansion failed: $Text::Template::ERROR";

            $outhtml = $header . $tt_output;

        } else {
            puke "Invalid template type '$tmpltype' specified - can be 'HTML' or 'TT2' or 'Text'";
        }

    } else {

        my $body = _tag('body', %{$args{body}});

        # assemble header HTML-compliantly
        $jsfunc = "<html><head><title>$args{title}</title>$jsfunc</head>"
                . "$body$font<h3>$args{title}</h3>" if $args{header};

        # Insert any text we may have specified
        my $text = $args{text} || '';
        if ($self->{state}{invalid}) {
            $text .= sprintf $args{messages}{form_invalid_text}, $self->{state}{invalid},
                             $args{messages}{form_invalid_color};
        } elsif (keys %need) {
            $text .= $args{messages}{form_required_text};
        }

        $outhtml = $header . $jsfunc . $text . $outhtml;
    }

    # XXX finally, reset our fields and field_names
    $self->{field_names} = $oldfn;
    $self->{fields} = $oldfv;

    return $outhtml;
}

sub confirm () {
    # This is nothing more than a special wrapper around render()
    my $self = shift;
    my %args = _args(@_);
    my $date = localtime;
    $args{text} ||= sprintf $self->{opt}{messages}{form_confirm_text}, $date;
    $args{static} = 1;
    return $self->render(%args);
}

sub mail () {
    # This is a very generic mail handler
    my $self = shift;
    my %args = _args(@_);

    # Where does the mailer live? Must be sendmail-compatible
    my $mailer = undef;
    unless ($mailer = $args{mailer} && -x $mailer) {
        for my $sendmail (qw(/usr/lib/sendmail /usr/sbin/sendmail /usr/bin/sendmail)) {
            if (-x $sendmail) {
                $mailer = "$sendmail -t";
                last;
            }
        }
    }
    unless ($mailer) {
        belch "Cannot find a sendmail-compatible mailer to use; mail aborting";
        return;
    }
    unless ($args{to}) {
        belch "Missing required 'to' argument; cannot continue without recipient";
        return;
    }

    # untaint
    my $oldpath = $ENV{PATH};
    $ENV{PATH} = '/usr/bin:/usr/sbin';

    open(MAIL, "|$mailer >/dev/null 2>&1") || next;
    print MAIL "From: $args{from}\n";
    print MAIL "To: $args{to}\n";
    print MAIL "Cc: $args{cc}\n" if $args{cc};
    print MAIL "Subject: $args{subject}\n\n";
    print MAIL "$args{text}\n";

    # retaint
    $ENV{PATH} = $oldpath;

    return close(MAIL);
}

sub mailconfirm () {

    # This prints out a very generic message. This should probably
    # be much better, but I suspect very few if any people will use
    # this method. If you do, let me know and maybe I'll work on it.

    my $self = shift;
    my $to = shift unless (@_ > 1);
    my %args = _args(@_);

    # must have a "to"
    return unless $args{to} ||= $to;

    # defaults
    $args{from}    ||= 'auto-reply';
    $args{subject} ||= "$self->{opt}{title} Submission Confirmation";
    $args{text}    ||= <<EOF;
Your submission has been received and will be processed shortly. 

If you have any questions, please contact our staff by replying
to this email.
EOF
    $self->mail(%args);
}

sub mailresults () {
    # This is a wrapper around mail() that sends the form results
    my $self = shift;
    my %args = _args(@_);

    # Get the field separator to use
    my $delim = $args{delimiter} || ': ';
    my $join  = $args{joiner}    || $";
    my $sep   = $args{separator} || "\n";

    # subject default
    $args{subject} ||= "$self->{opt}{title} Submission Results";

    if ($args{skip}) {
        if ($args{skip} =~ m#^m?(\S)(.*)\1$#) {
            ($args{skip} = $2) =~ s/\\\//\//g;
            $args{skip} =~ s/\//\\\//g;
        }
    }

    my @form = ();
    for my $field ($self->fields) {
        if ($args{skip} && $field =~ /$args{skip}/) {
            next;
        }
        my $v = join $join, $self->field($field);
        $field = _toname($field) if $args{labels};
        push @form, "$field$delim$v"; 
    }
    my $text = join $sep, @form;

    $self->mail(%args, text => $text);
}

sub submitted () {
    # this returns the value of the submit key, if any
    return unless $CGI;
    my $self = shift;
    my $smtag = shift || ('_submitted' . ($self->{opt}{name} ? "_$self->{opt}{name}" : ''));

    if ($CGI->param($smtag)) {
        # If we've been submitted, then we return the value of
        # the submit tag (which allows multiple submission buttons).
        # Must use an "|| 0E0" or else hitting "Enter" won't cause
        # $form->submitted to be true (as the button is only sent
        # across CGI when clicked).
        my $sr = $CGI->param('_submit') || '0E0';
        debug 2, "submitted() is true, returning $sr";
        return $sr;
    } else {
        return;
    }
}

sub sessionid () {
    # checks/sets the _sessoinid parameter
    return unless $CGI;
    my $self = shift;
    my $sid  = shift;
    $sid ? $CGI->param(-name => '_sessionid', -value => $sid, -override => 1)
         : $CGI->param('_sessionid');
}

# These allow a crude method of delegation
sub cgi_param () {
    return unless $CGI;
    shift; $CGI->param(@_);
}

sub cgi_header () {
    return unless $CGI;
    shift; $CGI->header(@_);
}

# This allows us to interface with our HTML::Template
sub tmpl_param () {
    my $self = shift; 
    my $key  = shift;
    @_ ? $self->{tmplvar}{$key} = shift
       : $self->{tmplvar}{$key};
}

sub validate () {

    # This function does all the validation on the Perl side.
    # It doesn't generate JavaScript; see render() for that...

    my $self = shift;
    my $form = $self;   # XXX alias for examples (paint-by-numbers)
    local $^W = 0;      # -w sucks

    debug 1, "called validate(@_)";

    # Create our %valid hash which takes into account local args
    my %valid = (%{$self->{opt}{validate} || {}}, _args(@_));

    # Get %need from expansion of our 'required' param to new()
    my %need  = $self->_expreqd($self->{opt}{required}, \%valid);

    # Fail or success?
    my $bad = 0;

    for my $field (@{$self->{field_names}}) {

        # Get validation pattern if exists
        my $pattern = $valid{$field} || $valid{ALL} || 'VALUE';

        # fatal error if they try to validate nonexistent field
        puke "Attempt to validate non-existent field '$field'"
            unless $self->{fields}{$field};

        # check for if $need{$field}; if not, next if blank
        if ($need{$field}) {
            debug 1, "$field: is required per 'required' param";
        } else {
            debug 1, "$field: is optional per 'required' param";
            next unless defined $self->field($field);
            debug 1, "$field: ...but is defined, so still checking";
        }

        # loop thru, and if something isn't valid, we tag it
        my $atleastone = 0;
        for my $value ($self->field($field)) {
            my $thisfail = 0;
            $atleastone++;

            # Check our hash to see if it's a special pattern
            ($pattern) = _data($VALID{$pattern}) if $VALID{$pattern};

            debug 1, "$field: validating ($value) against pattern '$pattern'";

            # hashref is a grouping per-language
            if (ref $pattern eq 'HASH') {
                $pattern = $pattern->{perl} || next;
            }

            if ($pattern =~ m#^m?(\S)(.*)\1$#) {
                # it be a regexp
                (my $tpat = $2) =~ s/\\\//\//g;
                $tpat =~ s/\//\\\//g;
                debug 1, "$field: does '$value' =~ /$tpat/ ?";
                unless ($value =~ /$tpat/) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
            } elsif (ref $pattern eq 'ARRAY') {
                # must be w/i this set of values
                debug 1, "$field: is '$value' in (@{$pattern}) ?";
                unless (_ismember($value, @{$pattern})) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
            } elsif (ref $pattern eq 'CODE') {
                # eval that mofo, which gives them $form
                debug 1, "$field: does $pattern($value) ret true ?";
                unless ( &{$pattern}($value) ) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
            } elsif ($pattern eq 'VALUE') {
                # Not null
                debug 1, "$field: length '$value' > 0 ?";
                unless (defined($value) && length($value)) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
            } else {
                # literal string is a literal comparison, but warn of typos...
                belch "Validation string '$pattern' may be a typo of a builtin pattern"
                    if ($pattern =~ /^[A-Z]+$/); 
                # must escape to prevent serious problem if $value = "'; system 'rm -f /'; '"
                debug 1, "$field: '$value' $pattern ? 1 : 0";
                unless (eval qq(\$value $pattern ? 1 : 0)) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
                belch "Literal code eval error in validate: $@" if $@;
            }

            # Just for debugging's sake
            $thisfail ? debug 2, "$field: validation FAILED"
                      : debug 2, "$field: validation passed";
        }
        # If not $atleastone and they asked for validation, then we
        # know that we have an error since this means no values
        unless ($atleastone) { $self->{fields}{$field}{invalid} = 1; $bad++; }
    }
    debug 2, "validation done, failures (\$bad) = $bad";
    $self->{state}{invalid} = $bad;
    return $bad ? 0 : 1;
}

sub AUTOLOAD () {
    # This allows direct addressing by name, for quicker usage
    my $self  = shift;
    my($name) = $AUTOLOAD =~ /.*::(.+)/;
    return 1 if $name eq 'DESTROY';
    if ($self->{fields}{$name}) {
        if (@_) {
            my %args = @_;
            $args{name} = $name;
            debug 1, "AUTOLOAD dispatch to \$form->field(name $name @_)";
            return $self->field(%args);
        } else {
            debug 1, "AUTOLOAD dispatch to \$form->field($name)";
            return $self->field($name);
        }
    } elsif (! @_) {
        debug 1, "AUTOLOAD dispatch to \$CGI->param($name)";
        return $CGI->param($name);
    } else {
        puke "Attempt to address non-existent field '$name' by name"
    }
}

1;

