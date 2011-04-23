package t::Util;
use strict;
use warnings;
use File::Path qw(remove_tree make_path);
use File::Spec::Functions qw(catfile catdir);
use Test::Mock::Net::FTP;

BEGIN {
    remove_tree 'tmp' if ( -e 'tmp' );
    make_path( catdir('tmp', 'dir1'), catdir('tmp', 'dir1', 'dir2'), catdir('tmp', 'dir1', 'dir3') );

    Test::Mock::Net::FTP::mock_prepare(
        'somehost.example.com', => {
            'user1'=> {
                password => 'secret',
                dir => ['tmp', '/ftproot'], # Map physical path 'tmp' to mock server path '/ftproot'
            },
        },
    );
}

END {
    remove_tree('tmp');
}

1;
