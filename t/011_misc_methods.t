#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More;
use Test::Mock::Net::FTP;

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1'=> {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        },
    }
);

subtest 'transfer mode', sub {
    my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
    $ftp->login('user1', 'secret');
    is( $ftp->mock_transfer_mode(), 'ascii');#default transfer mode is ascii

    $ftp->binary();
    is( $ftp->mock_transfer_mode(), 'binary');

    $ftp->ascii();
    is( $ftp->mock_transfer_mode(), 'ascii');

    $ftp->quit();
    done_testing();
};

subtest 'connection mode', sub {
    my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
    $ftp->login('user1', 'secret');
    is( $ftp->mock_connection_mode(), 'pasv');

    $ftp->port(1234);
    is( $ftp->mock_connection_mode(), 'port');

    $ftp->pasv();
    is( $ftp->mock_connection_mode(), 'pasv');

    $ftp->quit();
    done_testing();
};
done_testing();

