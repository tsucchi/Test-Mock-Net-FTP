#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Path qw(remove_tree);
use File::Spec::Functions qw(catdir);
use t::Util;
use Test::Mock::Net::FTP;

subtest 'mkdir and rmdir', sub {
    remove_tree( catdir('tmp', 'dirX') );

    my $ftp = prepare_ftp();

    ok( !-e catdir($ftp->mock_physical_root, 'dirX' ) );

    $ftp->mkdir('dirX');
    ok( -e catdir($ftp->mock_physical_root, 'dirX' ) );

    $ftp->rmdir('dirX');
    ok( !-e catdir($ftp->mock_physical_root, 'dirX' ) );

    remove_tree( catdir('tmp', 'dirX') );
};

subtest 'mkdir and rmdir recursive', sub {
    remove_tree( catdir('tmp', 'dirX') );

    my $ftp = prepare_ftp();

    ok( !-e catdir($ftp->mock_physical_root, 'dirX', 'dirY', 'dirZ' ) );
    $ftp->mkdir('dirX/dirY/dirZ', 1);
    ok( -e catdir($ftp->mock_physical_root, 'dirX', 'dirY', 'dirZ' ) );

    $ftp->rmdir('dirX', 1);
    ok( !-e catdir($ftp->mock_physical_root, 'dirX', 'dirY', 'dirZ' ) );

    remove_tree( catdir('tmp', 'dirX') );
};


done_testing();
