#!/usr/bin/env perl

use strict;
use warnings;
use IO::Socket::UNIX qw( SOCK_STREAM SOMAXCONN );
use File::Temp;
use Time::HiRes qw/usleep/;

use Test::More tests => 11;
BEGIN { use_ok('Thruk::Utils::XS') };

#########################
# start test socket
# get a temp file from File::Temp and replace it with our socket
my $fh = File::Temp->new(UNLINK => 0);
my $socket_path = $fh->filename;
unlink($socket_path);
my $pid = fork();
die("cannot fork") unless defined $pid;
if(!$pid) {
    Test::More->builder->no_ending(1);
    create_socket($socket_path);
    exit;
}

# wait for our socket
for(1...100) {
    last if -e $socket_path;
    usleep(50000);
}
ok(-e $socket_path, 'socket '.$socket_path.' exists');

#########################
# real tests
my $res;
$res = Thruk::Utils::XS::socket_pool_do(10, [0, 'testkey1', $socket_path, "GET status",
                                             0, 'testkey2', $socket_path, "GET status",
                                            ]);
is(ref $res, 'ARRAY', 'list with 2 requests ref');
is(scalar @{$res}, 2, 'list with 2 requests size');
is($res->[0]->{'success'}, 1, 'result is a success');
is($res->[0]->{'num'}, 0, 'result got a number');
like($res->[0]->{'key'}, "/^testkey/", 'result got a key');
like($res->[0]->{'result'}, "/total:/", 'result got data');

$res = Thruk::Utils::XS::socket_pool_do(10, [0, 'testkey1', $socket_path, "GET status"]);
is(ref $res, 'ARRAY', 'list with 1 request ref');
is(scalar @{$res}, 1, 'list with 1 request size');

$res = Thruk::Utils::XS::socket_pool_do(10, []);
is($res, undef, 'empty list');

kill('INT', $pid);
unlink($socket_path);



#########################
# SUBS
#########################
# test socket server
sub create_socket {
    my $socket_path = shift;
    my $listener;

    $listener = IO::Socket::UNIX->new(
                                        Type    => SOCK_STREAM,
                                        Listen  => SOMAXCONN,
                                        Local   => $socket_path,
                                    ) or die("failed to open $socket_path as test socket: ".$!);
    while( my $socket = $listener->accept() or die('cannot accept: $!') ) {
        my $recv = "";
        while(<$socket>) { $recv .= $_; last if $_ eq "\n" }
        my $data;
        my $status = 200;
        if($recv =~ m/^GET\ status/mx) {
            $data = "{total:0,data:[]}\n";
        }
        my $content_length = sprintf("%11s", length($data));
        print $socket $status." ".$content_length."\n";
        print $socket $data;
        close($socket);
    }
    unlink($socket_path);
}
