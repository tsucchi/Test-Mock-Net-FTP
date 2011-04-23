#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use t::Util;
use Test::Mock::Net::FTP;

$SIG{__WARN__} = sub {
    die shift;
};


subtest 'autoload', sub {
    my $ftp = prepare_ftp();
    eval {
        $ftp->append('aaa', 'bbb');
    };
    like( $@, qr/^Not Impremented method append called\./);
    $ftp->close;
    done_testing();
};

done_testing();
