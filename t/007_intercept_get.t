#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use File::Path qw(remove_tree make_path);
use File::Copy;
use File::Spec::Functions qw(catfile catdir);
use Cwd qw(chdir getcwd);

use Test::Mock::Net::FTP qw(intercept);
use Net::FTP;


remove_tree 'tmp' if ( -e 'tmp' );
remove_tree 'ftpserver' if ( -e 'ftpserver' );

make_path( catdir('ftpserver', 'dir1'), 'tmp' );
copy( catfile('t', 'testdata', 'data1.txt'), catfile('ftpserver', 'dir1', 'data1.txt' ) );

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1'=> {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        },
    },
);

my $ftp = Net::FTP->new('somehost.example.com'); #replaced by Test::Mock::Net::FTP
$ftp->login('user1', 'secret');
my $cwd = getcwd();
chdir( 'tmp' );

$ftp->cwd('dir1');
$ftp->get( 'data1.txt' );
ok( -e 'data1.txt' );
open(my $IN, '<', 'data1.txt' ) or die $@;
my $contents = do { local $/; <$IN>};
close($IN);
is( $contents, "this is testdata #1\n");


chdir($cwd);
remove_tree('tmp');
remove_tree('ftpserver');
$ftp->close if defined ($ftp);


done_testing();
