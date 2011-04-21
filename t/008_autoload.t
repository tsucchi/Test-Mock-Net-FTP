#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use Test::Mock::Net::FTP;

$SIG{__WARN__} = sub {
    die shift;
};

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1' => {
            password => 'secret',
            dir => ['ftpserver', '/ftproot'],
        }
    },
);


my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
$ftp->login('user1', 'secret');
eval {
    $ftp->append('aaa', 'bbb');
};
like( $@, qr/^Not Impremented method append called\./);
$ftp->close;

done_testing();
