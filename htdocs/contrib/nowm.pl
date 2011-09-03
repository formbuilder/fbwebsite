#!/usr/bin/perl

# Copyright (c) 2003-2005 Nathan Wiger <nate@wiger.org>
# nowm.pl - non-watermark label emailer

use lib '../../lib';
use strict;

use BeerLabels::Conf;
use BeerLabels::Layout;
use BeerLabels::DBI;
use BeerLabels::Labelize;

use MIME::Lite;
use SQL::Abstract;   # of course
use File::Basename;

my %cf  = BeerLabels::Conf->readconf;
my $dbh = BeerLabels::DBI->connect;
my $sql = SQL::Abstract->new;
my $br  = '<br />';

use CGI;
use CGI::FormBuilder;

my $cgi  = CGI->new;
my @path = split '/', $cgi->path_info;
my $id   = pop @path;   # last element is label id
die "Missing file as PATH_INFO" unless $id;
my $lf   = labelurl($cf{imgorig}, $id);

# List of regexes of fuckkers fucking with our shit
my $fuckoff = 'fuckoff.list';
open(FO, $fuckoff);
my @fuckoff;
while (<FO>) {
    s/\s*#.*//;         # strip comments
    next if /^\s*$/;    # blank lines
    chomp;
    push @fuckoff, $_;
}
close FO;

my $pp = <<'EOPP';
<!-- BEGIN PAYPAL CODE -->
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_xclick" />
<input type="hidden" name="business" value="nate@wiger.org" />
<input type="hidden" name="item_name" value="BeerLabels.com site hosting fees" />
<input type="image" src="http://www.paypal.com/images/x-click-but04.gif" 
name="submit" alt="Donate using PayPal" />
</form>
<!-- END PAYPAL CODE -->
EOPP


# Random string generation
# Only the first 6 characters are used
my @chr = (0..9, 'A'..'Z');
my $str = '';
srand(time() ^ $$);
for (0..24) {
    $str .= $chr[rand(@chr)];
}

# rot13 the fucking string for our image verification
sub rot13 ($) {
    my $str = shift;
    $str =~ tr/A-Za-z0-9/N-ZA-Mn-za-m987654321/;   # rot13 (trivial)
    return $str;
}

# Note: The variable "session" is really just a rot13'ed verification
# string, but it's meant to throw off script kiddies thru obscurity.
my $form = CGI::FormBuilder->new(
                fields => [qw/email string session/],
                messages => {form_required_text => ''},
                method => 'POST',
                reset => 0, submit => 'Request Label',
                fieldtype => 'hidden', lalign => 'right',
                validate => {email => 'EMAIL'},
                required => [qw/email string/],
                text => <<EOT,
First off, have you considered donating some cash?$br
Why not click on the PayPal Donate button above?
<p>
If you have, THANK YOU. This site costs us over \$100/month to host$br
because of the gigs and gigs of images.
<p>
Anyways, submit this form to get a watermark-free label.
<p>
<b><i>The image will be emailed to you, so you
must enter a valid email address.$br
La imagen será enviada a usted, así que usted debe incorporar
un email address válido.$br
L'image sera expédiée à vous, ainsi vous devez écrire un email
address valide.$br
Das Bild wird zu Ihnen verschickt, also müssen Sie ein gültiges
email address eintragen.$br
</i></b>
</p>
EOT
           );

