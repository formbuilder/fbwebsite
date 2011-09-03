
# Copyright (c) 2001-2002 Nathan Wiger <nate@nateware.com>
# Please visit www.formbuilder.org for support information
# Use "perldoc FormBuilder.pm" for documentation

package CGI::FormBuilder;

=head1 NAME

CGI::FormBuilder - Easily generate and process stateful forms

=head1 SYNOPSIS

    use CGI::FormBuilder;

    # Let's assume we did a DBI query to get existing values
    my $dbval = $sth->fetchrow_hashref;

    my $form = CGI::FormBuilder->new(
                    method => 'POST',
                    fields => [qw/name email phone gender/],
                    values => $dbval,
                    validate => { email => 'EMAIL', phone => 'PHONE' },
                    required => 'ALL',
                    font => 'arial,helvetica',
               );

    # Change gender field to have options
    $form->field(name => 'gender', options => [qw/Male Female/]);

    if ($form->submitted && $form->validate) {
        my $fields = $form->field;    # get form fields as hashref

        # Do something to update your data (you would write this)
        do_data_update($fields->{name}, $fields->{email},
                       $fields->{phone}, $fields->{gender});

        # Show confirmation screen
        print $form->confirm(header => 1);

        # Email the person a brief confirmation
        $form->mailconfirm(to => $fields->{email});

    } else {
        # Print out the form
        print $form->render(header => 1);
    }

=cut

