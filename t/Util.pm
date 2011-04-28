package t::Util;
use parent qw(Exporter);
use strict;
use warnings;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir);
use Test::Mock::Net::FTP;
use Test::More;

our @EXPORT = qw(prepare_ftp file_contents_ok);

BEGIN {
    remove_tree 'tmp' if ( -e 'tmp' );
    make_path( catdir('tmp', 'ftpserver', 'dir1'),
               catdir('tmp', 'ftpserver', 'dir1', 'dir2'),
               catdir('tmp', 'ftpserver', 'dir1', 'dir3'),
               catdir('tmp', 'ftpserver', 'dir2') );

    Test::Mock::Net::FTP::mock_prepare(
        'somehost.example.com', => {
            'user1'=> {
                password => 'secret',
                dir => ['tmp/ftpserver', '/ftproot'],
            },
        },
    );
}

END {
    remove_tree('tmp');
}

sub prepare_ftp {
    my (%option) = @_;
    my $ftp = Test::Mock::Net::FTP->new('somehost.example.com', %option);
    $ftp->login('user1', 'secret');
    return $ftp;
}

sub file_contents_ok {
    my ($filename, $expected_string) = @_;
    local $Test::Builder::Level += 1;

    ok( -e $filename );

    open my $IN, '<', $filename or die $@;
    my $contents = do { local $/; <$IN>};
    close $IN;
    is( $contents, $expected_string);
}


1;
