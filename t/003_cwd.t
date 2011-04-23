#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir);
use Test::Mock::Net::FTP;


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
}

END {
    remove_tree('tmp');
}

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
