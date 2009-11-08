#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir);
use Test::Mock::Net::FTP qw(intercept);

my $ftp;
my $IN;
my $contents;

remove_tree 'ftpserver' if ( -e 'ftpserver' );
make_path( catdir('ftpserver', 'dir1') );


Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1' => {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        },
    },
);

use Net::FTP;
$ftp = Net::FTP->new('somehost.example.com');# (replaced by Test::Mock::Net::FTP)
ok( defined $ftp );

$ftp->login('user1', 'secret');
$ftp->cwd('dir1');
$ftp->put( catfile('t', 'testdata', 'data1.txt') );
ok( -e catfile('ftpserver', 'dir1', 'data1.txt') );

remove_tree('ftpserver');
$ftp->close if defined ($ftp);


done_testing();
