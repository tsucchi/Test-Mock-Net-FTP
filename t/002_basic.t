#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use Test::Mock::Net::FTP;

Test::Mock::Net::FTP::mock_prepare(
    'somehost.example.com' => {
        'user1' => {
            password => 'secret',
        },
        'user2' => {
            password => 'secret2',
        }
    },
    'host2.example.com' => {
        'userX' => {
            password => 'secretX',
        }

    },
);

ok( !defined Test::Mock::Net::FTP->new('invalidhost.example.com') );

my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
ok( defined $ftp);
ok( defined $ftp->login('user1', 'secret') );
ok( !defined $ftp->login('invalid', 'invalid') );
is( $ftp->message, 'Login incorrect.');
ok( $ftp->close );


$ftp = Test::Mock::Net::FTP->new('host2.example.com');
ok( defined $ftp);
ok( defined $ftp->login('userX', 'secretX') );
ok( $ftp->close );


done_testing();
