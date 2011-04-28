#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;
use File::Spec::Functions qw(catfile catdir rootdir);
use t::Util;
use Test::Mock::Net::FTP;
use Cwd;

my $data = catfile('t', 'testdata', 'data1.txt');

subtest 'default put', sub {
    my $ftp = prepare_ftp();

    $ftp->cwd('dir1');
    $ftp->put($data);

    file_contents_ok(catfile($ftp->mock_physical_root, 'dir1', 'data1.txt'), "this is testdata #1\n");
    done_testing();
};

subtest 'default put and chdir', sub {
    my $ftp = prepare_ftp();
    my $cwd = getcwd();

    my $data_abs = catfile($cwd, $data);
    chdir 'tmp';
    $ftp->cwd('dir1');
    $ftp->put($data_abs);

    file_contents_ok(catfile($ftp->mock_physical_root, 'dir1', 'data1.txt'), "this is testdata #1\n");

    chdir $cwd;
    done_testing();
};


subtest 'specify remote filename', sub {
    my $ftp = prepare_ftp();
    $ftp->put( $data, catfile('dir2', 'data1_another_name.txt') );

    file_contents_ok( catfile($ftp->mock_physical_root, 'dir2', 'data1_another_name.txt'),
                      "this is testdata #1\n");
    done_testing();
};



subtest 'specify absolute path', sub {
    my $ftp = prepare_ftp();
    $ftp->put( $data, '/ftproot/dir2/data1_another_name2.txt' );

    file_contents_ok( catfile($ftp->mock_physical_root, 'dir2', 'data1_another_name2.txt'),
                      "this is testdata #1\n");
    done_testing();
};


done_testing();
