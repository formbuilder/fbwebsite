#!/usr/bin/perl

use lib '../lib';
use lib '../ex';

use FBSite::Layout;
use CGI::FormBuilder;

my $mail = 'nate@wiger.org';

my $form = CGI::FormBuilder->new(
                method => 'POST',
                fields => [qw/name email topic comments code antibot/],
                font   => 'arial,helvetica',
                required  => 'ALL',
                text => <<EOT,
<p>
To contact Nate, please complete this form. Sorry that I
can't just post my email address any more, but spam sucks.
And, if you expect any type of reply, you need to include a
valid email address. I don't have time for ICQ, AIM, or Java-based
brain implants.
<p>
<font color="#CC0000"><b>Note: PLEASE send general FormBuilder questions
to the <a href="http://groups.google.com/group/perl-formbuilder">FormBuilder
Google Group</a></b></font>.
EOT
           );

$form->field(name => 'topic',
             options => [ 'formbuilder.org feedback',
                          'FormBuilder question',
                          'Consulting inquiry']
            );
$form->field(name => 'comments', type => 'textarea', cols => 65, rows => 10);

# create a basic captcha
my @chr = (0..9, 'A'..'Z');
my $str = '';
srand(time() ^ $$);
for (0..5) {
    $str .= $chr[rand(@chr)];
}

if ($form->submitted && $form->validate &&
    $form->field('code') eq uc($form->field('antibot'))) {
    my $field = $form->field;
    open M, "|/usr/sbin/sendmail -t" or die "Can't write mail: $!";
    print M <<EOM;
From: $field->{name} <$field->{email}>
To: $mail
Subject: $field->{topic}

$field->{comments}
EOM
    close M;
    print layout($form->confirm,
                 'Please give me a couple days to get back to you. Thanks!');
} else {
    $form->field(name => 'antibot', label => "Type '$str' here",
                 validate => "/^$str\$/");
    $form->field(name => 'code', type => 'hidden', value => $str,
                 force => 1);

    open H, "<author.shtml";
    my $h = join '', <H>;
    close H;
    $h =~ s#<!--X-->.*<!--/X-->##;
    print layout($h, $form->render);
}

