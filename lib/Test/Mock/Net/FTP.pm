package Test::Mock::Net::FTP;
use strict;
use warnings;

use File::Copy;
use File::Spec::Functions qw( catdir splitdir rootdir catfile curdir rel2abs abs2rel );
use File::Basename;
use Cwd qw(getcwd);
use Carp;
use File::Path qw(make_path remove_tree);
use File::Slurp;

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
              dir      => ['./ftpserver', '/ftproot'],
              override => { 
                  ls => sub {
                      return qw(aaa bbb ccc);
                  },
              },
          },
      }
  );
  my $ftp = Test::Mock::Net::FTP->new('somehost.example.com');
  $ftp->login('user1', 'secret');
  $ftp->cwd('datadir');
  $ftp->get('file1');
  my @files = $ftp->ls();# => ('aaa', 'bbb', 'ccc');
  $ftp->quit();
  # or
  use Test::Mock::Net::FTP qw(intercept);
  some_method_using_ftp();

=head1 DESCRIPTION

Test::Mock::Net::FTP is Mock Object for Net::FTP. This module behave like FTP servers, but only use local filesystem.(not using socket).

=cut

my %mock_server;
my $cwd_when_prepared;

=head1 METHODS

=cut

=head2 mock_prepare( %params )

prepare FTP server in your local filesystem.

=cut

sub mock_prepare {
    my %args = @_;
    %mock_server = %args;
    $cwd_when_prepared = getcwd();
}

=head2 mock_pwd()

mock's current directory

=cut

sub mock_pwd {
    my ($self) = @_;
    return catdir($self->mock_physical_root, $self->_mock_cwd);
}

=head2 mock_physical_root()

mock's physical root directory

=cut

sub mock_physical_root {
    my ($self) = @_;
    return $self->{mock_physical_root};
}

=head2 mock_connection_mode()

return current connection mode (port or pasv)

=cut

sub mock_connection_mode {
    my ($self) = @_;

    return $self->{mock_connection_mode};
}

=head2 mock_port_no()

return current port no

=cut

sub mock_port_no {
    my ($self) = @_;

    return $self->{mock_port_no};
}

=head2 mock_transfer_mode()

return current transfer mode(ascii or binary)

=cut

sub mock_transfer_mode {
    my ($self) = @_;

    return $self->{mock_transfer_mode};
}

=head2 mock_command_history()

return command history

  my $ftp = Test::Mock::Net::FTP->new('somehost');
  $ftp->login('somehost', 'passwd');
  $ftp->ls('dir1');
  my @history = $ftp->mock_command_history();
  # =>  ( ['login', 'somehost', 'passwd'], ['ls', 'dir1']);

=cut

sub mock_command_history {
    my ($self) = @_;

    return @{ $self->{mock_command_history} };
}

sub _push_mock_command_history {
    my ($self, $method_name, @args) = @_;
    shift @args; #discard $self;
    push @{ $self->{mock_command_history} }, [$method_name, @args];
}

=head2 mock_clear_command_history()

clear command history

=cut

sub mock_clear_command_history {
    my ($self) = @_;

    $self->{mock_command_history} = [];
}


=head2 new( $host, %options )

create new instance

=cut

sub new {
    my ($class, $host, %opts ) = @_;
    return if ( !exists $mock_server{$host} );

    my ($connection_mode, $port_no) = _connection_mode_and_port_no(%opts);

    my $self = {
        mock_host            => $host,
        mock_physical_root   => '',
        mock_server_root     => '',
        mock_transfer_mode   => 'ascii',
        mock_connection_mode => $connection_mode,
        mock_port_no         => $port_no,
        message              => '',
        mock_command_history => [],
    };
    bless $self, $class;
}

sub _connection_mode_and_port_no {
    my (%opts) = @_;
    my $connection_mode = ((!defined $opts{Passive} && !defined $opts{Port} ) || !!$opts{Passive}) ? 'pasv' : 'port';
    my $port_no = $connection_mode eq 'pasv' ? ''
                                             : defined $opts{Port} ? $opts{Port}
                                                                   : '20';
    return ($connection_mode, $port_no);
}

=head2 login( $user, $password )

