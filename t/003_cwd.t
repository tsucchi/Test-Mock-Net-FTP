#!/usr/bin/perl -w
use Test::More;
use Test::Mock::Net::FTP;
use t::Util;
use strict;
use warnings;

sub prepare_ftp {
    my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
    $ftp->login('user1', 'secret');
    return $ftp;
}

subtest 'default directory', sub {
    my $ftp = prepare_ftp();

    is( $ftp->pwd, '/ftproot' );
    is( $ftp->mock_pwd, 'tmp' );
    ok( -d $ftp->mock_pwd);

    $ftp->quit;
    done_testing();
};

subtest 'chdir to dir1', sub {
    my $ftp = prepare_ftp();

    ok( $ftp->cwd('dir1') );
    is( $ftp->pwd, '/ftproot/dir1' );
    is( $ftp->mock_pwd, 'tmp/dir1' );

    $ftp->quit();
    done_testing();
};

subtest 'back to rootdir', sub {
    my $ftp = prepare_ftp();

    $ftp->cwd('dir1');
    ok( $ftp->cwd() );
    is( $ftp->pwd, '/ftproot' ); #back to rootdir
    is( $ftp->mock_pwd, 'tmp');

    $ftp->quit();
    done_testing();
};

subtest 'chdir to updir', sub {
    my $ftp = prepare_ftp();

    ok( $ftp->cwd('dir1/dir2') );
    is( $ftp->pwd, '/ftproot/dir1/dir2' );
    is( $ftp->mock_pwd, 'tmp/dir1/dir2' );

    $ftp->cwd('../../');
    is( $ftp->pwd, '/ftproot' );
    is( $ftp->mock_pwd, 'tmp' );

    $ftp->quit();
    done_testing();
};

subtest 'chdir to up another dir', sub {
    my $ftp = prepare_ftp();

    ok( $ftp->cwd('dir1/dir2') );
    is( $ftp->pwd, '/ftproot/dir1/dir2' );
    is( $ftp->mock_pwd, 'tmp/dir1/dir2' );
    $ftp->cwd('../dir3');
    is( $ftp->pwd, '/ftproot/dir1/dir3' );
    is( $ftp->mock_pwd, 'tmp/dir1/dir3' );

    $ftp->quit();
    done_testing();
};

subtest 'using absolute path', sub {
    my $ftp = prepare_ftp();

    ok( $ftp->cwd('/ftproot/dir1/dir2') );
    is( $ftp->pwd, '/ftproot/dir1/dir2' );
    is( $ftp->mock_pwd, 'tmp/dir1/dir2' );

    $ftp->quit();
    done_testing();
};


subtest 'invalid path', sub {
    my $ftp = prepare_ftp();

    ok( !$ftp->cwd('dir1/hoge') );
    is( $ftp->message, 'Failed to change directory.');
    is( $ftp->pwd(), '/ftproot' ); #directory wasn't change

    $ftp->quit();
    done_testing();
};


done_testing();
