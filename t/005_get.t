#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use File::Path qw(remove_tree make_path);
use File::Copy;
use File::Spec::Functions qw(catfile catdir rootdir);
use Cwd qw(getcwd chdir);

use Test::Mock::Net::FTP;


my $IN;
my $contents;

remove_tree 'tmp' if ( -e 'tmp' );
my $my_tmp = catdir(rootdir, 'tmp', $ENV{USER});
remove_tree  $my_tmp if ( -e $my_tmp );
remove_tree 'ftpserver' if ( -e 'ftpserver' );

make_path( catdir('ftpserver', 'dir1'),  'tmp' , $my_tmp );
copy( catfile('t', 'testdata', 'data1.txt'), catfile('ftpserver', 'dir1', 'data1.txt' ) );

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1'=> {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        },
    }
);

my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
$ftp->login('user1', 'secret');
my $cwd = getcwd();
chdir( 'tmp' );

$ftp->cwd('dir1');
$ftp->get( 'data1.txt' );
ok( -e 'data1.txt' );
open($IN, '<', 'data1.txt' ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");


unlink( 'data1.txt' );
$ftp->cwd();
$ftp->get( 'dir1/data1.txt' );
ok( -e 'data1.txt' );
open($IN, '<', 'data1.txt' ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");

# absolute path
unlink( 'data1.txt' );
$ftp->cwd();
$ftp->get( '/ftproot/dir1/data1.txt', 'data1_copy.txt' );
ok( -e 'data1_copy.txt' );
open($IN, '<', 'data1_copy.txt' ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");

chdir($cwd);

unlink( 'data1.txt' );
$ftp->cwd();
my $file_in_my_tmp = catfile($my_tmp, 'data1_copy2.txt');
$ftp->get( '/ftproot/dir1/data1.txt', $file_in_my_tmp );
ok( -e $file_in_my_tmp );
open($IN, '<', $file_in_my_tmp ) or die $@;
$contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");

remove_tree('tmp');
remove_tree('ftpserver');
remove_tree  $my_tmp;
$ftp->close if defined ($ftp);


done_testing();
