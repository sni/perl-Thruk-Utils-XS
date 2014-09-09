# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Thruk-Utils-XS.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 6;
BEGIN { use_ok('Thruk::Utils::XS') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $res;
$res = Thruk::Utils::XS::pool_do(10, ["/tmp/live6.sock", "GET status", "/tmp/live6.sock", "GET timeperiods"]);
is(ref $res, 'ARRAY', 'list with 2 requests ref');
is(scalar @{$res}, 2, 'list with 2 requests size');
#use Data::Dumper; print STDERR Dumper($res);

$res = Thruk::Utils::XS::pool_do(10, ["/tmp/live6.sock", "GET status"]);
is(ref $res, 'ARRAY', 'list with 1 request ref');
is(scalar @{$res}, 1, 'list with 1 request size');
#use Data::Dumper; print STDERR Dumper($res);

$res = Thruk::Utils::XS::pool_do(10, []);
is($res, undef, 'empty list');