use Carp;
use strict;
use vars qw($VERSION $CGIMOD $CGI $AUTOLOAD);
$VERSION = do { my @r=(q$Revision: 2.7 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };

# use CGI for stickiness (prefer CGI::Minimal for _much_ better speed)
# we try the faster one first, since they're compatible for our needs
# XXX sorry, this is no longer true, due to no ";" support and file uploads

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
    EMAIL => ['/^[\w\-\+\.]+\@[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/', 'name@host.domain'],
    CARD  => '/^\d{4}[\- ]?\d{4}[\- ]?\d{4}[\- ]?\d{4}$|^\d{4}[\- ]?\d{6}[\- ]?\d{5}$/',
    MMYY  => ['/^([1-9]|1[0-2])\/?[0-9]{2}$/', 'MM/YY'],
    MMYYYY=> ['/^([1-9]|1[0-2])\/?[0-9]{4}$/', 'MM/YYYY'],
    DATE  => ['/^([1-9]|1[0-2])\/?([1-9]|[1-2][0-9]|3[1-2])\/?[0-9]{4}$/', 'MM/DD/YYYY'],
    TIME  => ['/^[0-9]{1,2}:[0-9]{2}$/', 'HH:MM (24-hour)' ],
    AMPM  => ['/^[0-9]{1,2}:[0-9]{2}\s*([aA]|[pP])[mM]$/', 'HH:MM AM/PM' ],
    ZIPCODE=> '/^\d{5}$|^\d{5}\-\d{4}$/',
    STATE => ['/^[a-zA-Z]{2}$/', 'two-letter abbr'],
    COUNTRY => ['/^[a-zA-Z]{2}$/', 'two-letter abbr'],
    IPV4  => ['/^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-5][0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-5][0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-5][0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-5][0-5])$/', 'IP address'],
    NETMASK => ['/^(\d{1,3}\.){0,3}\d{1,3}$/', 'IP netmask' ],
    FILE  => ['/^[\/\w\.\-]+$/', 'UNIX format'],
    WINFILE => ['/^[a-zA-Z]:\\[\\\w\s\.\-]+$/', 'Windows format'],
    MACFILE => ['/^[:\w\.\-]+$/', 'Mac format'],
    USER  => ['/^[-a-zA-Z0-9]{4,8}$/', '4-8 characters'],  # require a 4-8 char username
    HOST  => ['/^[a-zA-Z0-9][-a-zA-Z0-9]*$/', 'valid hostname'],
    DOMAIN=> ['/^[a-zA-Z0-9][-a-zA-Z0-9\.]*\.[a-zA-Z]+$/', 'DNS domain'],   # mostly correct, but allows "dom.c-o.uk"
    ETHER => ['/^[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}[\.:]?[\da-f]{1,2}$/i', 'ethernet' ],
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
    linebreaks multiple nameopts options override params radionum required
    reset selectnum smartness sortopts static sticky submit table
    template title type_orig validate valign value_orig values messages 
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

    my $self = shift;
    my %args = _args(@_);
    my %val  = ();
    my @val  = ();
    local $^W = 0;      # -w sucks

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
            } elsif ($field =~ /^countr/i) {
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
        if ($OURATTR{$key} || ($key eq 'text' && $name ne 'body')) {
            shift; next;
        }
        my $val = _escapehtml shift;    # minimalist HTML escaping
        push @tag, qq($key="$val");
    }
    return '<' . join(' ', $name, sort @tag) . '>';
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
    belch "You won't be able to get at any form values unless you specify 'fields' to new()"
        unless $args{fields};

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
        local $^W = 0;   # length() triggers uninit, too slow to catch
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
        $args{table} = 1 if @{$self->{field_names}} > 1;
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
                ? ($args{table} ? "\n" : "<br>\n") : '';

    # For holding the JavaScript validation code
    my $jsfunc = '';
    my $jsname = $args{name} ? "validate_$args{name}" : 'validate';

    # User-specified jsfunc options
    my $ajsf = delete $args{jsfunc} || '';

    if ($args{javascript} && $args{validate} || $args{required}) {
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

        # print a label unless it's 0
        my $label = '';
        if ($args{labels} || ! exists $args{labels}) {
            $args{labels} = {} unless ref $args{labels} eq 'HASH';
            $label = $attr->{label} || $args{labels}{$field} || _toname($field);
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

        # Pre-catch setting type to 'static', by twiddling an extra flag, which
        # then tells our else statement below to also print out the value
        my $static = $attr->{type} eq 'static' || $args{static};

        # set default field type to fieldtype if exists
        $attr->{type} ||= $args{fieldtype} if $args{fieldtype};

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
            $self->{fields}{$field}{required} = 1;

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

                # pre-catch: hashref is a grouping per-language
                if (ref $pattern eq 'HASH') {
                    $pattern = $pattern->{javascript} || next;
                }

                if ($pattern =~ m!^m?(.).*\1$!) {
                    # JavaScript regexp
                    $jsfunc .= qq($in    if ($nn (! $jsfield.match($pattern)) ) {\n);
                } elsif (ref $pattern eq 'ARRAY') {
                    # must be w/i this set of values
                    # can you figure out how this piece of Perl works? ha ha ha ha ....
                    $jsfunc .= "$in    if ($nn ($jsfield != '"
                             . join("' && $jsfield != '", @{$pattern}) . "') ) {\n";
                } elsif ($pattern eq 'VALUE' || $need{$field}) {
                    # Not null
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

        # Save options for template creation below
        my @opt = ();

        # Must catch this to prevent non-existent fault below
        $attr->{labels} = {} unless ref $attr->{labels} eq 'HASH';
        $attr->{sortopts} ||= $args{sortopts} if $args{sortopts};

        # Now we generate the HTML tag for each element 
        if ($attr->{type} eq 'select') {

            $attr->{onChange} = delete $attr->{jsclick} if $attr->{jsclick};

            # "options" are the options for our select list
            @opt = _opt($attr->{options} ||= $vattr);
            @opt = _sort(@opt, $attr->{sortopts}) if $attr->{sortopts};
            unshift @opt, ['', $args{messages}{form_select_default}]
                if $args{smartness} && ! $attr->{multiple};

            # generate our select tag. handle multiples.
            my $mult = $attr->{multiple} || (@value > 1) ? ' multiple' : '';
            $tag = _tag("select$mult", name => $field, %{$attr});
            for my $opt (@opt) {
                # Since our data structure is a series of ['',''] things,
                # we get the name from that. If not, then it's a list
                # of regular old data that we _toname if nameopts => 1 
                my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
                $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                my $slct = _ismember($o, @value) ? ' selected' : '';
                $tag .= _tag("option$slct", value => $o) . $n . '</option>';
            }
            $tag .= '</select>';

        } elsif ($attr->{type} eq 'radio' || $attr->{type} eq 'checkbox') {
            $attr->{onClick} = delete $attr->{jsclick} if $attr->{jsclick};

            # get our options
            @opt = _opt($attr->{options} ||= $vattr);
            @opt = _sort(@opt, $attr->{sortopts}) if $attr->{sortopts};

            for my $opt (@opt) {
                # Since our data structure is a series of ['',''] things,
                # we get the name from that. If not, then it's a list
                # of regular old data that we _toname if nameopts => 1 
                my($o,$n) = (ref $opt eq 'ARRAY') ? (@{$opt}) : ($opt);
                $n ||= $attr->{labels}{$o} || ($attr->{nameopts} ? _toname($o) : $o);
                my $slct = _ismember($o, @value) ? ' checked' : '';
                $tag .= _tag("input$slct", name => $field, value => $o, %{$attr}) 
                      . ' ' . $n . ' ';
                $tag .= '<br>' if $attr->{linebreaks};
            }
        } elsif ($attr->{type} eq 'textarea') {
            $attr->{onChange} = delete $attr->{jsclick} if $attr->{jsclick};
            my $text = join "\n", @value;
            $tag = _tag('textarea', name => $field, %{$attr}) . _escapehtml($text) . "</textarea>";

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

                # print the value out too when in a static context
                my $tagcom = _escapehtml($value);
                $tag .= $tagcom . ' ' if $attr->{type} eq 'hidden' && $static && $tagcom;
                $tag .= '<br>' if $attr->{linebreaks};
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
        my $error = $self->{fields}{$field}{invalid}
                        ? ($args{messages}{"form_invalid_$et"}
                           || $args{messages}{form_invalid_field})
                        : '';
        debug 2, "got error string = $error for form_invalid_$et";

        # if we have a template, then we setup the tag to a tmpl_var of the
        # same name via param(). otherwise, we generate HTML rows and stuff
        if (ref $args{template} eq 'HASH' && $args{template}{type} eq 'TT2') {
            # Template Toolkit can access complex data pretty much unaided
            $tmplvar{field}{$field} = {
                 %{ $self->{fields}{$field} },
                 field   => $tag,
                 values  => \@value,
                 options => \@opt,                   # added by nwiger
                 comment => $attr->{comment} || '',  # added by nwiger
                 error   => $error,                  # added by nwiger
                 label   => $label,
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

            # and finally any error
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
                    label => $n,
                    value => $o,
                    checked => $chk,
                    selected => $slct,
                };
            }

            # now assign our loop-field
            $tmplvar{"loop-$field"} = \@tmpl_loop;

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
                    my $js = ($args{submit} && $args{javascript})
                                ? qq( onClick="this.form._submit.value = this.value;")
                                : '';
                    $submit .= _tag("input$js", type => 'submit', name => '_submit',
                                value => $s);
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

    # hidden trailer. if you perceive this as annoying, let me know and I
    # may remove it. it's supposed to help.
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
                || puke "tt2 template not specified";
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

        } else {
            puke "Invalid template type '$tmpltype' specified - can be 'HTML' or 'TT2'";
        }

    } else {

        my $body = _tag('body', %{$args{body}});

        # assemble header HTML-compliantly
        $jsfunc = "<html><head><title>$args{title}</title>$jsfunc</head>"
                . "$body$font<h3>$args{title}</h3>\n" if $header;

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
    my $mailer = '';
    unless ($mailer = $args{mailer}) {
        for my $sendmail (qw(/usr/lib/sendmail /usr/sbin/sendmail /usr/bin/sendmail)) {
            if (-x $sendmail) {
                $mailer = "$sendmail -t";
                last;
            }
        }
    }
    unless ($mailer) {
        belch "Cannot find a sendmail-compatible mailer to use";
        return;
    }

    open(MAIL, "|$mailer") || next;
    print MAIL <<EOF;
From: $args{from}
To: $args{to}
Cc: $args{cc}
Subject: $args{subject}

$args{text}
EOF
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
    my $join  = $args{joiner} || $";

    # subject default
    $args{subject} ||= "$self->{opt}{title} Submission Results";

    my @form = ();
    for my $field ($self->fields) {
        my $v = join $join, $self->field($field);
        push @form, "$field$delim$v"; 
    }
    my $text = join "\n", @form;

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

    debug 1, "called validate(@_)";

    # Create our %valid hash which takes into account local args
    my %valid = (%{$self->{opt}{validate} || {}}, _args(@_));

    # Get %need from expansion of our 'required' param to new()
    my %need  = $self->_expreqd($self->{opt}{required}, \%valid);

    # Fail or success?
    my $bad = 0;

    for my $field (@{$self->{field_names}}) {

        # Get validation pattern if exists
        my $pattern = $valid{$field} || 'VALUE';

        # fatal error if they try to validate nonexistent field
        puke "Attempt to validate non-existent field '$field'"
            unless $self->{fields}{$field};

        # check for if $need{$field}; if not, next if blank
        if ($need{$field}) {
            debug 1, "$field: is required per 'required' param";
        } else {
            debug 1, "$field: is optional per 'required' param";
            next unless $self->field($field);
            debug 1, "$field: ...but is defined, so still checking";
        }

        # loop thru, and if something isn't valid, we tag it
        my $atleastone = 0;
        for my $value ($self->field($field)) {
            my $thisfail = 0;
            $atleastone++;

            # Check our hash to see if it's a special pattern
            ($pattern) = _data($VALID{$pattern}) if $VALID{$pattern};

            # pre-catch: hashref is a grouping per-language
            if (ref $pattern eq 'HASH') {
                $pattern = $pattern->{perl} || next;
            }

            debug 1, "$field: validating ($value) against pattern '$pattern'";

            if ($pattern =~ m#^m?(.).*\1$#) {
                # it be a regexp
                debug 1, "$field: does '$value' =~ $pattern ?";
                unless (eval qq('$value' =~ $pattern ? 1 : 0)) {
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
            } elsif ($pattern eq 'VALUE') {
                # Not null
                local $^W = 0;   # length() triggers uninit, too slow to catch
                debug 1, "$field: length '$value' > 0 ?";
                unless (length $value) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
            } else {
                # literal string is a literal comparison, but warn of typos...
                belch "Validation string '$pattern' may be a typo of a builtin pattern"
                    if ($pattern =~ /^[A-Z]+$/); 
                debug 1, "$field: '$value' $pattern ? 1 : 0";
                unless (eval qq('$value' $pattern ? 1 : 0)) {
                    $self->{fields}{$field}{invalid} = 1;
                    $thisfail = ++$bad;
                }
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

__END__

=head1 DESCRIPTION

=head2 Overview

I hate generating and processing forms. Hate it, hate it, hate it,
hate it. My forms almost always end up looking the same, and almost
always end up doing the same thing. Unfortunately, there really haven't
been any tools out there that streamline the process. Many modules
simply substitute Perl for HTML code:

    # The manual way
    print qq(<input name="email" type="text" size="20">);

    # The module way
    print input(-name => 'email', -type => 'text', -size => '20');

The problem is, that doesn't really gain you anything. You still
have just as much code. Modules like the venerable C<CGI.pm> are great
for processing parameters, but they don't save you much time when
trying to generate and process forms.

The goal of C<CGI::FormBuilder> (B<FormBuilder>) is to provide an easy way
for you to generate and process CGI form-based applications. This module
is designed to be smart in that it figures a lot of stuff out for you.
As a result, B<FormBuilder> gives you about a B<4:1> ratio of the code
it generates versus what you have to write.

For example, if you have multiple values for a field, it sticks them
in a radio, checkbox, or select group, depending on some factors. It
will also automatically name fields for you in human-readable labels
depending on the field names, and lay everything out in a nicely
formatted table. It will even title the form based on the name of
the script itself (C<order_form.cgi> becomes "Order Form").

Plus, B<FormBuilder> provides you full-blown validation for your
fields, including some useful builtin patterns. It will even generate
JavaScript validation routines on the fly! And, of course, it
maintains state ("stickiness") across submissions, with hooks
provided for you to plugin your own sessionid module such
as C<Apache::Session>.

And though it's smart, it allows you to customize it as well.  For
example, if you really want something to be a checkbox, you can make
it a checkbox. And, if you really want something to be output a
specific way, you can even specify the name of an C<HTML::Template> or
Template Toolkit (C<Template>) compatible template which will be
automatically filled in, statefully.

=head2 Walkthrough

Let's walk through a whole example to see how B<FormBuilder> works.
The basic usage is straightforward, and has these steps:

=over

=item 1.

Create a new C<CGI::FormBuilder> object with the proper options

=item 2.

Modify any fields that may need fiddling with

=item 3.

Validate the form, if applicable, and print it out

=back

B<FormBuilder> is designed to do the tedious grunt work for you.
In fact, a whole form-based application can be output with nothing
more than this:

    use CGI::FormBuilder;

    my @fields = qw(name email password confirm_password zipcode);

    my $form = CGI::FormBuilder->new(fields => \@fields);

    print $form->render(header => 1);

Not only does this generate about 4 times as much HTML-compliant code
as the above Perl code, but it also keeps values statefully across
submissions, even when multiple values are selected. And if you
do nothing more than add the C<validate> option to C<new()>:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields, 
                    validate => {email => 'EMAIL'}
               );

You now get a whole set of JavaScript validation code, as well
as Perl hooks for validation. In total you get about B<6 times>
the amount of code generated versus written. Plus, statefulness
and validation are handled for you, automatically.

Let's keep building on this example. Say we decide that we really
like our form fields and their stickiness, but we need to change
a couple things. For one, we want the page to be laid out very 
precisely. No problem! We simply create an C<HTML::Template> compatible
template and tell our module to use that. The C<HTML::Template>
module uses special HTML tags to print out variables. All you
have to do in your template is create one for each field that you're
printing, as well as one for the form header itself:

    <html>
    <head>
    <title><tmpl_var form-title></title>
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

Then, all you need to do in your Perl is add the C<template> option:

    my $form = CGI::FormBuilder->new(fields => \@fields, 
                                     validate => {email => 'EMAIL'},
                                     template => 'userinfo.tmpl');

And the rest of the code stays the same.

You can also do a similar thing using the Template Toolkit
(http://template-toolkit.org/) to generate the form.  This time,
specify the C<template> option as a hashref  which includes the
C<type> option set to C<TT2> and the C<template> option to denote
the name of the template you want processed.  You can also add
C<variable> as an option (among others) to denote the variable
name that you want the form data to be referenced by.

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
            [% form.submit %]
          </td>
        </tr>
      </table>
      [% form.end %]
    </body>
    </html>

So, as you can see, there is plugin capability for B<FormBuilder>
to basically "run" the two major templating engines, B<HTML::Template>
and B<Template Toolkit>.

Now, back to B<FormBuilder>. Let's assume that we want to validate our
form on the server side, which is common since the user may not be running
JavaScript.  All we have to add is the statement:

    $form->validate;

Which will go through the form, checking each value specified to
the validate option to see if it's ok. If there's a problem, then
that field is highlighted so that when you print it out the errors
will be apparent.

Of course, the above returns a truth value, which we should use
to see if the form was valid. That way, we can only fiddle our
database or whatever if everything looks good. We can then use
our C<confirm()> method to print out a generic results page:

    if ($form->validate) {
        # form was good, let's update database ...
        print $form->confirm;
    } else {
        print $form->render;
    }

The C<validate()> method will use whatever criteria were passed
into C<new()> via the C<validate> parameter to check the form
submission to make sure it's correct.

However, we really only want to do this after our form has been
submitted, since this could otherwise result in our form showing
errors even though the user hasn't gotten a chance to fill it
out yet. As such, we can check for whether the form has been
submitted yet by wrapping the above with:

    if ($form->submitted && $form->validate) {
        # form was good, let's update database ...
        print $form->confirm;
    } else {
        print $form->render;
    }

Of course, this module wouldn't be really smart if it didn't provide
some more stuff for you. A lot of times, we want to send a simple 
confirmation email to the user (and maybe ourselves) saying that
the form has been submitted. Just use C<mailconfirm()>:

    $form->mailconfirm(to   => $form->field('email'),
                       from => 'auto-reply');

With B<FormBuilder>, any default values you specify are automatically
overridden by whatever the user enters into the form and submits. 
These can then be gotten to by using the C<field()> method:

    my $email = $form->field(name => 'email');

Of course, like C<CGI.pm's param()> you can just specify the name
of the field when getting a value back:

    my $email = $form->field('email');

B<FormBuilder> is good at giving you the data that you should
be getting. That is, let's say that you initially setup your
C<$form> object to use a hash of existing values from a database
select or something. Then, you C<render()> the form, the user
fills it out, and submits it. When you call C<field()>, you'll
get whatever the correct value is, either the default or what
the user entered across the CGI.

So, our complete code thus far looks like this:

    use CGI::FormBuilder;

    my @fields = qw(name email password confirm_password zipcode);

    my $form = CGI::FormBuilder->new(
                    fields   => \@fields, 
                    validate => { email => 'EMAIL' },
                    template => 'userinfo.tmpl',
                    header   => 1
               );

    if ($form->submitted && $form->validate) {
        # form was ok, let's update database (you write this part)
        my $fields = $form->field;      # get all fields as hashref
        do_data_update($fields); 

        # show a confirmation message
        print $form->confirm;

        # and send them email about their submission
        $form->mailconfirm(to   => $form->field('email'),
                           from => 'auto-reply');
    } else {
        # print the form for them to fill out
        print $form->render;
    }

You may be surprised to learn that for many applications, the
above is probably all you'll need. Just fill in the parts that
affect what you want to do (like the database code), and you're
on your way.

=head1 REFERENCES

This really doesn't belong here, but unfortunately many people are
confused by references in Perl. Don't be - they're not that tricky.
When you take a reference, you're basically turning something into
a scalar value. Sort of. You have to do this if you want to pass
arrays intact into functions in Perl 5.

A reference is taken by preceding the variable with a backslash (\).
In our examples above, you saw something similar to this:

    my @fields = ('name', 'email');   # same as = qw(name email)

    my $form = CGI::FormBuilder->new(fields => \@fields);

Here, C<\@fields> is a reference. Specifically, it's an array
reference, or "arrayref" for short.

Similarly, we can do the same thing with hashes:

    my %validate = (
        name  => 'NAME';
        email => 'EMAIL',
    );

    my $form = CGI::FormBuilder->new( ... validate => \%validate);

Here, C<\%validate> is a hash reference, or "hashref".

Basically, if you don't understand references and are having trouble
wrapping your brain around them, you can try this simple rule: Any time
you're passing an array or hash into a function, you must precede it
with a backslash. Usually that's true for CPAN modules.

Finally, there are two more types of references: anonymous arrayrefs
and anonymous hashrefs. These are created with C<[]> and C<{}>,
respectively. So, for our purposes there is no real difference between
this code:

    my @fields = qw(name email);
    my %validate = (name => 'NAME', email => 'EMAIL');

    my $form = CGI::FormBuilder->new(
                    fields   => \@fields,
                    validate => \%validate
               );

And this code:

    my $form = CGI::FormBuilder->new(
                    fields   => [ qw(name email) ],
                    validate => { name => 'NAME', email => 'EMAIL' }
               );

Except that the latter doesn't require that we first create 
C<@fields> and C<%validate> variables.

Now back to our regularly-scheduled program...

=head1 FUNCTIONS

Of course, in the spirit of flexibility this module takes a bizillion
different options. None of these are mandatory - you can call the
C<new()> constructor without any fields, but your form will be really
really short. :-)

This documentation is very extensive, but can be a bit dizzying due
to the enormous number of options that let you tweak just about anything.
As such, I recommend that if this is your first time using this module,
you stop and visit:

    www.formbuilder.org

And click on "Tutorials" and "Examples". Then, use the following section
as a reference later on.

=head2 new()

This is the constructor, and must be called very first. It returns
a C<$form> object, which you can then modify and print out to create
the form. This function accepts all of the options listed under C<render()>
below. In addition, it takes 6 options that can only be specified to C<new()>:

=over

=item fields => \@array | \%hash

The C<fields> option takes an arrayref of fields to use in the form.
The fields will be printed out in the same order they are specified.
This option is needed if you expect your form to have any fields,
and is I<the> central option to FormBuilder.

You can also specify a hashref of key/value pairs. The advantage is
you can then bypass the C<values> option. However, the big disadvantage
is you cannot control the order of the fields. This is ok if you're
using a template, but in real-life it turns out that passing a hashref
to C<fields> is not very useful.

=item name => $string

This option can B<only> be specified to C<new()> but not to C<render()>.

This names the form. It is optional, but if you specify it you must
do so in C<new()> since the name is then used to alter how variables
are created and looked up.

This option has an important side effect. When used, it renames several
key variables and functions according to the name of the form. This
allows you to (a) use multiple forms in a sequential application and
(b) display multiple forms inline in one document. If you're trying
to build a complex multi-form app and are having problems, try naming
your forms.

=item params => $object

This specifies an object from which the parameters should be derived.
The object must have a C<param()> method which will return values
for each parameter by name. By default a CGI object will be 
automatically created and used.

However, you will want to specify this if you're using C<mod_perl>:

    use Apache::Request;
    use CGI::FormBuilder;

    sub handler {
        my $r = Apache::Request->new(shift);
        my $form = CGI::FormBuilder->new(... params => $r);
        # ...
        print $form->render;
    }

Or, if you need to initialize a C<CGI.pm> object separately and
are using a C<POST> form method:

    use CGI;
    use CGI::FormBuilder;

    my $q = new CGI;
    my $mode = $q->param('mode');
    # do stuff based on mode ...
    my $form = CGI::FormBuilder->new(... params => $q);

The above example would allow you to access CGI parameters
directly via C<< $q->param >> (however, note that you could
get the same functionality by using C<< $form->cgi_param >>).

=item validate => \%hash

This option takes a hashref of key/value pairs, where each key
is the name of a field from the C<fields> option, and each value
is one of several things:

    - a regular expression to match the field against
    - an arrayref of values of which the field must be one
    - a string that corresponds to one of the builtin patterns
    - a string containing a literal comparison to do

And each of these can also be grouped together as:

    - a hashref containing pairings of comparisons to do for
      the two different languages, "javascript" and "perl"

By default, the C<validate> option also sets up each field so that
it is required. However, if you specify the C<required> option, then
only those fields explicitly listed would be required, and the rest
would only be validated if filled in. See the C<required> option for
more details.

Let's look at a concrete example:

    my $form = CGI::FormBuilder->new(

                  fields => [qw/username password confirm_password
                                first_name last_name email/],

                  validate => { username   => [qw/nate jim bob/],
                                first_name => '/^\w+$/',    # note the 
                                last_name  => '/^\w+$/',    # single quotes!
                                email      => 'EMAIL',
                                password   => '/^\S{6,8}$/',
                                confirm_password => {
                                    javascript => '== form.password.value',
                                    perl       => 'eq $form->field("password")'
                                }
                              }
               );

This would create both JavaScript and Perl conditionals on the fly
that would ensure:

    - "username" was either "nate", "jim", or "bob"
    - "first_name" and "last_name" both match the regex's specified
    - "email" is a valid EMAIL format
    - "confirm_password" is equal to the "password" field

B<Any regular expressions you specify must be enclosed in single quotes
because they need to be used for both JavaScript and Perl code.> As
such, specifying a C<qr//> will not work.

Note that for both the C<javascript> and C<perl> hashref code options,
the form will be present as the variable named C<form>. For the Perl
code, you actually get a complete C<$form> object meaning that you
have full access to all its methods (although the C<field()> method
is probably the only one you'll need for validation). 

In addition to taking any regular expression you'd like, the
C<validate> option also has many builtin defaults that can
prove helpful:

    VALUE   -  is any type of non-null value
    WORD    -  is a word (\w+)
    NAME    -  matches [a-zA-Z] only
    FNAME   -  person's first name, like "Jim" or "Joe-Bob"
    LNAME   -  person's last name, like "Smith" or "King, Jr."
    NUM     -  number, decimal or integer
    INT     -  integer
    FLOAT   -  floating-point number
    PHONE   -  phone number in form "123-456-7890" or "(123) 456-7890"
    INTPHONE-  international phone number in form "+prefix local-number"
    EMAIL   -  email addr in form "name@host.domain"
    CARD    -  credit card, including Amex, with or without -'s
    DATE    -  date in format MM/DD/YYYY or DD/MM/YYYY
    MMYY    -  date in format MM/YY or MMYY
    MMYYYY  -  date in format MM/YYYY or MMYYYY
    CCMM    -  strict checking for valid credit card 2-digit month ([0-9]|1[012])
    CCYY    -  valid credit card 2-digit year
    ZIPCODE -  US postal code in format 12345 or 12345-6789
    STATE   -  valid two-letter state in all uppercase
    IPV4    -  valid IPv4 address
    NETMASK -  valid IPv4 netmask
    FILE    -  UNIX format filename (/usr/bin)
    WINFILE -  Windows format filename (C:\windows\system)
    MACFILE -  MacOS format filename (folder:subfolder:subfolder)
    HOST    -  valid hostname (some-name)
    DOMAIN  -  valid domainname (www.i-love-bacon.com)
    ETHER   -  valid ethernet address using either : or . as separators

I know some of the above are US-centric, but then again that's where I live. :-)
So if you need different processing just create your own regular expression
and pass it in. If there's something really useful let me know and maybe
I'll add it.

=item messages => $filename | \%hash

This option allows you to customize basically all the messages 
this module outputs. This is useful if you are writing a multilingual
application, or are just anal and want the messages exactly right.

The messaging system is simple, as it borrows somewhat from C<getttext()>.
Each message displayed is given a unique key. If you specify a custom
message for a given key, then that message is used. Otherwise, the
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

Then, your language file would contain the following:

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

This system is easy, are there are many many messages that can be 
customized. Here is a list of the fields that can be customized,
along with their default values.

    js_invalid_start        %s error(s) were encountered with your submission:
    js_invalid_end          Please correct these fields and try again.

    js_invalid_input        - You must enter a valid value for the "%s" field
    js_invalid_select       - You must choose an option for the "%s" field
    js_invalid_checkbox     - You must choose an option for the "%s" field
    js_invalid_radio        - You must choose an option for the "%s" field
    js_invalid_password     - You must enter a valid value for the "%s" field
    js_invalid_textarea     - You must fill in the "%s" field
    js_invalid_file         - You must specify a valid file for the "%s" field

    form_required_text      <p>Fields shown in <b>bold</b> are required.

    form_invalid_text       <p>%s error(s) were encountered with your submission.
                            Please correct the fields <font color="%s">
                            <b>highlighted</b></font> below.

    form_invalid_color      red

    form_confirm_text       Success! Your submission has been received %s.

    form_invalid_input      You must enter a valid value
    form_invalid_select     You must choose an option from this list
    form_invalid_checkbox   You must choose an option from this group
    form_invalid_radio      You must choose an option from this group
    form_invalid_password   You must enter a valid value
    form_invalid_textarea   You must fill in this field
    form_invalid_file       You must specify a valid filename

    form_select_default     -select-
    form_submit_default     Submit
    form_reset_default      Reset

The C<js_> tags are used in JavaScript alerts, whereas the C<form_> tags
are used in HTML and templates managed by FormBuilder.

In some of the messages, you will notice a C<%s> C<printf> format. This
is because these messages will include certain details for you. For example,
the C<js_invalid_start> tag will print the number of errors if you include
the C<%s> format tag. Of course, you this is optional, so if you leave it
out then you won't get the number of errors.

The best way to get an idea of how these work is to experiment a little.
It should become obvious really quickly.

=item debug => 0 | 1 | 2

If set to 1, the module spits copious debugging info to STDERR.
If set to 2, it spits out even more gunk.  Defaults to 0.

=back

=head2 render()

This function renders the form into HTML, and returns a string
containing the form. The most common use is simply:

    print $form->render;

However, C<render()> accepts B<the exact same options> as C<new()>
Why? Because this allows you to set certain options at different
points in your code, which is often useful. For example, you could
change the formatting based on whether C<layout> appeared in the
query string:

    my $form = CGI::FormBuilder->new(method => 'POST',
                                     fields => [qw/name email/]);

    # Get our layout from an extra CGI param
    my $layout = $form->cgi_param('layout');

    # If we're using a layout, then make sure to request a template
    if ($layout) {
        print $form->render(template => $layout);
    } else {
        print $form->render(header => 1);
    }

The following are all the options accepted by both C<new()> and
C<render()>:

=over

=item action => $script

What script to point the form to. Defaults to itself, which is
the recommended setting.

=item body => \%hash

This takes a hashref of attributes that will be stuck in the
C<< <body> >> tag verbatim (for example, bgcolor, alink, etc).
If you're thinking about using this, also check out the
C<template> option above (and below).

=item fieldtype => 'type'

This can be used to set the default type for all fields. For example,
if you're writing a survey application, you may want all of your
fields to be of type C<textarea> by default. Easy:

    my $form = CGI::FormBuilder->new(... fieldtype => 'textarea');

=item fieldattr => { opt => val, opt => val }

Even more flexible than C<fieldtype>, this option allows you to 
specify I<any> type of HTML attribute and have it be the default
for all fields. For example:

    my $form = CGI::FormBuilder->new(... fieldattr => { class => 'myClass' });

Would set the C<class> HTML attribute on all fields by default,
so that when they are printed out they will have a C<class="myClass">
part of their HTML tag. Maybe you want a template?

=item font => $font | \%fonttags

The font face to use for the form. This is output as a series of
C<< <font> >> tags for best browser compatibility, and will even
take care of the tedious table elements. I use this option all the
time. If you specify a hashref instead of just a font name, then
each key/value pair will be taken as part of the C<< <font> >> tag.
For example:

    font => {face => 'verdana', size => '-1', color => 'gray'}

Would generate the following tag:

    <font face="verdana" size="-1" color="gray">

And properly nest them in all of the table elements.

=item header => 0 | 1

If set to 1, a valid C<Content-type> header will be printed out,
along with a whole bunch of HTML C<< <body> >> code, a C<< <title> >>
tag, and so on. This defaults to 0, since usually people end up using
templates or embedding forms in other HTML. Setting it to 1 is a great
way to throw together a quick and dirty form, though.

=item javascript => 0 | 1

If set to 1, JavaScript is generated in addition to HTML, the
default setting.

=item jshead => JSCODE

If using JavaScript, you can also specify some JavaScript code
that will be included verbatim in the <head> section of the
document. I'm not very fond of this one, what you probably
want is the next option.

=item jsfunc => JSCODE

Just like C<jshead>, only this is stuff that will go into the
C<validate> JavaScript function. As such, you can use it to
add extra JavaScript validate code verbatim. If something fails,
you should do two things:

    - append to the JS variable "alertstr"
    - increment the JS variable "invalid"

For example:

    my $jsfunc = <<EOJS;
    if (form.password.value == 'password') {
        alertstr += "Moron, you can't use 'password' for your password!\\n";
        invalid++;
    }
    EOJS

    my $form = CGI::FormBuilder->new(... jsfunc => $jsfunc);

Then, this code will be automatically called when form validation
is invoked. I find this option can be incredibly useful. Most often,
I use it to bypass validation on certain submit modes. The submit
button that was clicked is C<form._submit.value>:

    my $jsfunc = <<EOJS;
    if (form._submit.value == 'Delete') {
        if (confirm("Really DELETE this entry?")) return true;
        return false;
    } else if (form._submit.value == 'Cancel') {
        // skip validation since we're cancelling
        return true;
    }
    EOJS

Important: When you're quoting, remember that Perl will expand "\n"
itself. So, if you want a literal newline, you must double-escape
it, as shown above.

=item keepextras => 0 | 1 | \@array

If set to 1, then extra parameters not set in your fields declaration
will be kept as hidden fields in the form. However, you will need
to use C<cgi_param()>, not C<field()>, to get to the values. This is
useful if you want to keep some extra parameters like referer or
company available but not have them be valid form fields. See below
under C</"param"> for more details.

You can also specify an arrayref, in which case only params found on
that list will be preserved. For example, saying:

    ->new(keepextras => 1, ...);

Will preserve all non-field parameters, whereas saying:

    ->new(keepextras => [qw/mode company/], ...);

Will only preserve the params C<mode> and C<company>.

=item labels => \%hash

Like C<values>, this is a list of key/value pairs where the keys
are the names of C<fields> specified above. By default, B<FormBuilder>
does some snazzy case and character conversion to create pretty labels
for you. However, if you want to explicitly name your fields, use this
option.

For example:

    my $form = CGI::FormBuilder->new(
                    fields => [qw/name email/],
                    labels => {
                        name  => 'Your Full Name',
                        email => 'Primary Email Address'
                    }
               );

Usually you'll find that if you're contemplating this option what
you really want is a template.

=item lalign => 'left' | 'right' | 'center'

This is how to align the field labels in the table layout. I really
don't like this option being here, but it does turn out to be
pretty damn useful. You should probably be using a template.

=item linebreaks => 0 | 1

If set to 1, line breaks will be inserted after each input field.
By default this is figured out for you, so usually not needed.

=item method => 'POST' | 'GET'

Either C<POST> or C<GET>, the type of CGI method to use. Defaults
to C<GET> if nothing is specified.

=item options => \%hash

By using this argument, you can avoid having to specify the options
for different fields individually:

    my $form = CGI::FormBuilder->new(
                    fields => [qw/part_number department in_stock/],
                    options => {
                        department => [qw/hardware software/],
                        in_stock   => [qw/yes no/],
                    }
               );

This will then create the appropriate multi-option HTML inputs (in
this case, radio groups) automatically.

=item required => \@array | 'ALL' | 'NONE'

This is a list of those values that are required to be filled in.
Those fields named must be included by the user. If the C<required>
option is not specified, by default any fields named in C<validate>
will be required.

As of v1.97, the C<required> option now takes two other settings,
the string C<ALL> and the string C<NONE>. If you specify C<ALL>,
then all fields are required. If you specify C<NONE>, then none
of them are I<in spite of what may be set via the "validate" option>.

This is useful if you have fields that you need to be validated if
filled in, but which are optional. For example:

    my $form = CGI::FormBuilder->new(
                    fields => qw[/name email/],
                    validate => { email => 'EMAIL' },
                    required => 'NONE'
               );

This would make the C<email> field optional, but if filled in then
it would have to match the C<EMAIL> pattern.

In addition, it is I<very> important to note that if the C<required>
I<and> C<validate> options are specified, then they are taken as an
intersection. That is, only those fields specified as C<required>
must be filled in, and the rest are optional. For example:

    my $form = CGI::FormBuilder->new(
                    fields => qw[/name email/],
                    validate => { email => 'EMAIL' },
                    required => [qw/name/]
               );

This would make the C<name> field mandatory, but the C<email> field
optional. However, if C<email> is filled in, then it must match the
builtin C<EMAIL> pattern.

=item reset => 0 | $string

If set to 0, then the "Reset" button is not printed. If set to 
text, then that will be printed out as the reset button. Defaults
to printing out a button that says "Reset".

=item selectnum => $threshold

These affect the "intelligence" of the module. If a given field
has any options, then it will be a radio group by default. However,
if more than C<selectnum> options are present, then it will become
a select list. The default is 5 or more options. For example:

    # This will be a radio group
    my @opt = qw(Yes No);
    $form->field(name => 'answer', options => \@opt);

    # However, this will be a select list
    my @states = qw(AK CA FL NY TX);
    $form->field(name => 'state', options => \@states);

    # This is the one special case - single items are checkboxes
    $form->field(name => 'answer', options => ['Yes']);

There is no threshold for checkboxes since these are basically
a type of multiple radio select group. As such, a radio group
becomes a checkbox group if there are multiple values (not
options, but actual values) for a given field, or if you 
specify C<< multiple => 1 >> to the C<field()> method. Got it?

=item smartness => 0 | 1 | 2

By default CGI::FormBuilder tries to be pretty smart for you, like
figuring out the types of fields based on their names and number
of options. If you don't want this behavior at all, set C<smartness>
to C<0>. If you want it to be B<really> smart, like figuring
out what type of validation routines to use for you, set it to
C<2>. It defaults to C<1>.

=item sortopts => alpha | numeric | NAME | NUM | 1

If specified to C<render()> or C<new()>, this has the same effect
as the same-named option to C<field()>, only it applies to all fields.

=item static => 0 | 1

If set to 1, then the form will be output with static hidden
fields. Defaults to 0.

=item sticky => 0 | 1

Determines whether or not form values should be sticky across
submissions. This does I<not> affect the value you get back from
a call to C<field()>. It also does not affect default values. It
only affects values the user may have entered via the CGI.

This defaults to 1, meaning values are sticky. However, you may
want to set it to 0 if you have a form which does something like
adding parts to a database. See the L</"EXAMPLES"> section for 
a good example.

=item submit => 0 | $string | \@array

If set to 0, then the "Submit" button is not printed. It defaults
to creating a button that says "Submit" verbatim. If given an
argument, then that argument becomes the text to show. For example:

    print $form->render(submit => 'Do Lookup');

Would make it so the submit button says "Do Lookup" on it. 

If you pass an arrayref of multiple values, you get a key benefit.
This will create multiple submit buttons, each with a different value.
In addition, though, when submitted only the one that was clicked
will be sent across CGI via some JavaScript tricks. So this:

    print $form->render(submit => ['Add A Gift', 'No Thank You']);

Would create two submit buttons. Clicking on either would submit the
form, but you would be able to see which one was submitted via the
C<submitted()> function:

    my $clicked = $form->submitted;

So if the user clicked "Add A Gift" then that is what would end up
in the variable C<$clicked> above. This allows nice conditionality:

    if ($form->submitted eq 'Add A Gift') {
        # show the gift selection screen
    } elsif ($form->submitted eq 'No Thank You')
        # just process the form
    }

See the L</"EXAMPLES"> section for more details.

=item table => 0 | 1 | \%tabletags

By default B<FormBuilder> decides how to layout the form based on
the number of fields, values, etc. You can force it into a table
by specifying C<1>, or force it out of one with C<0>.

If you specify a hashref instead, then these will be used to 
create the C<< <table> >> tag. For example, to create a table
with no cellpadding or cellspacing, use:

    table => {cellpadding => 0, cellspacing => 0}

=item template => $filename | \%hash

This points to a filename that contains an C<HTML::Template>
compatible template to use to layout the HTML. You can also specify
the C<template> option as a reference to a hash, allowing you to
further customize the template processing options.

For example, you could turn on caching in C<HTML::Template> with
something like the following:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        filename => 'form.tmpl',
                        shared_cache => 1
                    }
               );

In addition, specifying a hashref allows you to use an alternate template
processing system like the C<Template Toolkit>.  A minimal configuration
would look like this:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        type => 'TT2',      # use Template Toolkit
                        template => 'form.tmpl',
                    },
               );

The C<type> option specifies the name of the processor.  Use C<TT2> to
invoke the Template Toolkit or C<HTML> (the default) to invoke
C<HTML::Template> as shown above. All other options besides C<type>
are passed to the constructor for that templating system verbatim,
so you'll need to consult those docs to see what different options do.

For lots more information on templates, see the L</"TEMPLATES"> section
below.

=item text => $text

This is text that is included below the title but above the
actual form. Useful if you want to say something simple like
"Contact $adm for more help", but if you want lots of text
check out the C<template> option above.

=item title => $title

This takes a string to use as the title of the form. 

=item valign => 'top' | 'middle' | 'bottom'

Another one I don't like, this alters how form fields are laid out in
the natively-generated table. Default is "middle".

=item values => \%hash | \@array

The C<values> option takes a hashref of key/value pairs specifying
the default values for the fields. These values will be overridden
by the values entered by the user across the CGI. The values are
used case-insensitively, making it easier to use DBI hashref records
(which are in upper or lower case depending on your database).

This option is useful for selecting a record from a database or
hardwiring some sensible defaults, and then including them in the
form so that the user can change them if they wish. For example:

    my $rec = $sth->fetchrow_hashref;
    my $form = CGI::FormBuilder->new(fields => \@fields,
                                     values => $rec);

You can also pass an arrayref, in which case each value is used
sequentially for each field as specified to the C<fields> option.
While C<new()> is used as an example, this can of course be
used in C<render()> as well.

=back

Note that any other options specified are passed to the C<< <form> >>
tag verbatim. For example, you could specify C<onSubmit> or C<enctype>
to add the respective attributes.

=head2 field()

This method is called on the C<$form> object you get from the C<new()>
method above, and is used to manipulate individual fields. You can use
this if you want to specify something is a certain type of input, or
has a certain set of options.

For example, let's say that you create a new form:

    my $form = CGI::FormBuilder->new(fields => [qw/name state zip/]);

And that you want to make the "state" field a select list of all
the states. You would just say:

    $form->field(name => 'state', type => 'select',
                 options => \@states);

Then, when you used C<render()> to create the form output, the "state"
field would appear as a select list with the values in C<@states>
as options.

If just given the name of the field, then the value of that field will
be returned, just like C<CGI.pm>:

    my $email = $form->field('email');

Why is this not named C<param()>? Simple: Because it's not compatible.
Namely, while the return context behavior is the same, this function
is not responsible for retrieving all CGI parameters - only those
defined as valid form fields. This is important, as it allows your
script to accept only those field names you've defined for security.

To get the list of valid field names just call it without and args:

    my @fields = $form->field;

And to get a hashref of field/value pairs, call it as:

    my $fields = $form->field;
    my $name = $fields->{name};

Note that if you call it as a hashref, you will only get one single
value per field. This is just fine as long as you don't have
multiple values per field (the normal case). However, if you have
a query string like this:

    favorite_colors.cgi?color=red&color=white&color=blue

Then you will only get one value for C<color> in the hashref. In
this case you'll need to access it via C<field()> to get them all:

    my @colors = $form->field('color');

The C<field()> function takes several parameters, the first of
which is mandatory. The rest are listed in alphabetical order:

Finally, you can also take advantage of a new feature and address
fields directly by name. This means instead of:

    my $address = $form->field('address');

You can say:

    my $address = $form->address;

This works for setting properties as well:

    $form->field(name => 'user_id', size => '8', maxlength => '12');
    $form->user_id(size => '8', maxlength => '12');

Both of those would do the exact same thing. You will get a fatal
error if you try to address an invalid field.

=over

=item name => $name

The name of the field to manipulate. The "name =>" part is optional
if there's only one argument. For example:

    my $email = $form->field(name => 'email');
    my $email = $form->field('email');  # same thing

However, if you're specifying more than one argument then you must
include the C<name> part:

    $form->field(name => 'email', size => '40');

=item comment => $string

This prints out the given comment I<after> the field to fill
in, vebatim. For example, if you wanted a field to look like
this:

    Joke [____________] (keep it clean, please!)

You would use the following:

    $form->field(name => 'joke', comment => '(keep it clean, please!)');

The C<comment> can actually be anything you want (even another
form field). But don't tell anyone I said that.

=item force => 0 | 1

This is used in conjunction with the C<value> option to forcibly
override a field's value. See below under the C<value> option for
more details. For compatibility with C<CGI.pm>, you can also call
this option C<override> instead, but don't tell anyone.

=item jsclick => $jscode

This is a simple abstraction over directly specifying the JavaScript
action type. This turns out to be extremely useful, since if an
option list changes from C<select> to C<radio> or C<checkbox> (depending
on the number of options), then the action changes from C<onChange>
to C<onClick>. Why?!?!

So if you said:

    $form->field(name => 'credit_card', jsclick => 'recalc_total();',
                 options => \@cards)

This would generate the following code, depending on the number
of C<@cards>:

    <select name="credit_card" onChange="recalc_total();"> ...

    <radio name="credit_card" onClick="recalc_total();"> ...

You get the idea.

=item label => $string

This will be the label printed out next to the field. By default
it will be generated automatically from the field name.

=item labels => \%hash

This takes a hashref of key/value pairs where each key is one of
the options, and each value is what its printed label should be.
For example:

    $form->field(name => 'state', options => [qw/AZ CA NV OR WA/],
                 labels => {
                     AZ => 'Arizona',
                     CA => 'California',
                     NV => 'Nevada',
                     OR => 'Oregon',
                     WA => 'Washington
                 });

When rendered, this would create a select list where the option
values were "CA", "NV", etc, but where the state's full name
was displayed for the user to select.

You can also get the same effect by passing complex data
structures directly to the C<options> argument (see below).
If you have predictable data, check out the C<nameopts> option.

=item linebreaks => 0 | 1

Similar to the top-level "linebreaks" option, this one will put
breaks in between options, to space things out more. This is
useful with radio and checkboxes especially.

=item multiple => 0 | 1

If set to 1, then the user is allowed to choose multiple
values from the options provided. This turns radio groups
into checkboxes and selects into multi-selects. Defaults
to automatically being figured out based on number of values.

=item nameopts => 0 | 1

If set to 1, then options for select lists will be automatically
named just like the fields. So, if you specified a list like:

    $form->field(name => 'department', 
                 options => qw[/molecular_biology philosophy psychology
                                particle_physics social_anthropology/],
                 nameopts => 1);

This would create a list like:

    <select name="department">
    <option value="molecular_biology">Molecular Biology</option>
    <option value="philosophy">Philosophy</option>
    <option value="psychology">Psychology</option>
    <option value="particle_physics">Particle Physics</option>
    <option value="social_anthropology">Social Anthropology</option>
    </select>

Basically, you get names for the options that are determined in 
the same way as the names for the fields. This is designed as
a simpler alternative to using custom C<options> data structures
if your data is regular enough to support it.

=item options => \@options | \%options | 'BUILTIN'

This takes an arrayref of options. It also automatically results
in the field becoming a radio (if <= 4) or select list (if > 4),
unless you explicitly set the type with the C<type> parameter.

Each item will become both the value and the text label by default.
That is, if you specified these options:

    $form->field(name => 'opinion', options => [qw/yes no maybe so/]);

You will get something like this:

    <select name="opinion">
    <option value="yes">yes</option>
    <option value="no">no</option>
    <option value="maybe">maybe</option>
    <option value="so">so</option>
    </select>

However, if a given item is either an arrayref or hashref, then
the first element will be taken as the value and the second as the
label. So something like this:

    push @opt, ['yes', 'You betcha!'];
    push @opt, ['no', 'No way Jose'];
    push @opt, ['maybe', 'Perchance...'];
    push @opt, ['so', 'So'];
    $form->field(name => 'opinion', options => \@opt);

Would result in something like the following:

    <select name="opinion">
    <option value="yes">You betcha!</option>
    <option value="no">No way Jose</option>
    <option value="maybe">Perchance...</option>
    <option value="so">So</option>
    </select>

And this code would have the same effect:

    push @opt, { yes => 'You betcha!' };
    push @opt, { no  => 'No way Jose' };
    push @opt, { maybe => 'Perchance...' };
    push @opt, { so  => 'So' };
    $form->field(name => 'opinion', options => \@opt);

As would, in fact, this code:

    my %opt = (
        yes => 'You betcha!',
        no  => 'No way Jose',
        maybe => 'Perchance...',
        so  => 'So'
    );
    $form->field(name => 'opinion', options => \%opt);

You get the idea. The goal is to give you as much flexibility
as possible when constructing your data structures, and this
module figures it out correctly. The only disadvantage to the
very last method is that since the top-level structure is a
hash, you cannot control the order of the options.

If you're just looking for simple naming, see the C<nameopts>
option above.

Finally, currently a single builtin options set is included:
C<STATE>, which contains all 50 states + DC as 2-letter codes.

=item override => 0 | 1

A synonym for the C<force> option described above.

=item required => 0 | 1

If set to 1, the field must be filled in:

    $form->field(name => 'email', required => 1);

This is rarely useful - what you probably want is the C<validate>
option to C<new()>.

=item sortopts => alpha | numeric | NAME | NUM | 1

If set, and there are options, then the options will be sorted 
in the specified order. For example:

    $form->field(name => 'category', options => \@cats,
                 sortopts => 'alpha');

Would sort the C<@cats> options in alpha order.

The terms "NAME" and "NUM" have been introduced to keep consistency
with the C<validate> options. They are synonymous with "alpha" and
"numeric", respectively. If you specify "1", then an alpha sort is
done, again for simplicity.

=item type => $type

Type of input box to make it. Default is "text", and valid values
include anything allowed by the HTML specs, including "password",
"select", "radio", "checkbox", "textarea", "hidden", and so on.

If set to "static", then the field will be printed out, but will
not be editable. Like when you print out a complete static form,
the field's value will be placed in a hidden field as well.

=item value => $value | \@values

The C<value> option can take either a single value or an arrayref
of multiple values. In the case of multiple values, this will
result in the field automatically becoming a multiple select list
or checkbox group, depending on the number of options specified
above.

Just like the 'values' to C<new()>, this can be overridden by
CGI values. To forcibly change a value, you need to specify the
C<force> option described above, for example:

    $form->field(name => 'credit_card', value => 'not shown',
                 force => 1);

This would make the C<credit_card> field into "not shown",
useful for hiding stuff if you're going to use C<mailresults()>.

=item validate => '/regex/'

Similar to the C<validate> option used in C<new()>, this affects
the validation just of that single field. As such, rather than
a hashref, you would just specify the regex to match against.

B<This regex must be specified as a single-quoted string, and
NOT as a qr() regex>. The reason is that this needs to be
easily usable by JavaScript routines as well.

=item [htmlattr] => $value, [htmlattr] => $value

In addition to the above tags, the C<field()> function can take
any other valid HTML attribute, which will be placed in the tag
verbatim. For example, if you wanted to alter the class of the
field (if you're using stylesheets and a template, for example),
you could say:

    $form->field(name => 'email', class => 'FormField',
                 size => 80);

Then when you call C<$form->render> you would get a field something
like this:

    <input type="text" name="email" class="FormField" size="80">

(Of course, for this to really work you still have to create a class
called C<FormField> in your stylesheet.)

See also the C<fieldattr> option which can be passed to either
C<new()> or C<render()> and which provides global defaults
for all fields.

=back

=head2 cgi_param()

Wait a second, if we have C<field()> from above, why the heck
would we ever need C<cgi_param()>?

Simple. The above C<field()> function does a bunch of special
stuff. For one thing, it will only return fields which you have
explicitly defined in your form. Excess parameters will be
silently ignored. Also, it will incorporate defaults you give
it, meaning you may get a value back even though the user didn't
enter one explicitly in the form (see above).

But, you may have some times when you want extra stuff so that
you can maintain state, but you don't want it to appear in your
form. B2B and branding are easy examples:

    http://hr-outsourcing.com/newuser.cgi?company=mr_propane

This could change stuff in your form so that it showed the logo
and company name for the appropriate vendor, without polluting
your form parameters.

This call simply redispatches to C<CGI::Minimal> (if installed)
or C<CGI.pm>'s C<param()> methods, so consult those docs for 
more information.

=head2 tmpl_param()

This allows you to interface with your C<HTML::Template> template,
if you are using one. As with C<cgi_param()> above, this is only
useful if you're manually setting non-field values. B<FormBuilder>
will automatically setup your field parameters for you; see the
L</"template"> option for more details.

=head2 confirm()

The purpose of this function is to print out a static confirmation
screen showing a short message along with the values that were
submitted. It is actually just a special wrapper around C<render()>,
twiddling a couple options.

If you're using templates, you probably want to specify a separate
success template, such as:

    print $form->confirm(template => 'success.tmpl');

So that you don't get the same screen twice.

=head2 submitted()

This returns the value of the "Submit" button if the form has been
submitted, undef otherwise. This allows you to either test it in
a boolean context:

    if ($form->submitted) { ... }

Or to retrieve the button that was actually clicked on in the
case of multiple submit buttons:

    if ($form->submitted eq 'Update') {
        ...
    } elsif ($form->submitted eq 'Delete') {
        ...
    }

It's best to call C<validate()> in conjunction with this to make
sure the form validation works. To make sure you're getting accurate
info, it's recommended that you name your forms with the C<name>
option described above.

If you're writing a multiple-form app, you should name your forms
with the C<name> option to ensure that you are getting an accurate
return value from this sub. See the C<name> option above, under
C<render()>.

You can also specify the name of an optional field which you want to
"watch" instead of the default C<_submitted> hidden field. This is useful
if you have a search form and also want to be able to link to it from
other documents directly, such as:

    mysearch.cgi?lookup=what+to+look+for

Normally, C<submitted()> would return false since the C<_submitted>
field is not included. However, you can override this by saying:

    $form->submitted('lookup');

Then, if the lookup field is present, you'll get a true value.
(Actually, you'll still get the value of the "Submit" button if
present.)

=head2 validate()

This validates the form based on the validation criteria passed
into C<new()> via the C<validate> option. In addition, you can
specify additional criteria to check that will be valid for just
that call of C<validate()>. This is useful is you have to deal
with different geos:

    if ($location eq 'US') {
        $form->validate(state => 'STATE', zipcode => 'ZIPCODE');
    } else {
        $form->validate(state => '/^\w{2,3}$/');
    }

Note that if you pass args to your C<validate()> function like
this, you will not get JavaScript generated or required fields
placed in bold. So, this is good for conditional validation
like the above example, but for most applications you want to
pass your validation requirements in via the C<validate>
option to the C<new()> function, and just call the C<validate()>
function with no arguments.

=head2 sessionid()

This gets and sets the sessionid, which is stored in the special
form field C<_sessionid>. By default no session ids are generated
or used. Rather, this is intended to provide a hook for you to 
easily integrate this with a session id module like C<Apache::Session>.

Since you can set the session id via the C<_sessionid> field, you
can pass it as an argument when first showing the form:

    http://mydomain.com/forms/update_info.cgi?_sessionid=0123-091231

This would set things up so that if you called:

    my $id = $form->sessionid;

This would get the value C<0123-091231> in your script. Conversely,
if you generate a new sessionid on your own, and wish to include it
automatically, simply set is as follows:

    $form->sessionid($id);

This will cause it to be automatically carried through subsequent
forms.

=head2 mailconfirm()

This sends a confirmation email to the named addresses. The C<to>
argument is required; everything else is optional. If no C<from>
is specified then it will be set to the address C<auto-reply>
since that is a common quasi-standard in the web app world.

This does not send any of the form results. Rather, it simply
prints out a message saying the submission was received.

=head2 mailresults()

This emails the form results to the specified address(es). By 
default it prints out the form results separated by a colon, such as:

    name: Nathan Wiger
    email: nate@wiger.org
    colors: red green blue

And so on. You can change this by specifying the C<delimiter> and
C<joiner> options. For example this:

    $form->mailresults(to => $to, delimiter => '=', joiner => ',');

Would produce an email like this:

    name=Nathan Wiger
    email=nate@wiger.org
    colors=red,green,blue

Note that now the last field ("colors") is separated by commas since
you have multiple values and you specified a comma as your C<joiner>.

=head2 mail()

This is a more generic version of the above; it sends whatever is
given as the C<text> argument via email verbatim to the C<to> address.
In addition, if you're not running C<sendmail> you can specify the
C<mailer> parameter to give the path of your mailer. This option
is accepted by the above functions as well.

=head1 TEMPLATES

B<FormBuilder> has the ability to "drive" both C<HTML::Template> 
and C<Template Toolkit>. You enable a template by specifying the
C<template> option and passing it the appropriate information.
Then, you must place special tags in your template which will
be expanded for you. Let's look at each template solution in turn.

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
    <tmpl_var form-start>  -  Opening <form> tag w/ options
    <tmpl_var form-submit> -  The submit button(s)
    <tmpl_var form-reset>  -  The reset button
    <tmpl_var form-end>    -  Just the closing </form> tag

So, let's revisit our C<userinfo.tmpl> template from above:

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

    $form->field(name => 'color', nameopts => 1,
                 options => [qw/red green blue yellow black white gray/]);

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

    $form->field(name => 'mailopt', options => [qw/1 0/],
                 labels => {
                    1 => 'Yes, please keep me on it!',
                    0 => 'No, remove me immediately.'
                 });

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

For more information on templates, see L<HTML::Template>.        

=head2 Template Toolkit

Thanks to a huge patch from Andy Wardley, B<FormBuilder> also supports
C<Template Toolkit>. This is enabled by specifying the following
options as a hashref to the C<template> argument:

    my $form = CGI::FormBuilder->new(
                    fields => \@fields,
                    template => {
                        type => 'TT2',      # use Template Toolkit
                        template => 'form.tmpl'
                    }
               );

By default, the Template Toolkit makes all the form and field 
information accessible through simple variables.

    [% jshead %]  -  JavaScript to stick in <head>
    [% title  %]  -  The <title> of the HTML form
    [% start  %]  -  Opening <form> tag w/ options
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

=head1 EXAMPLES

I find this module incredibly useful, so here are even more examples,
pasted from sample code that I've written:

=head2 Ex1: order.cgi

This example provides an order form complete with validation of the
important fields. 

    #!/usr/bin/perl -w

    use strict;
    use CGI::FormBuilder;

    my @states = qw(AL AK AZ AR CA CO CT DE DC FL GE HI ID IL IN IA KS
                    KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC
                    ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY);

    my $form = CGI::FormBuilder->new(
                    header => 1, method => 'POST', title => 'Order Info',
                    fields => [qw/first_name last_name email address
                                  state zipcode credit_card/],
                    validate => {email => 'EMAIL', zipcode => 'ZIPCODE',
                                 credit_card => 'CARD'}
               );

    $form->field(name => 'state', options => \@states, sort => 'alpha');

    # This adds on the 'details' field to our form dynamically
    $form->field(name => 'details', cols => '50', rows => '10');

    # try to validate it first
    if ($form->submitted && $form->validate) {
        # ... more code goes here to do stuff ...
        print $form->confirm;
    } else {
        print $form->render;
    }

This will create a form called "Order Info" that will provide a pulldown
menu for the "state", a textarea for the "details", and normal text
boxes for the rest. It will then validate the fields specified to the
C<validate> option appropriately.

=head2 Ex2: order_form.cgi

This is very similar to the above, only it uses the C<smartness> option
to fill in the "state" options automatically, as well as guess at the
validation types we want. I recommend you use the C<debug> option to
see what's going on until you're sure it's doing what you want.

    #!/usr/bin/perl -w

    use strict;
    use CGI::FormBuilder;

    my $form = CGI::FormBuilder->new(
                    header => 1, method => 'POST',
                    smartness => 2, debug => 2,
                    fields => [qw/first_name last_name email address
                                  state zipcode credit_card/],
               );

    # This adds on the 'details' field to our form dynamically
    $form->field(name => 'details', cols => '50', rows => '10');

    # try to validate it first
    if ($form->submitted && $form->validate) {
        # ... more code goes here to do stuff ...
        print $form->confirm;
    } else {
        print $form->render;
    }

Since we didn't specify the C<title> option, it will be automatically
determined from the name of the executable. In this case it will be
"Order Form".

=head2 Ex3: ticket_search.cgi

This is a simple search script that uses a template to layout 
the search parameters very precisely. Note that we set our
options for our different fields and types.

    #!/usr/bin/perl -w

    use strict;
    use CGI::FormBuilder;

    my $form = CGI::FormBuilder->new(
                    header => 1, template => 'ticket_search.tmpl',
                    fields => [qw/type string status category/]
               );

    # Need to setup some specific field options
    $form->field(name => 'type',
                 options => [qw/ticket requestor hostname sysadmin/]);

    $form->field(name => 'status', type => 'radio', value => 'incomplete',
                 options => [qw/incomplete recently_completed all/]);

    $form->field(name => 'category', type => 'checkbox',
                 options => [qw/server network desktop printer/]);

    # Render the form and print it out so our submit button says "Search"
    print $form->render(submit => ' Search ');

Then, in our C<ticket_search.tmpl> HTML file, we would have something like this:

    <html>
    <head>
      <title>Search Engine</title>
      <tmpl_var js-head>
    </head>
    <body bgcolor="white">
    <center>
    <p>
    Please enter a term to search the ticket database. Make sure
    to "quote phrases".
    <p>
    <tmpl_var form-start>
    Search by <tmpl_var field-type> for <tmpl_var field-string>
    <tmpl_var form-submit>
    <p>
    Status: <tmpl_var field-status>
    <p>
    Category: <tmpl_var field-category>
    <p>
    </form>
    </body>
    </html>

That's all you need for a sticky search form with the above HTML layout.
Notice that you can change the HTML layout as much as you want without
having to touch your CGI code.

=head2 Ex4: user_info.cgi

This script grabs the user's information out of a database and lets
them update it dynamically. The DBI information is provided as an
example, your mileage may vary:

    #!/usr/bin/perl -w

    use strict;
    use CGI::FormBuilder;
    use DBI;
    use DBD::Oracle

    my $dbh = DBI->connect('dbi:Oracle:db', 'user', 'pass');

    # We create a new form. Note we've specified very little,
    # since we're getting all our values from our database.
    my $form = CGI::FormBuilder->new(
                    fields => [qw/username password confirm_password
                                  first_name last_name email/]
               );

    # Now get the value of the username from our app
    my $user = $form->cgi_param('user');
    my $sth = $dbh->prepare("select * from user_info where user = '$user'");
    $sth->execute;
    my $default_hashref = $sth->fetchrow_hashref;

    # Render our form with the defaults we got in our hashref
    print $form->render(values => $default_hashref,
                        title  => "User information for '$user'",
                        header => 1);

=head2 Ex5: add_part.cgi

This presents a screen for users to add parts to an inventory database.
Notice how it makes use of the C<sticky> option. If there's an error,
then the form is presented with sticky values so that the user can
correct them and resubmit. If the submission is ok, though, then the
form is presented without sticky values so that the user can enter
the next part.

    #!/usr/bin/perl -w

    use strict;
    use CGI::FormBuilder;

    my $form = CGI::FormBuilder->new(
                    method => 'POST',
                    fields => [qw/sn pn model qty comments/],
                    labels => { sn => 'Serial Number',
                                pn => 'Part Number' },
                    sticky => 0,
                    header => 1,
                    required => [qw/sn pn model qty/],
                    validate => { sn  => '/^\d{3}-\d{4}-\d{4}$/',
                                  pn  => '/^\d{3}-\d{4}$/',
                                  qty => 'INT' },
                    font => 'arial,helvetica'
               );

    # shrink the qty field for prettiness, lengthen model
    $form->field(name => 'qty', size => 4);
    $form->field(name => 'model', size => 60);

    if ($form->submitted) {
        if ($form->validate) {
            # Add part to database
        } else {
            # Invalid; show form and allow corrections
            print $form->render(sticky => 1);
            exit;
        }
    }

    # Print form for next part addition.
    print $form->render;

With the exception of the database code, that's the whole application.

=head1 FREQUENTLY ASKED QUESTIONS (FAQ)

There are a couple questions and subtle traps that seem to poke people
on a regular basis. Here are some hints.

=over

=head2 I'm confused. Why doesn't field() work like CGI's param()?

If you're used to C<CGI.pm>, you have to do a little bit of a brain
shift when working with this module.

First, this module is designed to address fields as I<abstract
entities>. That is, you don't create a "checkbox" or "radio group"
per se. Instead, you create a field named for the data you want
to collect. B<FormBuilder> takes care of figuring out what the
most optimal HTML representation is for you.

So, if you want a single-option checkbox, simply say something
like this:

    $form->field(name => 'join_mailing_list', options => ['Yes']);

If you want it to be checked by default, you add the C<value> arg:

    $form->field(name  => 'join_mailing_list', options => ['Yes'],
                 value => 'Yes');

You see, you're creating a field that has one possible option: "Yes".
Then, you're saying its current value is, in fact, "Yes". This will
result in B<FormBuilder> creating a single-option field (which is
a checkbox by default) and selecting the requested value (meaning
that the box will be checked).

If you want multiple values, then all you have to do is specify
multiple options:

    $form->field(name  => 'join_mailing_list', options => [qw/Yes No/],
                 value => 'Yes');

Now you'll get a radio group, and "Yes" will be selected for you!
By viewing fields as data entities (instead of HTML tags) you
get much more flexibility and less code maintenance. If you want
to be able to accept multiple values, simply add the C<multiple> arg:

    $form->field(name    => 'favorite_colors', multiple => 1,
                 options => [qw/red green blue]);

Depending on the number of C<options> you have, you'll get either
a set of checkboxes or a multiple select list (unless you manually
override this with the C<type> arg). Regardless, though, to get the
data back all you have to say is:

    my @colors = $form->field('favorite_colors');

And the rest is taken care of for you.

=head2 How do I make a multi-screen/multi-mode form?

This is easily doable, but you have to remember a couple things. Most
importantly, that B<FormBuilder> only knows about those fields you've
told it about. So, let's assume that you're going to use a special
parameter called C<mode> to control the mode of your application so
that you can call it like this:

    myapp.cgi?mode=list&...
    myapp.cgi?mode=edit&...
    myapp.cgi?mode=remove&...

And so on. You need to do two things. First, you need the C<keepextras>
option:

    my $form = CGI::FormBuilder->new(..., keepextras => 1);

This will maintain the C<mode> field as a hidden field across requests
automatically. Second, you need to realize that since the C<mode> is
not a defined field, you have to get it via the C<cgi_param()> method:

    my $mode = $form->cgi_param('mode');

This will allow you to build a large multiscreen application easily,
even integrating it with modules like C<CGI::Application> if you want.

You can also do this by simply defining C<mode> as a field in your
C<fields> declaration. The reason this is discouraged is because
when iterating over your fields you'll get C<mode>, which you likely
don't want (since it's not "real" data).

=head2 Why won't CGI::FormBuilder work with POST requests?

It will, but chances are you're probably doing something like this:

    use CGI qw/:standard/;
    use CGI::FormBuilder;

    # Our "mode" parameter determines what we do
    my $mode = param('mode');

    # Change our form based on our mode
    if ($mode eq 'view') {
        my $form = CGI::FormBuilder->new(
                        method => 'POST',
                        fields => [qw/.../],
                   );
    } elsif ($mode eq 'edit') {
        my $form = CGI::FormBuilder->new(
                        method => 'POST',
                        fields => [qw/.../],
                   );
    }

The problem is this: Once you read a C<POST> request, it's gone
forever. In the above code, what you're doing is having C<CGI.pm>
read the C<POST> request (on the first call of C<param()>).

Luckily, there is an easy solution. First, you need to modify
your code to use the OO form of C<CGI.pm>. Then, simply specify
the C<CGI> object you create to the C<params> option of B<FormBuilder>:

    use CGI;
    use CGI::FormBuilder;

    my $cgi = CGI->new;

    # Our "mode" parameter determines what we do
    my $mode = $cgi->param('mode');

    # Change our form based on our mode
    # Note: since it is POST, must specify the 'params' option
    if ($mode eq 'view') {
        my $form = CGI::FormBuilder->new(
                        method => 'POST',
                        fields => [qw/.../],
                        params => $cgi      # get CGI params
                   );
    } elsif ($mode eq 'edit') {
        my $form = CGI::FormBuilder->new(
                        method => 'POST',
                        fields => [qw/.../],
                        params => $cgi      # get CGI params
                   );
    }

Or, since B<FormBuilder> gives you a C<cgi_param()> function, you
could modify your code so you use B<FormBuilder> exclusively.

=head2 How do I make it so that the values aren't shown in the form?

Easy.

    my $form = CGI::FormBuilder->new(sticky => 0, ...);

By turning off the C<sticky> option, you will still be able to access
the values, but they won't show up in the form.

=head2 How do I manually override the value of a field?

You must specify the C<force> option:

    $form->field(name => 'name_of_field', value => $value, force => 1);

If you don't specify C<force>, then any CGI value will always win.

=head2 How can I change option XXX based on a conditional?

Remember that C<render()> can take any option that C<new()> can. This
means that you can set some features on your form sooner and others
later:

    my $form = CGI::FormBuilder->new(method => 'POST');

    my $mode = $form->cgi_param('mode');

    if ($mode eq 'add') {
        print $form->render(fields => [qw/name email phone/],
                            title  => 'Add a new entry');
    } elsif ($mode eq 'edit') {
        # do something to select existing values
        my %values = select_values();
        print $form->render(fields => [qw/name email phone/],
                            title  => 'Edit existing entry',
                            values => \%values);
    }

In fact, since any of the options can be used in either C<new()> or 
C<render()>, you could have specified C<fields> to C<new()> above
since they are the same for both conditions.

=head2 I can't get "validate" to accept my regular expressions!

You're probably not specifying them within single quotes. See the
section on C<validate> above.

=head2 Can FormBuilder handle file uploads?

It sure can, and it's really easy too. Just change the C<enctype>
as an option to C<new()>:

    use CGI::FormBuilder;
    my $form = CGI::FormBuilder->new(
                    enctype => 'multipart/form-data',
                    method  => 'POST',
                    fields  => [qw/filename/]
               );

    $form->field(name => 'filename', type => 'file');

And then get to your file the same way as C<CGI.pm>:

    if ($form->submitted) {
        my $file = $form->field('filename');

        # save contents in file, etc ...
        open F, ">$dir/$file" or die $!;
        while (<$file>) {
            print F;
        }
        close F;

        print $form->confirm(header => 1);
    } else {
        print $form->render(header => 1);
    }

In fact, that's a whole file upload program right there.

=back

=head1 BUGS AND FEATURES

This has been used pretty thoroughly in a production environment
for a while now, so it's definitely stable, but I would be shocked
if it's bug-free. Bug reports and B<especially patches> to fix such
bugs are welcomed.

I'm always open to entertaining "new feature" requests, but before
sending me one, first try to work within this module's interface.
You can very likely do exactly what you want by using a template.

=head1 NOTES

Parameters beginning with a leading underscore are reserved for
future use by this module. Use at your own peril.

This module does a B<lot> of guesswork for you. This means that
sometimes (although hopefully rarely), you may be scratching your
head wondering "Why did it do that?". Just use the C<field>
method to set things up the way you want and move on.

Due to too many incompatibilities with CGI.pm, unfortunately
C<CGI::Minimal> is no longer used. Sorry.

The output of the HTML generated natively may change slightly from
release to release. If you need precise control, use a template.

=head1 SUPPORT

For support, please start by visiting the FormBuilder website at:

    www.formbuilder.org

This site has numerous tutorials and other documentation to help you
use FormBuilder to its full potential. There will also be a mailing
list, hopefully setup by the time are read this.

If you can't find the answer there, then feel free to email me directly.

=head1 ACKNOWLEDGEMENTS

This module has really taken off, thanks to very useful input, bug
reports, and encouraging feedback from a number of people, including:

    Andy Wardley
    Jakob Curdes
    Mark Belanger
    Peter Billam
    Godfrey Carnegie
    Florian Helmberger
    Mark Houliston
    Randy Kobes
    William Large
    Kevin Lubic
    Mehryar
    Koos Pol
    Shawn Poulson
    Dan Collis Puro
    John Theus

Thanks!

=head1 SEE ALSO

L<HTML::Template>, L<Template>, L<CGI::Minimal>, L<CGI>, L<CGI::Application>

=head1 VERSION

$Id: FormBuilder.pm,v 2.7 2002/10/04 17:42:22 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2001-2002 Nathan Wiger <nate@nateware.com>. All Rights 
Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut
