package Test::Mock::Net::FTP;
use strict;
use warnings;

use File::Copy;
use File::Spec::Functions qw( catdir splitdir rootdir catfile curdir rel2abs abs2rel );
use File::Basename;
use Cwd qw(getcwd);
use Carp;

our $VERSION = '0.01';

=head1 NAME

Test::Mock::Net::FTP - Mock Object for Net::FTP

=head1 SYNOPSIS

  use strict;
  use warnings;

  use Test::More;
  use Test::Mock::Net::FTP;

  Test::Mock::Net::FTP::mock_prepare(
      'somehost.example.com' => {
          'user1'=> {
              password => 'secret',
              dir => ['./ftpserver', '/ftproot'],
          },
      }
  );
  my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
  $ftp->login('user1', 'secret');
  $ftp->cwd('datadir');
  $ftp->get('file1');
  $ftp->quit();
  # or
  use Test::Mock::Net::FTP qw(intercept);
  some_method_using_ftp();


=head1 DESCRIPTION

Test::Mock::Net::FTP is Mock Object for Net::FTP. This module behave like FTP servers, but only use local filesystem.(not using socket).

=cut

my %mock_server;


=head1 METHODS

=cut

=head2 mock_prepare(%params)

prepare FTP server in your local filesystem.

=cut

sub mock_prepare {
    my %args = @_;
    %mock_server = %args;
}


=head2 new($host, %options)

create new instance

=cut

sub new {
    my $class = shift;
    my ( $host, %opts ) = @_;
    return if ( !exists $mock_server{$host} );

    my $self = {
        mock_host            => $host,
        mock_phisical_root   => '',
        mock_server_root     => '',
        mock_transfer_mode   => 'ascii',
        mock_connection_mode => 'pasv',
    };
    bless $self, $class;
}

=head2 login($user, $password)

login mock FTP server

=cut

sub login {
    my $self = shift;
    my ( $user, $pass ) = @_;
    if ( $self->_mock_login_auth( $user, $pass) ) {# auth success
        $self->{mock_cwd} = rootdir();
        my $mock_server_for_user = $mock_server{$self->{mock_host}}->{$user};
        $self->{mock_phisical_root}   = rel2abs($mock_server_for_user->{dir}->[0]) if defined $mock_server_for_user->{dir}->[0];
        $self->{mock_server_root} = $mock_server_for_user->{dir}->[1] if defined $mock_server_for_user->{dir}->[1];
        return 1;
    }
    $self->{message} = 'Login incorrect.';
    return;
}

sub _mock_login_auth {
    my $self = shift;
    my ( $user, $pass ) = @_;
    my $server_user     = $mock_server{$self->{mock_host}}->{$user};
    return if !defined $server_user; #user not found
    my $server_password = $server_user->{password};
    return $server_password eq $pass;
}


=head2 pwd()

return (mock) server current directory

=cut

sub pwd {
    my $self =shift;
    return catdir($self->{mock_server_root}, $self->_mock_cwd);
}


=head2 mock_pwd()

mock's current directory

=cut

sub mock_pwd {
    my $self = shift;
    return catdir(abs2rel($self->{mock_phisical_root}), $self->_mock_cwd);
}


=head2 cwd($dir)

change (mock) server current directory

=cut

sub cwd {
    my $self = shift;
    my ($dirs) = @_;

    if ( !defined $dirs ) {
        $self->{mock_cwd} = rootdir();
        $dirs = "";
    }

    my $backup_cwd = $self->_mock_cwd;
    for my $dir ( splitdir($dirs) ) {
        $self->_mock_cwd_each($dir);
    }
    $self->{mock_cwd} =~ s/^$self->{mock_server_root}//;#for absolute path
    return $self->_mock_check_pwd($backup_cwd);
}

sub _mock_cwd_each {
    my $self = shift;
    my ( $dir ) = @_;
    if ( $dir eq '..' ) {
        $self->{mock_cwd} = dirname($self->_mock_cwd);# to updir
    }
    else {
        $self->{mock_cwd} = catdir($self->_mock_cwd, $dir);
    }
}

# check if mock server directory "phisically" exists.
sub _mock_check_pwd {
    my $self = shift;
    my( $backup_cwd ) = @_;
    if ( ! -d $self->mock_pwd ) {
        $self->{mock_cwd} = $backup_cwd;
        $self->{message} = 'Failed to change directory.';
        return 0;
    }
    return 1;
}

=head2 put($local_file, [$remote_file])

put a file to mock FTP server

=cut

sub put {
    my $self = shift;
    my($local_file, $remote_file) = @_;
    $remote_file = basename($local_file) if ( !defined $remote_file );
    copy( $self->_abs_local_file($local_file),
          $self->_abs_remote_file($remote_file) ) || croak "can't put $local_file to $remote_file\n";
}

=head2 get($remote_file, [$local_file])

get file from mock FTP server

=cut

sub get {
    my $self = shift;
    my($remote_file, $local_file) = @_;
    $local_file = basename($remote_file) if ( !defined $local_file );
    copy( $self->_abs_remote_file($remote_file),
          $self->_abs_local_file($local_file)   ) || croak "can't get $remote_file\n";
}


=head2 ls($dir)

