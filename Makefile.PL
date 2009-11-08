use inc::Module::Install;

name           'Test-Mock-Net-FTP';
author         'Takuya Tsuchida <takuya.tsuchida@gmail.com>';
version        '0.0.1';
license        'perl';

perl_version   '5.008';
all_from       'lib/Test/Mock/Net/FTP.pm';
test_requires  'Test::More'  => '0.88';   #want to use done_testing()

WriteAll;
