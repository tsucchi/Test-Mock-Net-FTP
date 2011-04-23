#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Spec::Functions qw(catfile catdir rootdir);
use t::Util;
use Test::Mock::Net::FTP;


subtest 'default put', sub {
    my $ftp = prepare_ftp();
    my $data = catfile('t', 'testdata', 'data1.txt');
    $ftp->cwd('dir1');
    $ftp->put($data);

    file_contents_ok(catfile('tmp', 'ftpserver', 'dir1', 'data1.txt'), "this is testdata #1\n");
    done_testing();
};


subtest 'specify remote filename', sub {
    my $ftp = prepare_ftp();
    $ftp->put( catfile('t', 'testdata', 'data1.txt'), catfile('dir2', 'data1_another_name.txt') );

    file_contents_ok( catfile('tmp', 'ftpserver', 'dir2', 'data1_another_name.txt'),
                      "this is testdata #1\n");
    done_testing();
};



subtest 'specify absolute path', sub {
    my $ftp = prepare_ftp();
    $ftp->put( catfile('t', 'testdata', 'data1.txt'),
               '/ftproot/dir2/data1_another_name2.txt' );

    file_contents_ok( catfile('tmp', 'ftpserver', 'dir2', 'data1_another_name2.txt'),
                      "this is testdata #1\n");
    done_testing();
};


done_testing();