list file(s) in server directory.

=cut

sub ls {
    my $self = shift;
    my($dir) = @_;
    my $target_dir = $self->_remote_dir_for_dir($dir);
    my @ls = split(/\n/, `ls $target_dir`);
    return (defined $dir)? map{ catfile($dir, $_) } @ls : @ls;
}


=head2 dir($dir)

list file(s) with detail information(ex. filesize) in server directory.

=cut

sub dir {
    my $self = shift;
    my($dir) = @_;
    my $target_dir = $self->_remote_dir_for_dir($dir);
    my @dir = split(/\n/, `ls -l $target_dir`);
    shift @dir if ( $dir[0] !~ /^[-rxwtTd]{10}/ ); #remove like "total xx"
    return @dir;
}

=head2 rename($oldname, $newname)

rename remote file

=cut

sub rename {
    my $self = shift;
    my ($oldname, $newname) = @_;
    rename $self->_abs_remote_file($oldname), $self->_abs_remote_file($newname);
}

=head2 delete($filename)

delete remote file

=cut

sub delete {
    my $self = shift;
    my ($filename) = @_;
    unlink $self->_abs_remote_file($filename);
}


=head2 port($port_no)

specify data connection to port-mode

=cut

sub port {
    my $self = shift;
    $self->{mock_connection_mode} = 'port';
}

=head2 pasv()

specify data connection to passive-mode

=cut

sub pasv {
    my $self = shift;
    $self->{mock_connection_mode} = 'pasv';
}

=head2 mock_connection_mode()

return current connection mode (port or pasv)

=cut

sub mock_connection_mode {
    my $self = shift;
    return $self->{mock_connection_mode};
}


=head2 binary()

enter binary mode

=cut

sub binary {
    my $self = shift;
    $self->{mock_transfer_mode} = 'binary';
}

=head2 ascii()

enter ascii mode

=cut

sub ascii {
    my $self = shift;
    $self->{mock_transfer_mode} = 'ascii';
}

=head2 mock_transfer_mode()

return current transfer mode(ascii or binary)

=cut

sub mock_transfer_mode {
    my $self = shift;
    return $self->{mock_transfer_mode};
}

=head2 quit()

quit. currently do nothing

=cut

sub quit {
    my $self = shift;
    return 1;
}

=head2 close()

close connection mock FTP server.(eventually do nothing)

=cut

sub close {
    return 1;
}

=head2 abort()

abort. currently do nothing

=cut

sub abort {
    my $self = shift;
    return 1;
}


=head2 site(@args)

execute SITE command (currently do nothing)

=cut

sub site {
    my $self = shift;
    return 1;
}


sub _remote_dir_for_dir {
    my $self = shift;
    my($dir) = @_;
    $dir =~ s/^$self->{mock_server_root}// if (defined $dir && $dir =~ /^$self->{mock_server_root}/ ); #absolute path
    $dir = "" if !defined $dir;
    return catdir($self->mock_pwd, $dir);
}

sub _remote_dir_for_file {
    my $self = shift;
    my( $remote_file ) = @_;
    my $remote_dir = dirname( $remote_file ) eq curdir() ? $self->{mock_cwd} : dirname( $remote_file ) ;
    $remote_dir =~ s/^$self->{mock_server_root}// if ( $remote_file =~ /^$self->{mock_server_root}/ );
    return $remote_dir;
}

sub _abs_remote_file {
    my $self = shift;
    my( $remote_file ) = @_;
    my $remote_dir = $self->_remote_dir_for_file($remote_file);
    $remote_dir = "" if !defined $remote_dir;
    return catfile($self->{mock_phisical_root}, $remote_dir, basename($remote_file))
}

sub _abs_local_file {
    my $self = shift;
    my ($local_file) = @_;
    my $root = rootdir();
    return $local_file if ( $local_file =~ m{^$root} );
    my $local_dir = dirname( $local_file ) eq curdir() ? getcwd() : dirname( $local_file );
    $local_dir = "" if !defined $local_dir;
    return catfile($local_dir, basename($local_file));
}

=head2 message()

return messages from mock FTP server

=cut

sub message {
    my $self = shift;
    return $self->{message};
}

sub _mock_cwd {
    my $self = shift;
    return (defined $self->{mock_cwd}) ? $self->{mock_cwd} : "";
}


sub import {
    my ($package, @args) = @_;
    for my $arg ( @args ) {
        _mock_intercept() if ( $arg eq 'intercept' );
    }
}

sub _mock_intercept {
    use Net::FTP;
    no warnings 'redefine';
    *Net::FTP::new = sub {
        my $class = shift;#discard $class
        return Test::Mock::Net::FTP->new(@_);
    }
}

sub AUTOLOAD {
    our $AUTOLOAD;
    (my $method = $AUTOLOAD) =~ s/.*:://s;
    carp "Not Impremented method $method called.";
}

sub DESTROY {}

1;


=head1 AUTHOR

Takuya Tsuchida E<lt>tsucchi at cpan.orgE<gt>

=head1 SEE ALSO

L<Net::FTP>

=head1 REPOSITORY

L<http://github.com/tsucchi/Test-Mock-Net-FTP>


=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009-2011 Takuya Tsuchida

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
