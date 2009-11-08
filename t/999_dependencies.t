#!/usr/bin/perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Test::Dependencies exclude => [qw/Test::Dependencies Test::Mock::Net::FTP/],
                       style   => 'light' ;

ok_dependencies();
