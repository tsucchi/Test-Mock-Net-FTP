#!/usr/bin/perl -w

use strict;
use warnings;

use File::Path qw(remove_tree make_path);
use File::Copy;
use File::Spec::Functions qw(catfile catdir);

use Test::Mock::Net::FTP;
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
my @ls_result;
my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
$ftp->login('user1', 'secret');

@ls_result = $ftp->ls('dir1');
is( scalar(@ls_result), 2 );
is( $ls_result[0], 'dir1/data1.txt' );

$ftp->cwd('dir1');
@ls_result = $ftp->ls();
is( scalar(@ls_result), 2 );
is( $ls_result[0], 'data1.txt' );

$ftp->cwd();
@ls_result = $ftp->ls('/ftproot/dir1'); #absolute path
is( scalar(@ls_result), 2 );
is( $ls_result[0], '/ftproot/dir1/data1.txt' );

remove_tree 'ftpserver' if ( -e 'ftpserver' );

done_testing();
