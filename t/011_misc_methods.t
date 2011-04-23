#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More;
use t::Util;
use Test::Mock::Net::FTP;

subtest 'transfer mode', sub {
    my $ftp = prepare_ftp();
    is( $ftp->mock_transfer_mode(), 'ascii');#default transfer mode is ascii

    $ftp->binary();
    is( $ftp->mock_transfer_mode(), 'binary');

    $ftp->ascii();
    is( $ftp->mock_transfer_mode(), 'ascii');

    $ftp->quit();
    done_testing();
};

subtest 'connection mode', sub {
    my $ftp = prepare_ftp();
    is( $ftp->mock_connection_mode(), 'pasv');

    $ftp->port(1234);
    is( $ftp->mock_connection_mode(), 'port');

    $ftp->pasv();
    is( $ftp->mock_connection_mode(), 'pasv');

    $ftp->quit();
    done_testing();
};

subtest 'site', sub {
    my $ftp = prepare_ftp();
    $ftp->site("help");
    ok(1); #dummy
    done_testing();
};

done_testing();

