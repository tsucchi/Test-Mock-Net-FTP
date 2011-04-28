#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More;
use t::Util;
use Test::Mock::Net::FTP;
use File::Spec::Functions qw(catfile);
use File::Copy;

subtest 'transfer mode', sub {
    my $ftp = prepare_ftp();
    is( $ftp->mock_transfer_mode(), 'ascii');#default transfer mode is ascii

    $ftp->binary();
    is( $ftp->mock_transfer_mode(), 'binary');

    $ftp->ascii();
    is( $ftp->mock_transfer_mode(), 'ascii');

    done_testing();
};

subtest 'connection mode', sub {
    my $ftp = prepare_ftp();
    is( $ftp->mock_connection_mode(), 'pasv');
    is( $ftp->mock_port_no(),         '');

    $ftp->port(1234);
    is( $ftp->mock_connection_mode(), 'port');
    is( $ftp->mock_port_no(),         '1234');

    $ftp->pasv();
    is( $ftp->mock_connection_mode(), 'pasv');
    is( $ftp->mock_port_no(),         '');

    # specify port mode(and default port no)
    $ftp = prepare_ftp(Passive=>0);
    is( $ftp->mock_connection_mode(), 'port');
    is( $ftp->mock_port_no(),         '20');

    # specify port no
    $ftp = prepare_ftp(Port=>1122);
    is( $ftp->mock_connection_mode(), 'port');
    is( $ftp->mock_port_no(),         '1122');

    done_testing();
};

subtest 'site', sub {
    my $ftp = prepare_ftp();
    $ftp->site("help");
    ok(1); #dummy
    done_testing();
};

subtest 'hash', sub {
    my $ftp = prepare_ftp();
    $ftp->hash();
    ok(1); #dummy
    done_testing();
};

subtest 'alloc', sub {
    my $ftp = prepare_ftp();
    $ftp->alloc(1024);
    ok(1); #dummy
    done_testing();
};

subtest 'size', sub {
    my $ftp = prepare_ftp();
    copy( catfile('t', 'testdata', 'data1.txt'), catfile('tmp', 'ftpserver', 'dir1', 'data1.txt' ) );
    $ftp->cwd('dir1');
    ok( $ftp->size("data1.txt") );
    unlink catfile('tmp', 'ftpserver', 'dir1', 'data1.txt' );
    done_testing();
};

subtest 'mdtm', sub {
    my $ftp = prepare_ftp();
    copy( catfile('t', 'testdata', 'data1.txt'), catfile('tmp', 'ftpserver', 'dir1', 'data1.txt' ) );
    $ftp->cwd('dir1');
    ok( $ftp->mdtm("data1.txt") );
    unlink catfile('tmp', 'ftpserver', 'dir1', 'data1.txt' );
    done_testing();
};

done_testing();

