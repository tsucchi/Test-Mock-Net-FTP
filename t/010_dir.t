#!/usr/bin/perl

use strict;
use warnings;

use File::Path qw(remove_tree make_path);
use File::Copy;
use File::Spec::Functions qw(catfile catdir);
use Test::More;

use Test::Mock::Net::FTP;

remove_tree 'ftpserver' if ( -e 'ftpserver' );

make_path( catdir('ftpserver', 'dir1') );
copy( catfile('t', 'testdata', 'data1.txt'), catfile('ftpserver', 'dir1', 'data1.txt' ) );
copy( catfile('t', 'testdata', 'data1.txt'), catfile('ftpserver', 'dir1', 'data2.txt' ) );

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1'=> {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        },
    }
);
my @dir_result;
my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
$ftp->login('user1', 'secret');

@dir_result = $ftp->dir('dir1');
is( scalar(@dir_result), 2 );
like( $dir_result[0], qr/data1\.txt$/ );

$ftp->cwd('dir1');
@dir_result = $ftp->dir();
is( scalar(@dir_result), 2 );
like( $dir_result[0], qr/data1\.txt$/ );

$ftp->cwd();
@dir_result = $ftp->dir('/ftproot/dir1'); #absolute path
is( scalar(@dir_result), 2 );
like( $dir_result[0], qr/data1\.txt$/ );

remove_tree 'ftpserver' if ( -e 'ftpserver' );

done_testing();
