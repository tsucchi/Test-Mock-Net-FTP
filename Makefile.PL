use inc::Module::Install;

name            'Test-Mock-Net-FTP';
author          'Takuya Tsuchida <tsucchi at cpan.org>';
license         'perl';

perl_version    '5.008';
all_from        'lib/Test/Mock/Net/FTP.pm';

requires        'File::Slurp';
requires        'File::Path'  => '2.07';   # for make_path/remove_tree
test_requires   'Test::More'  => '0.94';   # want to use done_testing() and subtest
test_requires   'parent';
test_requires   'Capture::Tiny';

author_tests    'xt';
author_requires 'Test::Perl::Critic';
author_requires 'Test::Synopsis';
author_requires 'Test::Pod';
author_requires 'Test::Pod::Coverage';
author_requires 'Test::Module::Used' => '0.1.4';
author_requires 'Test::CheckManifest';

no_index        'directory' => 'tmp';
repository      'http://github.com/tsucchi/Test-Mock-Net-FTP';

WriteAll;
