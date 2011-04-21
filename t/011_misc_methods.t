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
my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
is( $ftp->mock_transfer_mode(), 'ascii');#default transfer mode is ascii

$ftp->binary();
is( $ftp->mock_transfer_mode(), 'binary');

$ftp->ascii();
is( $ftp->mock_transfer_mode(), 'ascii');

$ftp->quit();
done_testing();
