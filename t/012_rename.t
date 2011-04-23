#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Spec::Functions qw(catfile);
use t::Util;
use Test::Mock::Net::FTP;

my $ftp = prepare_ftp();
$ftp->cwd('dir1');
$ftp->put( 't/testdata/data1.txt' );
ok( -e  catfile($ftp->mock_physical_root, 'dir1', 'data1.txt') );
ok( !-e catfile($ftp->mock_physical_root, 'dir1', 'data2.txt') );

$ftp->rename('data1.txt', 'data2.txt');
ok( !-e catfile($ftp->mock_physical_root, 'dir1', 'data1.txt') );
ok( -e  catfile($ftp->mock_physical_root, 'dir1', 'data2.txt') );

done_testing();
