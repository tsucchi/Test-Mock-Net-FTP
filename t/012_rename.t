#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir rootdir);
use File::Copy;

use Test::Mock::Net::FTP;

my $ftp;
my $IN;
my $contents;
my $my_tmp;


BEGIN {
    $my_tmp = catdir(rootdir(), 'tmp', $ENV{USER});
    remove_tree 'ftpserver' if ( -e 'ftpserver' );
    make_path( catdir('ftpserver', 'dir1'), catdir('ftpserver', 'dir2'), $my_tmp );

    Test::Mock::Net::FTP::mock_prepare(
        'somehost.example.com' => {
            'user1' => {
                password => 'secret',
                dir => ['ftpserver', '/ftproot'],
            },
        },
    );

    $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
    $ftp->login('user1', 'secret');
}

END {
    remove_tree('ftpserver');
    remove_tree  $my_tmp if ( -e $my_tmp );
    $ftp->close if defined ($ftp);
}

$ftp->cwd('dir1');
$ftp->put( 't/testdata/data1.txt' );
ok( -e catfile('ftpserver', 'dir1', 'data1.txt') );
ok( !-e catfile('ftpserver', 'dir1', 'data2.txt') );

$ftp->rename('data1.txt', 'data2.txt');
ok( !-e catfile('ftpserver', 'dir1', 'data1.txt') );
ok( -e catfile('ftpserver', 'dir1', 'data2.txt') );

done_testing();
