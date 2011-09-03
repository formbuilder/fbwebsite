#!/usr/bin/perl

use lib '../lib';
use strict;

my $base = "$ENV{DOCUMENT_ROOT}/download";

#my $cpanurl = 'http://www.cpan.org/authors/id/N/NW/NWIGER';
my $cpanurl = '/download';
my $basepkg = 'CGI-FormBuilder-';
my $relnote = 'relnotes.pl';
my $docfile = 'docs/CGI/FormBuilder.html';

use FBSite::Layout;

my @h = (head('Download FormBuilder'), <<EOS);
On this page you can download FormBuilder, aka the Perl CGI::FormBuilder
module. You can check out the <a href="/features/">features</a> to get
a better idea of what FormBuilder offers, and make sure to read the appropriate
release notes below. I also strongly recommend you
<a href="http://groups.google.com/group/perl-formbuilder">join the FormBuilder Google Group</a>,
although this is by no means required.
EOS

# Walk thru two releases
opendir D, $base or warn "Can't read $base: $!";
my @dir = readdir D;
my($new, $old, @realold) = reverse sort grep /^$basepkg([\d\.]+)\.t.*gz$/, @dir;
my($beta) = reverse sort grep /^$basepkg([\d\.]+_rc\d+)\.t.*gz$/, @dir;
closedir D;

# Check for an alpha/beta
#my $beta = '';
#unless ($new =~ /(\d+\.\d+)\./) {
    #$beta = $new;
    #$new = $old;
    #$old = shift @realold;
#}

# Extract version numbers
my($bver) = $beta =~ /^$basepkg([\d.]+_rc\d+)\./;
my($nver) = $new =~ /^$basepkg([\d.]+)\./;
my($over) = $old =~ /^$basepkg([\d.]+)\./;

push @h, head("Current Release");
push @h, <<EOC;
<b>The current release of FormBuilder is <a href="$cpanurl/$new" class="mark">$nver</a></b>.
This is the latest stable version, suitable for installation in production
environments. You should read the <a href="$relnote?r=$nver">release notes</a> for a
list of new features, bugfixes, and other details. You can also <a href="$basepkg$nver">browse
the $nver release</a>.
EOC

if ($beta) {
    push @h, head("Development Release");
    push @h, <<EOD;
The current <b>unverified</b> development release is <a href="$cpanurl/$beta" class="mark">$bver</a>.
This has the latest features, and is close to being released. If you're not in a true
7x24 production environment, <i>please</i> try it out! Read the
<a href="$relnote?r=$bver">release notes</a> or <a href="$basepkg$bver">browse
the $bver release</a>.
EOD
}

if ($old) {
    push @h, head("Previous Release");
    push @h, <<EOP;
If you don't have the cajones for installing the latest software, you can
download <a href="$cpanurl/$old" class="mark">$over</a>. However, this version likely
has some known bugs, and there is no way you'll get any support on it. Again,
you should first read the <a href="$relnote?r=$over">release notes</a> for this version.
You can also <a href="$basepkg$over">browse the $over release</a>.
EOP
}

if (@realold) {
    push @h, head("Older FormBuilder Releases");
    push @h, "These are <b>NOT RECOMMENDED</b> unless you're nostalgic or the government.<ul>";
    for (@realold) {
        my($ver) = /^$basepkg([\d.]+)\./;
        push @h, <<EOO;
<li>FormBuilder $ver
    - <a href="$cpanurl/$_">download</a>
    | <a href="$relnote?r=$ver">release notes</a>
    | <a href="$basepkg$ver/$docfile">documentation</a>
    | <a href="$basepkg$ver">browse</a></li>
EOO
    }
}

push @h, "</ul><i>Note: If versions are missing or skipped, it's usually for a very good reason.</i>\n";

print layout(@h);