login mock FTP server. this method IS NOT allowed to be overridden.

=cut

sub login {
    my ($self, $user, $pass) = @_;
    $self->_push_mock_command_history('login', @_);

    if ( $self->_mock_login_auth( $user, $pass) ) {# auth success
        my $cwd = getcwd();
        chdir $cwd_when_prepared;# chdir for absolute path
        my $mock_server_for_user = $mock_server{$self->{mock_host}}->{$user};
        my $dir = $mock_server_for_user->{dir};
        $self->{mock_physical_root} = rel2abs($dir->[0]) if defined $dir->[0];
        $self->{mock_server_root}   = $dir->[1];
        $self->{mock_cwd}           = rootdir();
        $self->{mock_override}      = $mock_server_for_user->{override};
        chdir $cwd;
        return 1;
    }
    $self->{message} = 'Login incorrect.';
    return;
}

sub _mock_login_auth {
    my ($self, $user, $pass) = @_;

    my $server_user     = $mock_server{$self->{mock_host}}->{$user};
    return if !defined $server_user; #user not found

    my $server_password = $server_user->{password};
    return $server_password eq $pass;
}

=head2 authorize( [$auth, [$resp]] )

authorize.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub authorize {
    my ($self, $auth, $resp) = @_;

    $self->_push_mock_command_history('authorize', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{authorize} } if ( exists $self->{mock_override}->{authorize} );

    return $self->mock_default_authorize($auth, $resp);
}

=head2 mock_default_authorize( [$auth, [$resp]] )

default implementation for authorize. this method sholud be used in overridden method.

=cut

sub mock_default_authorize {
    my ($self, $auth, $resp) = @_;
    return 1;
}

=head2 site( @args )

execute SITE command. 
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub site {
    my ($self, @args) = @_;

    $self->_push_mock_command_history('site', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{site} } if ( exists $self->{mock_override}->{site} );

    return $self->mock_default_site(@args);
}

=head2 mock_default_site( @args )

default implementation for site. this method sholud be used in overridden method.

=cut

sub mock_default_site {
    my ($self, @args) = @_;
    return 1;
}

=head2 ascii()

enter ascii mode.
mock_transfer_mode() returns 'ascii'.
this methos is allowed to be overridden.

=cut

sub ascii {
    my ($self) = @_;

    $self->_push_mock_command_history('ascii', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{ascii} } if ( exists $self->{mock_override}->{ascii} );

    return $self->mock_default_ascii();
}

=head2 mock_default_ascii()

default implementation for ascii. this method sholud be used in overridden method.

=cut

sub mock_default_ascii {
    my ($self) = @_;
    $self->{mock_transfer_mode} = 'ascii';
}

=head2 binary()

enter binary mode.
mock_transfer_mode() returns 'binary'.
this methos is allowed to be overridden.

=cut

sub binary {
    my ($self) = @_;

    $self->_push_mock_command_history('binary', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{binary} } if ( exists $self->{mock_override}->{binary} );

    return $self->mock_default_binary();
}

=head2 mock_default_binary()

default implementation for binary. this method sholud be used in overridden method.

=cut

sub mock_default_binary {
    my ($self) = @_;
    $self->{mock_transfer_mode} = 'binary';
}

=head2 rename($oldname, $newname)

rename remote file.
this methos is allowed to be overridden.

=cut

sub rename {
    my ($self, $oldname, $newname) = @_;

    $self->_push_mock_command_history('rename', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{rename} } if ( exists $self->{mock_override}->{rename} );

    return $self->mock_default_rename($oldname, $newname)
}

=head2 mock_default_rename($oldname, $newname)

default implementation for rename. this method sholud be used in overridden method.

=cut

sub mock_default_rename {
    my ($self, $oldname, $newname) = @_;
    unless( CORE::rename $self->_abs_remote_file($oldname), $self->_abs_remote_file($newname) ) {
        $self->{message} = sprintf("%s: %s\n", $oldname, $!);
        return;
    }
}

=head2 delete( $filename )

delete remote file.
this methos is allowed to be overridden.

=cut

sub delete {
    my ($self, $filename) = @_;

    $self->_push_mock_command_history('delete', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{delete} } if ( exists $self->{mock_override}->{delete} );

    return $self->mock_default_delete($filename);
}

