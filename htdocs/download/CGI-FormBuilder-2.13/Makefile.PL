use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub modcheck () {
    # check to see if our template modules are present, as they're optional
    my $failed = '';
    for ('HTML::Template 2.06', 'Text::Template 1.43', 'Template 2.08') {
        my($mod,$ver) = split;
        eval "use $mod $ver";
        if ($@) {
            my($err) = split / at | \(/, $@;
            $failed .= "    $_  ($err)\n";
        }
    }
    if ($failed) {
        warn <<EOW;

Warning: The following OPTIONAL template modules are not installed:

$failed
FormBuilder will still work just fine, a-ok, no problem... unless you
want to use one of these modules for templates. You can always install
them later, FormBuilder will run without them.

EOW
        sleep 3;
    }
    return {};      # hashref is expected by MakeMaker
}

WriteMakefile(
    NAME           => 'CGI::FormBuilder',
    VERSION_FROM   => 'FormBuilder.pm',     # finds $VERSION
    PREREQ_PM      => { CGI => 0 },
    CONFIGURE      => \&modcheck,
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'FormBuilder.pod',  # abstract from POD
       AUTHOR        => 'Nathan Wiger (nate@sun.com)') : ()
    ),
);
