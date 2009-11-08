#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir);
use Test::Mock::Net::FTP;

my $ftp;

BEGIN {
    remove_tree 'tmp' if ( -e 'tmp' );
    make_path( catdir('tmp', 'dir1'), catdir('tmp', 'dir1', 'dir2'), catdir('tmp', 'dir1', 'dir3') );

    Test::Mock::Net::FTP::mock_prepare(
        'somehost.example.com', => {
            'user1'=> {
                password => 'secret',
                dir => ['tmp', '/ftproot'], # Map physical path 'tmp' to mock server path '/ftproot'
            },
        }
    );

    $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
    $ftp->login('user1', 'secret');
}

END {
    remove_tree('tmp');
    $ftp->close if defined ($ftp);
}

is( $ftp->pwd, '/ftproot' );
is( $ftp->mock_pwd, 'tmp' );
ok( -d $ftp->mock_pwd);

ok( $ftp->cwd('dir1') );
is( $ftp->pwd, '/ftproot/dir1' );
is( $ftp->mock_pwd, 'tmp/dir1' );
ok( -d $ftp->mock_pwd);

ok( $ftp->cwd() );
is( $ftp->pwd, '/ftproot' ); #back to rootdir
is( $ftp->mock_pwd, 'tmp');
ok( -d $ftp->mock_pwd);
ok( $ftp->cwd('dir1/dir2') );
is( $ftp->pwd, '/ftproot/dir1/dir2' );
is( $ftp->mock_pwd, 'tmp/dir1/dir2' );
ok( -d $ftp->mock_pwd);

ok( $ftp->cwd('..') );
is( $ftp->pwd, '/ftproot/dir1' );
is( $ftp->mock_pwd, 'tmp/dir1' );
ok( -d $ftp->mock_pwd);

$ftp->cwd();
ok( $ftp->cwd('dir1/dir2') );
is( $ftp->pwd, '/ftproot/dir1/dir2' );
is( $ftp->mock_pwd, 'tmp/dir1/dir2' );
ok( -d $ftp->mock_pwd);
$ftp->cwd('../../');
is( $ftp->pwd, '/ftproot' );
is( $ftp->mock_pwd, 'tmp' );
ok( -d $ftp->mock_pwd);

$ftp->cwd();
ok( $ftp->cwd('dir1/dir2') );
is( $ftp->pwd, '/ftproot/dir1/dir2' );
is( $ftp->mock_pwd, 'tmp/dir1/dir2' );
$ftp->cwd('../dir3');
is( $ftp->pwd, '/ftproot/dir1/dir3' );
is( $ftp->mock_pwd, 'tmp/dir1/dir3' );
ok( -d $ftp->mock_pwd);

# absolute path
$ftp->cwd();
ok( $ftp->cwd('/ftproot/dir1/dir2') );
is( $ftp->pwd, '/ftproot/dir1/dir2' );
is( $ftp->mock_pwd, 'tmp/dir1/dir2' );


# no exist path
$ftp->cwd();
ok( !$ftp->cwd('dir1/hoge') );
is( $ftp->message, 'Failed to change directory.');
is( $ftp->pwd(), '/ftproot' ); #directory wasn't change


done_testing();
