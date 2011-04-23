#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use File::Copy;
use File::Spec::Functions qw(catfile);
use t::Util;
use Test::Mock::Net::FTP;
use File::chdir;

copy( catfile('t', 'testdata', 'data1.txt'), catfile('tmp/ftpserver', 'dir1', 'data1.txt' ) );

subtest 'get', sub {
    my $ftp = prepare_ftp();
    local $CWD = 'tmp';

    $ftp->cwd('dir1');
    $ftp->get( 'data1.txt' );
    file_contents_ok('data1.txt', "this is testdata #1\n");
    unlink( 'data1.txt' );
    done_testing();
};

subtest 'specify canonical path', sub {
    my $ftp = prepare_ftp();
    local $CWD = 'tmp';

    $ftp->get( 'dir1/data1.txt' );
    file_contents_ok('data1.txt', "this is testdata #1\n");
    unlink( 'data1.txt' );
    done_testing();
};

subtest 'absolute path and local filename', sub {
    my $ftp = prepare_ftp();
    local $CWD = 'tmp';

    $ftp->cwd();
    $ftp->get( '/ftproot/dir1/data1.txt', 'data1_copy.txt' );
    file_contents_ok('data1_copy.txt', "this is testdata #1\n");
    unlink( 'data1_copy.txt' );
    done_testing();
};



done_testing();
