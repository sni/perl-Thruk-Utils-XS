#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Benchmark qw(:all);

use lib 'blib/lib';
use lib 'blib/arch';

use Test::More tests => 2;
use_ok('Thruk::Utils::XS');
use_ok('Monitoring::Availability::Logs');


my $results = cmpthese(-1, {
    'Monitoring::Availability::Logs' => sub { my $line = "[1263423600] SERVICE ALERT: i0test_host_132;i0test_random_18;CRITICAL;HARD;1;mo CRITICAL: random servicecheck critical"; my $r = Monitoring::Availability::Logs::parse_line($line); },
    'Thruk::Utils::XS'               => sub { my $line = "[1263423600] SERVICE ALERT: i0test_host_132;i0test_random_18;CRITICAL;HARD;1;mo CRITICAL: random servicecheck critical"; my $r = Thruk::Utils::XS::parse_line($line); },
});