=head2 mock_default_delete( $filename )

default implementation for delete. this method sholud be used in overridden method.

=cut

sub mock_default_delete {
    my ($self, $filename) = @_;

    unless( unlink $self->_abs_remote_file($filename) ) {
        $self->{message} = sprintf("%s: %s\n", $filename, $!);
        return;
    }
}

=head2 cwd( $dir )

change (mock) server current directory
this methos is allowed to be overridden.

=cut

sub cwd {
    my ($self, $dirs) = @_;

    $self->_push_mock_command_history('cwd', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{cwd} } if ( exists $self->{mock_override}->{cwd} );

    return $self->mock_default_cwd($dirs);
}


=head2 mock_default_cwd( $dir )

default implementation for cwd. this method sholud be used in overridden method.

=cut

sub mock_default_cwd {
    my ($self, $dirs) = @_;

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

=head2 cdup()

change (mock) server directory to parent
this methos is allowed to be overridden.

=cut

sub cdup {
    my ($self) = @_;

    $self->_push_mock_command_history('cdup', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{cdup} } if ( exists $self->{mock_override}->{cdup} );

    $self->mock_default_cdup();
}

=head2 mock_default_cdup()

default implementation for cdup. this method sholud be used in overridden method.

=cut

sub mock_default_cdup {
    my ($self) = @_;
    my $backup_cwd = $self->_mock_cwd;
    $self->{mock_cwd} = dirname($self->_mock_cwd);# to updir
    return $self->_mock_check_pwd($backup_cwd);
}

=head2 pwd()

return (mock) server current directory
this methos is allowed to be overridden.

=cut

sub pwd {
    my ($self) = @_;

    $self->_push_mock_command_history('pwd', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{pwd} } if ( exists $self->{mock_override}->{pwd} );

    return $self->mock_default_pwd();
}

=head2 mock_default_pwd()

default implementation for pwd. this method sholud be used in overridden method.

=cut 

sub mock_default_pwd {
    my ($self) = @_;
    return catdir($self->{mock_server_root}, $self->_mock_cwd);
}

sub _mock_cwd_each {
    my ($self, $dir) = @_;

    if ( $dir eq '..' ) {
        $self->cdup();
    }
    else {
        $self->{mock_cwd} = catdir($self->_mock_cwd, $dir);
    }
}

# check if mock server directory "phisically" exists.
sub _mock_check_pwd {
    my ($self, $backup_cwd) = @_;

    if ( ! -d $self->mock_pwd ) {
        $self->{mock_cwd} = $backup_cwd;
        $self->{message} = 'Failed to change directory.';
        return 0;
    }
    return 1;
}

=head2 restart( $where )

restart. currently do_nothing
this methos is allowed to be overridden.

=cut

sub restart {
    my ($self, $where) = @_;

    $self->_push_mock_command_history('restart', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{restart} } if ( exists $self->{mock_override}->{restart} );

    return $self->mock_default_restart($where);
}

=head2 mock_default_restart( $where )

default implementation for restart. this method sholud be used in overridden method.

=cut

sub mock_default_restart {
    my ($self, $where) = @_;
    return 1;
}

=head2 rmdir( $dirname, $recursive_bool )

rmdir to remove (mock) server. when $recursive_bool is true, dir is recursively removed.
this methos is allowed to be overridden.

=cut

sub rmdir {
    my ($self, $dirname, $recursive_bool) = @_;

    $self->_push_mock_command_history('rmdir', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{rmdir} } if ( exists $self->{mock_override}->{rmdir} );

    return $self->mock_default_rmdir($dirname, $recursive_bool);
}

=head2 mock_default_rmdir( $dirname, $recursive_bool )

default implementation for rmdir. this method sholud be used in overridden method.

=cut

sub mock_default_rmdir {
    my ($self, $dirname, $recursive_bool) = @_;
    if ( !!$recursive_bool ) {
        unless( remove_tree( $self->_abs_remote_file($dirname) ) ) {
            $self->{message} = sprintf("%s: %s", $dirname, $!);
            return;
        }
    }
    else {
        unless( CORE::rmdir $self->_abs_remote_file($dirname) ) {
            $self->{message} = sprintf("%s: %s", $dirname, $!);
            return;
        }
    }
}

=head2 mkdir( $dirname, $recursive_bool )

mkdir to remove (mock) server. when $recursive_bool is true, dir is recursively create.
this methos is allowed to be overridden.

=cut

sub mkdir {
    my ($self, $dirname, $recursive_bool) = @_;

    $self->_push_mock_command_history('mkdir', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{mkdir} } if ( exists $self->{mock_override}->{mkdir} );

    return $self->mock_default_mkdir($dirname, $recursive_bool);
}

=head2 mock_default_mkdir( $dirname, $recursive_bool )

default implementation for mkdir. this method sholud be used in overridden method.

=cut

sub mock_default_mkdir {
    my ($self, $dirname, $recursive_bool) = @_;
    if ( !!$recursive_bool ) {
        unless( make_path( $self->_abs_remote_file($dirname) ) ) {
            $self->{message} = sprintf("%s: %s", $dirname, $!);
            return;
        }
    }
    else {
        unless( CORE::mkdir $self->_abs_remote_file($dirname) ) {
            $self->{message} = sprintf("%s: %s", $dirname, $!);
            return;
        }
    }
}

=head2 alloc( $size, [$record_size] )

alloc. 
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub alloc {
    my ($self, $size, $record_size) = @_;

    $self->_push_mock_command_history('alloc', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{alloc} } if ( exists $self->{mock_override}->{alloc} );

    return $self->mock_default_alloc($size, $record_size);
}

=head2 mock_default_alloc( $size, [$record_size] )

default implementation for alloc. this method sholud be used in overridden method.

=cut

sub mock_default_alloc {
    my ($self, $size, $record_size) = @_;
    return 1;
}

=head2 ls( [$dir] )

list file(s) in server directory.
this methos is allowed to be overridden.

=cut

sub ls {
    my ($self, $dir) = @_;

    $self->_push_mock_command_history('ls', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{ls} } if ( exists $self->{mock_override}->{ls} );

    # my $target_dir = $self->_remote_dir_for_dir($dir);
    # my @ls = split(/\n/, `ls $target_dir`);
    # my @result =  (defined $dir)? map{ catfile($dir, $_) } @ls : @ls;
    my @result = $self->mock_default_ls($dir);
    return @result if ( wantarray() );
    return \@result;
}

=head2 mock_default_ls( [$dir] )

default implementation for ls. this method sholud be used in overridden method.

=cut

sub mock_default_ls {
    my ($self, $dir) = @_;

    my $target_dir = $self->_remote_dir_for_dir($dir);
    my @ls = split(/\n/, `ls $target_dir`);
    my @result =  (defined $dir)? map{ catfile($dir, $_) } @ls : @ls;

    return @result if ( wantarray() );
    return \@result;
}

=head2 dir( [$dir] )

list file(s) with detail information(ex. filesize) in server directory.
this methos is allowed to be overridden.

=cut

sub dir {
    my ($self, $dir) = @_;

    $self->_push_mock_command_history('dir', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{dir} } if ( exists $self->{mock_override}->{dir} );

    my @dir = $self->mock_default_dir($dir);
    return @dir if ( wantarray() );
    return \@dir;
}

=head2 mock_default_dir( [$dir] )

default implementation for dir. this method sholud be used in overridden method.

=cut 

sub mock_default_dir {
    my ($self, $dir) = @_;
    my $target_dir = $self->_remote_dir_for_dir($dir);
    my @dir = split(/\n/, `ls -l $target_dir`);
    shift @dir if ( $dir[0] !~ /^[-rxwtTd]{10}/ ); #remove like "total xx"

    return @dir if ( wantarray() );
    return \@dir;
}

=head2 get( $remote_file, [$local_file] )

get file from mock FTP server
this methos is allowed to be overridden.

=cut

sub get {
    my($self, $remote_file, $local_file) = @_;

    $self->_push_mock_command_history('get', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{get} } if ( exists $self->{mock_override}->{get} );

    return $self->mock_default_get($remote_file, $local_file);
}

=head2 mock_default_get( $remote_file, [$local_file] )

default implementation for get. this method sholud be used in overridden method.

=cut

sub mock_default_get {
    my($self, $remote_file, $local_file) = @_;
    $local_file = basename($remote_file) if ( !defined $local_file );
    unless( copy( $self->_abs_remote_file($remote_file),
                  $self->_abs_local_file($local_file) )   ) {
        $self->{message} = sprintf("%s: %s", $remote_file, $!);
        return;
    }

    return $local_file;
}


=head2 put( $local_file, [$remote_file] )

put a file to mock FTP server
this methos is allowed to be overridden.

=cut

sub put {
    my ($self, $local_file, $remote_file) = @_;

    $self->_push_mock_command_history('put', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{put} } if ( exists $self->{mock_override}->{put} );

    return $self->mock_default_put($local_file, $remote_file);
}

=head2 mock_default_put( $local_file, [$remote_file] )

default implementation for put. this method sholud be used in overridden method.

=cut

sub mock_default_put {
    my ($self, $local_file, $remote_file) = @_;
    $remote_file = basename($local_file) if ( !defined $remote_file );
    unless ( copy( $self->_abs_local_file($local_file),
                   $self->_abs_remote_file($remote_file) ) ) {
        carp "Cannot open Local file $remote_file: $!";
        return;
    }

    return $remote_file;
}

=head2 put_unique( $local_file, [$remote_file] )

same as put() but if same file exists in server. rename to unique filename
(in this module, simply add suffix .1(.2, .3...). and suffix is limited to 1024)
this methos is allowed to be overridden.

=cut

sub put_unique {
    my ($self, $local_file, $remote_file) = @_;

    $self->_push_mock_command_history('put_unique', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{put_unique} } if ( exists $self->{mock_override}->{put_unique} );

    return $self->mock_default_put_unique($local_file, $remote_file);
}

sub _unique_new_name {
    my ($self, $remote_file) = @_;

    my $suffix = "";
    my $newfile = $remote_file;
    for ( my $i=1; $i<=1024; $i++ ) {
        last if ( !-e $self->_abs_remote_file($newfile) );
        $suffix = ".$i";
        $newfile = $remote_file . $suffix;
    }
    return $newfile;
}

=head2 mock_default_put_unique( $local_file, [$remote_file] )

default implementation for put_unique. this method sholud be used in overridden method.

=cut

sub mock_default_put_unique {
    my ($self, $local_file, $remote_file) = @_;
    $remote_file = basename($local_file) if ( !defined $remote_file );

    my $newfile = $self->_unique_new_name($remote_file);
    unless ( copy( $self->_abs_local_file($local_file),
                   $self->_abs_remote_file($newfile) ) ) {
        carp "Cannot open Local file $remote_file: $!";
        $self->{mock_unique_name} = undef;
        return;
    }
    $self->{mock_unique_name} = $newfile;
}


=head2 append( $local_file, [$remote_file] )

put a file to mock FTP server. if file already exists, append file contents in server file.
this methos is allowed to be overridden.

=cut

sub append {
    my ($self, $local_file, $remote_file) = @_;

    $self->_push_mock_command_history('append', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{append} } if ( exists $self->{mock_override}->{append} );

    return $self->mock_default_append($local_file, $remote_file);
}

=head2 mock_default_append( $local_file, [$remote_file] )

default implementation for append. this method sholud be used in overridden method.

=cut

sub mock_default_append {
    my ($self, $local_file, $remote_file) = @_;

    $remote_file = basename($local_file) if ( !defined $remote_file );
    my $local_contents = eval { read_file( $self->_abs_local_file($local_file) ) };
    if ( $@ ) {
        carp "Cannot open Local file $remote_file: $!";
        return;
    }
    write_file( $self->_abs_remote_file($remote_file), { append => 1 }, $local_contents);
}

=head2 unique_name()

return unique filename when put_unique() called.
this methos is allowed to be overridden.

=cut

sub unique_name {
    my ($self) = @_;

    $self->_push_mock_command_history('unique_name', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{unique_name} } if ( exists $self->{mock_override}->{unique_name} );

    return $self->mock_default_unique_name();
}

=head2 mock_default_unique_name()

default implementation for unique_name. this method sholud be used in overridden method.

=cut

sub mock_default_unique_name {
    my($self) = @_;

    return $self->{mock_unique_name};
}

=head2 mdtm( $file )

returns file modification time in remote (mock) server. but currently always return 1
this methos is allowed to be overridden.

=cut

sub mdtm {
    my ($self, $filename) = @_;

    $self->_push_mock_command_history('mdtm', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{mdtm} } if ( exists $self->{mock_override}->{mdtm} );

    return $self->mock_default_mdtm($filename);
}

=head2 mock_default_mdtm()

default implementation for mdtm. this method sholud be used in overridden method.

=cut

sub mock_default_mdtm {
    my ($self, $filename) = @_;
    return 1;
}

=head2 size( $file )

returns filesize in remote (mock) server. but currently always return 1
this methos is allowed to be overridden.

=cut

sub size {
    my ($self, $filename) = @_;

    $self->_push_mock_command_history('size', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{size} } if ( exists $self->{mock_override}->{size} );

    return $self->mock_default_size($filename);
}

=head2 mock_default_size( $file )

default implementation for size. this method sholud be used in overridden method.

=cut

sub mock_default_size {
    my ($self, $filename) = @_;

    return 1;
}

=head2 supported( $cmd )

supported. 
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub supported {
    my ($self, $cmd) = @_;

    $self->_push_mock_command_history('supported', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{supported} } if ( exists $self->{mock_override}->{supported} );

    return $self->mock_default_supported($cmd);
}

=head2 mock_default_supported( $cmd )

default implementation for supported. this method sholud be used in overridden method.

=cut

sub mock_default_supported {
    my ($self, $cmd) = @_;
    return 1;
}


=head2 hash( [$filehandle_glob_ref], [$bytes_per_hash_mark] )

hash.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub hash {
    my ($self, $filehandle_glob_ref, $bytes_per_hash_mark) = @_;

    $self->_push_mock_command_history('hash', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{hash} } if ( exists $self->{mock_override}->{hash} );

    return $self->mock_default_hash($filehandle_glob_ref, $bytes_per_hash_mark);
}

=head2 mock_default_hash( [$filehandle_glob_ref], [$bytes_per_hash_mark] )

default implementation for hash. this method sholud be used in overridden method.

=cut

sub mock_default_hash {
    my ($self, $filehandle_glob_ref, $bytes_per_hash_mark) = @_;
    return 1;
}


=head2 feature( $cmd )

reature. currently returns list of $cmd.
this method is allowed to be overridden.

=cut

sub feature {
    my ($self, $cmd) = @_;

    $self->_push_mock_command_history('feature', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{feature} } if ( exists $self->{mock_override}->{feature} );

    return $self->mock_default_feature($cmd);
}

=head2 mock_default_feature( $cmd )

default implementation for feature. this method sholud be used in overridden method.

=cut

sub mock_default_feature {
    my ($self, $cmd) = @_;
    return ($cmd);
}

=head2 nlst( [$dir] )

nlst.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub nlst {
    my ($self, $dir) = @_;

    $self->_push_mock_command_history('nlst', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{nlst} } if ( exists $self->{mock_override}->{nlst} );

    return $self->mock_default_nlst($dir);
}

=head2 mock_default_nlst( [$dir] )

default implementation for nlst. this method sholud be used in overridden method.

=cut

sub mock_default_nlst {
    my ($self, $dir) = @_;
    return 1;
}

=head2 list( [$dir] )

list.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub list {
    my ($self, $dir) = @_;

    $self->_push_mock_command_history('list', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{list} } if ( exists $self->{mock_override}->{list} );

    return $self->mock_default_list($dir);
}

=head2 mock_default_list( [$dir] )

default implementation for list. this method sholud be used in overridden method.

=cut

sub mock_default_list {
    my ($self, $dir) = @_;
    return 1;
}

=head2 retr( $file )

retr.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub retr {
    my ($self, $file) = @_;

    $self->_push_mock_command_history('retr', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{retr} } if ( exists $self->{mock_override}->{retr} );

    return $self->mock_default_retr($file);
}

=head2 mock_default_retr($file)

default implementation for retr. this method sholud be used in overridden method.

=cut

sub mock_default_retr {
    my ($self, $file) = @_;
    return 1;
}

=head2 stor( $file )

stor.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub stor {
    my ($self, $file) = @_;

    $self->_push_mock_command_history('stor', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{stor} } if ( exists $self->{mock_override}->{stor} );

    return $self->mock_default_stor($file);
}

=head2 mock_default_stor( $file )

default implementation for stor. this method sholud be used in overridden method.

=cut

sub mock_default_stor {
    my ($self, $file) = @_;
    return 1;
}

=head2 stou( $file )

stou. currently do_nothing.

=cut

sub stou {
    my ($self, $file) = @_;

    $self->_push_mock_command_history('stou', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{stou} } if ( exists $self->{mock_override}->{stou} );

    return $self->mock_default_stou($file);
}

=head2 mock_default_stou( $file )

default implementation for stor. this method sholud be used in overridden method.

=cut

sub mock_default_stou {
    my ($self, $file) = @_;
    return 1;
}

=head2 appe( $file )

appe.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub appe {
    my ($self, $file) = @_;

    $self->_push_mock_command_history('appe', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{appe} } if ( exists $self->{mock_override}->{appe} );

    return $self->mock_default_appe($file);
}

=head2 mock_default_appe( $file )

default implementation for appe. this method sholud be used in overridden method.

=cut

sub mock_default_appe {
    my ($self, $file) = @_;
    return 1;
}

=head2 port( $port_no )

specify data connection to port-mode.

after called this method, mock_connection_mode() returns 'port' and 
mock_port_no() returns specified $port_no.

this methos is allowed to be overridden.

=cut

sub port {
    my ($self, $port_no) = @_;

    $self->_push_mock_command_history('port', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{port} } if ( exists $self->{mock_override}->{port} );

    return $self->mock_default_port($port_no);
}

=head2 mock_default_port( $port_no )

default implementation for port. this method sholud be used in overridden method.

=cut

sub mock_default_port {
    my ($self, $port_no) = @_;
    $self->{mock_connection_mode} = 'port';
    $self->{mock_port_no} = $port_no;
}

=head2 pasv()

specify data connection to passive-mode.
after called this method, mock_connection_mode() returns 'pasv' and
mock_port_no() returns ''

this methos is allowed to be overridden.

=cut

sub pasv {
    my ($self) = @_;

    $self->_push_mock_command_history('pasv', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{pasv} } if ( exists $self->{mock_override}->{pasv} );

    return $self->mock_default_pasv();
}

=head2 mock_default_pasv()

default implementation for pasv. this method sholud be used in overridden method.

=cut

sub mock_default_pasv {
    my ($self) = @_;
    $self->{mock_connection_mode} = 'pasv';
    $self->{mock_port_no} = '';
}

=head2 pasv_xfer( $src_file, $dest_server, [$dest_file] )

pasv_xfer.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub pasv_xfer {
    my ($self) = @_;

    $self->_push_mock_command_history('pasv_xfer', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{pasv_xfer} } if ( exists $self->{mock_override}->{pasv_xfer} );

    return $self->mock_default_pasv_xfer();
}

=head2 mock_default_pasv_xfer( $src_file, $dest_server, [$dest_file] )

default implementation for psv_xfer. this method sholud be used in overridden method.

=cut

sub mock_default_pasv_xfer {
    my ($self) = @_;
    return 1;
}


=head2 pasv_xfer_unique( $src_file, $dest_server, [$dest_file] )

pasv_xfer_unique.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub pasv_xfer_unique {
    my ($self) = @_;

    $self->_push_mock_command_history('pasv_xfer_unique', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{pasv_xfer_unique} } if ( exists $self->{mock_override}->{pasv_xfer_unique} );

    return $self->mock_default_pasv_xfer_unique();
}

=head2 mock_default_pasv_xfer_unique( $src_file, $dest_server, [$dest_file] )

default implementation for psv_xfer_unique. this method sholud be used in overridden method.

=cut

sub mock_default_pasv_xfer_unique {
    my ($self) = @_;
    return 1;
}

=head2 pasv_wait( $non_pasv_server )

pasv_wait.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub pasv_wait {
    my ($self) = @_;

    $self->_push_mock_command_history('pasv_wait', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{pasv_wait} } if ( exists $self->{mock_override}->{pasv_wait} );

    return $self->mock_default_pasv_wait();
}

=head2 mock_default_pasv_wait( $non_pasv_server )

default implementation for pasv_wait. this method sholud be used in overridden method.

=cut

sub mock_default_pasv_wait {
    my ($self) = @_;
    return 1;
}


=head2 abort()

abort.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub abort {
    my ($self) = @_;

    $self->_push_mock_command_history('abort', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{abort} } if ( exists $self->{mock_override}->{abort} );

    return $self->mock_default_abort();
}

=head2 mock_default_abort()

default implementation for abort. this method sholud be used in overridden method.

=cut

sub mock_default_abort {
    my ($self) = @_;
    return 1;
}

=head2 quit()

quit.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub quit {
    my ($self) = @_;

    $self->_push_mock_command_history('quit', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{quit} } if ( exists $self->{mock_override}->{quit} );

    return $self->mock_default_quit();
}

=head2 mock_default_quit()

default implementation for quit. this method sholud be used in overridden method.

=cut

sub mock_default_quit {
    my ($self) = @_;
    return 1;
}


=head2 quot( $cmd, @args )

quot.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub quot {
    my ($self) = @_;

    $self->_push_mock_command_history('quot', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{quot} } if ( exists $self->{mock_override}->{quot} );

    return $self->mock_default_quot();
}

=head2 mock_default_quot( $cmd, @args )

default implementation for quot. this method sholud be used in overridden method.

=cut

sub mock_default_quot {
    my ($self) = @_;
    return 1;
}


=head2 close()

close connection mock FTP server.
default implementation is 'do nothing'. this method is allowed to be overridden.

=cut

sub close {
    my ($self) = @_;

    $self->_push_mock_command_history('close', @_);
    $self->{message} = '';
    goto &{ $self->{mock_override}->{close} } if ( exists $self->{mock_override}->{close} );

    return $self->mock_default_close();
}

=head2 mock_default_close()

default implementation for close. this method sholud be used in overridden method.

=cut

sub mock_default_close {
    my ($self) = @_;
    return 1;
}


sub _remote_dir_for_dir {
    my ($self, $dir) = @_;

    $dir =~ s/^$self->{mock_server_root}// if (defined $dir && $dir =~ /^$self->{mock_server_root}/ ); #absolute path
    $dir = "" if !defined $dir;
    return catdir($self->mock_pwd, $dir);
}

sub _remote_dir_for_file {
    my ($self, $remote_file) = @_;

    my $remote_dir = dirname( $remote_file ) eq curdir() ? $self->{mock_cwd} : dirname( $remote_file ) ;
    $remote_dir =~ s/^$self->{mock_server_root}// if ( $remote_file =~ /^$self->{mock_server_root}/ );
    return $remote_dir;
}

sub _abs_remote_file {
    my ($self, $remote_file) = @_;

    my $remote_dir = $self->_remote_dir_for_file($remote_file);
    $remote_dir = "" if !defined $remote_dir;
    return catfile($self->{mock_physical_root}, $remote_dir, basename($remote_file))
}

sub _abs_local_file {
    my ($self, $local_file) = @_;

    my $root = rootdir();
    return $local_file if ( $local_file =~ m{^$root} );

    my $local_dir = dirname( $local_file ) eq curdir() ? getcwd() : dirname( $local_file );
    $local_dir = "" if !defined $local_dir;
    return catfile($local_dir, basename($local_file));
}

=head2 message()

return messages from mock FTP server
this method is allowed to be overridden.

=cut

sub message {
    my ($self) = @_;

    $self->_push_mock_command_history('message', @_);
    goto &{ $self->{mock_override}->{message} } if ( exists $self->{mock_override}->{message} );

    return $self->mock_default_message();
}

=head2 mock_default_message()

default implementation for message. this method sholud be used in overridden method.

=cut

sub mock_default_message {
    my ($self) = @_;
    return $self->{message};
}

sub _mock_cwd {
    my ($self) = @_;
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