if ($form->submitted && (1 ||
  uc($form->field('string')) eq rot13(substr($form->field('session'),0,6)))) {
    my $em = lc($form->field('email')) || die "Can't do shit w/o an email address";

    my $lmesg = '';     # loser message
    for (@fuckoff) {
        if ($em =~ /$_/ || $ENV{REMOTE_ADDR} eq $_) {
            # tell them to fuckoff
            $lmesg = <<EOM;
:<blockquote class="error">
You've been blocked for generally being an ass monkey.
</blockquote>
EOM
        }
    }

    #
    # Look for a record (this is mysql!)
    # Allow them to re-download the same thing repeatedly
    #
    my $rec = $dbh->selectall_arrayref("select * from $cf{tfreeload}
                                         where email = '$em'
                                           and download_file != '$lf'");

    #
    # Are they a donater?
    # This is a *FLAG* - no useful file info is in this table
    #
    my $don = $dbh->selectall_arrayref("select * from $cf{tdonate}
                                         where email = '$em'");

    # See if they've overstayed their welcome
    my $n = @$rec + 1;  # number downloaded
    my $d = @$don;      # number of donations

    # Which limit to use (verbose for message below)
    my $lmax  = $d ? $cf{ndonate} : $cf{nfreeload};
    if (!$d && $n > $cf{nfreeload}) {
       $lmesg = " for free ($cf{nfreeload})";
    } elsif ($d && $n > ($cf{ndonate}*$d)) {
       $lmesg = ", even with a donation ($cf{ndonate})";
    }

    if ($lmesg && $em ne 'nwiger@gmail.com') {
        print $cgi->header, layout({TITLE => 'Overstayed Your Welcome'}, <<EOT);
<b>No Dice</b>
<p>
Sorry, you've asked for too many labels$lmesg$br
This site costs us almost \$100/month to run because of all$br
the gigs of images, and we're not rich bastards.
<p>
Click on the "PayPal Donate" button to send us some cash.$br
We're not asking for alot. Just a couple bucks.
$pp
<p>
As soon as we get it we'll allow you to download more labels.$br
<i>
Cuando recibimos su donación, permitiremos que usted descargue más
etiquetas.$br
Quand nous recevons votre donation, nous vous permettrons de télécharger
plus d'étiquettes.$br
Wenn wir Ihre Abgabe empfangen, erlauben wir Ihnen, mehr Aufkleber
zu downloaden.$br
</i>
<p>
Note: You're not legally required to send us squat. If you'd like
additional labels for free, simply email us manually using our
<a href="$cf{contact}">contact form</a>.
<p>
Thanks,$br
Corey and Nate
<p>
EOT
        exit if $em eq 'nate@wiger.org';    # testing

        $lmesg =~ s/<[^>]+>//g;     # strip HTML
        warn "Freeloader $em asked for too much$lmesg [$ENV{REMOTE_ADDR}]\n";

    if (0) {
        # email it to us, but only on freeloader status
        my $cmsg = MIME::Lite->new(
                      To         => $cf{email},
                      'Reply-To' => $em,
                      Subject    => "[BL] Freeloader $em asked too much",
                      Data       => "Freeloader $em requested too many labels$lmesg [$ENV{REMOTE_ADDR}]",
                   );
        $cmsg->send || die "Cannot email $lf to $em: $!";
    }

        exit;
    }

    # New user, or donater, so they get a label
    my $lfpath = "$cf{basedir}/$lf";
    unless (-f $lfpath) {
        warn "[nowm.pl] Cannot read $lfpath: $!\n";
        print $cgi->header, layout({TITLE => 'Watermark-free Error'}, <<EOT);
<b>Error with label</b>
<p>
Sorry, we couldn't find a watermark-free version of that label in our database.<br />
This happens rarely for some labels that we scanned in long ago.
<p>
Please <a href="$cf{contact}">contact us directly</a>.
EOT
        exit;
    }

    ### Create a new single-part message, to send a GIF file:
    my $msg = MIME::Lite->new(
                  From     => $cf{email},
                  To       => $em,
                  Subject  => "Watermark-free label #$id",
                  Type     => 'TEXT',
                  Data     => <<EOD,
Attached is the watermark-free label you requested
from BeerLabels.com. Enjoy!

Cheers,
Nate and Corey
BeerLabels.com
EOD
              );

    $msg->attach(Type     => 'image/jpeg',
                 Encoding => 'base64',
                 Path     => $lfpath,
                 Filename => basename($lfpath));
    $msg->send || die "Cannot email $lf to $em: $!";

    # success
    warn "[nowm.pl] Gave clean $lf to $em ($n/$lmax) [$ENV{REMOTE_ADDR}]\n";

    # write a database record
    my %ins = (
        email         => $em,
        download_file => $lf,
        download_date => \'now()',
    );
    my($stmt, @bind) = $sql->insert($cf{tfreeload}, \%ins);
    $dbh->do($stmt, {}, @bind) || die "Cannot insert: $DBI::errstr";

    # confirmation message
    my $annoy = $d ? '' : "${br}If you enjoy it, a little cash would be cool.";
    print $cgi->header, layout({TITLE => 'Watermark-free Label'}, <<EOT);
<b>Watermark-free label sent</b>
<p>
All done, we just emailed a clean copy of the full-size label to $em.
$annoy
</p><p>
If you don't get it, <b>check your "Spam" or "Junk" mail folders</b>.$br
If it's still not there, <a href="mailto:$cf{email}">let us know</a>.
</p><p>
Happy drinking,$br
Corey and Nate
</p>
EOT

} else {
    $form->field(name => 'email', type => 'text',
                 label => "Your email address:");

    my $ckstr = rot13($str);
    my $vlink = ''; #qq(<img src="$cf{cverimage}?$ckstr" height="18" alt="Verification" align="middle" />);

    $form->field(name => 'string', type => 'text', size => 6, type => 'hidden',
                 maxlength => 10, label => "Enter $vlink:");

    $form->field(name => 'session', value => $ckstr, force => 1);

    print $cgi->header, layout({TITLE => "Watermark-free Label"},
                               '<b>Watermark-free label request</b>',
                               ' (<a href="javascript:history.back();">back</a>)', $br, $br,
                               $form->render);
}

