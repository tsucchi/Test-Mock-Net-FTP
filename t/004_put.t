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
$ftp->put( catfile('t', 'testdata', 'data1.txt') );
ok( -e catfile('ftpserver', 'dir1', 'data1.txt') );

open($IN, '<', catfile('ftpserver', 'dir1', 'data1.txt') ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");


# specify remote filename
$ftp->cwd();
$ftp->put( catfile('t', 'testdata', 'data1.txt'), catfile('dir2', 'data1_another_name.txt') );
ok( -e catfile('ftpserver', 'dir2', 'data1_another_name.txt') );
open($IN, '<', catfile('ftpserver', 'dir2', 'data1_another_name.txt') ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");


# specify absolute path
$ftp->cwd();
$ftp->put( catfile('t', 'testdata', 'data1.txt'), '/ftproot/dir2/data1_another_name2.txt' );
ok( -e catfile('ftpserver', 'dir2', 'data1_another_name2.txt') );
open($IN, '<', catfile('ftpserver', 'dir2', 'data1_another_name2.txt') ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");

my $file_in_my_tmp = catfile($my_tmp, 'data1_copy2.txt');
copy( catfile('t', 'testdata', 'data1.txt'), $file_in_my_tmp );
$ftp->cwd();
$ftp->put( $file_in_my_tmp, '/ftproot/dir2/data1_another_name2.txt' );
ok( -e catfile('ftpserver', 'dir2', 'data1_another_name2.txt') );
open($IN, '<', catfile('ftpserver', 'dir2', 'data1_another_name2.txt') ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");

done_testing();
