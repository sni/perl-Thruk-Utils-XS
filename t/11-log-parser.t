#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

use lib 'blib/lib';
use lib 'blib/arch';

use Test::More tests => 76;
use_ok('Thruk::Utils::XS');
use_ok('Monitoring::Availability::Logs');

while(my $line = <DATA>) {
    my $dup = $line;
    my $data1 = Thruk::Utils::XS::parse_line($line);
    is($line, $dup, "line is unchanged");
    chomp($dup);
    my $data2 = Monitoring::Availability::Logs::parse_line($dup);
    is_deeply($data2, $data1, "xs module returns the same data") or print STDERR Dumper("Thruk::Utils::XS:", $data1, "Monitoring::Availability::Logs:", $data2);
}


__DATA__
[1260711580] Local time is Sun Dec 13 14:39:40 CET 2009
[1260711580] Nagios 3.0.6 starting... (PID=12480)
[1260711581] Finished daemonizing... (New PID=12484)
[1260715790] Error: Unable to create temp file for writing status data!
[1260715801] Successfully shutdown... (PID=12502)
[1260716221] Lockfile '/opt/projects/nagios/n1/var/nagios3.pid' looks like its already held by another instance of Nagios (PID 13226).  Bailing out...
[1260722815] Warning: The check of host 'test_host_020' looks like it was orphaned (results never came back).  I'm scheduling an immediate check of the host...
[1260725492] Warning: Check result queue contained results for host 'test_host_105', but the host could not be found!  Perhaps you forgot to define the host in your config files?
[1260725492] Warning: Check result queue contained results for service 'test_ok_04' on host 'test_host_131', but the service could not be found!  Perhaps you forgot to define the service in your config files?
[1260971246] PROGRAM_RESTART event encountered, restarting...
[1261050819] PASSIVE HOST CHECK: n1_test_router_00;0;blah blah blah
[1261685289] SERVICE NOTIFICATION: test_contact;i0test_host_180;i0test_random_18;OK;notify-service;mo REVOVERED: random servicecheck recovered
[1261686379] SERVICE FLAPPING ALERT: i0test_host_135;i0test_flap_01;STARTED; Service appears to have started flapping (24.2% change >= 20.0% threshold)
[1261686484] SERVICE ALERT: i0test_host_132;i0test_random_18;CRITICAL;HARD;1;mo CRITICAL: random servicecheck critical
[1261687372] HOST ALERT: i0test_host_198;DOWN;HARD;1;mo DOWN: random hostcheck: parent host down
[1261687372] HOST NOTIFICATION: test_contact;i0test_host_198;DOWN;notify-host;mo DOWN: random hostcheck: parent host down
[1261687373] HOST FLAPPING ALERT: i0test_host_198;STARTED; Host appears to have started flapping (20.3% change > 20.0% threshold)
[1262850812] Caught SIGSEGV, shutting down...
[1262850822] HOST DOWNTIME ALERT: localhost;STARTED; Host has entered a period of scheduled downtime
[1262850822] SERVICE DOWNTIME ALERT: localhost;test;STARTED; Service has entered a period of scheduled downtime
[1263042133] EXTERNAL COMMAND: ENABLE_NOTIFICATIONS;
[1263423600] CURRENT HOST STATE: i0test_router_19;UP;HARD;1;mo OK: random hostcheck ok
[1263423600] CURRENT SERVICE STATE: i0test_host_199;i0test_warning_18;WARNING;HARD;3;mo WARNING: warning servicecheck
[1263423600] LOG ROTATION: DAILY: DAILY
[1263457861] Auto-save of retention data completed successfully.
[1263458022] Caught SIGTERM, shutting down...
[1263648166] LOG VERSION: 2.0
[1262991600] TIMEPERIOD TRANSITION: workhours;-1;1
[1262991630] TIMEPERIOD TRANSITION: workhours;1;0
[1262991640] SERVICE ALERT: testhost;testservice;CRITICAL;HARD;1;service is down
[1262991700] TIMEPERIOD TRANSITION: workhours;0;1
[1262991710] SERVICE ALERT: testhost;testservice;OK;HARD;1;service is ok
[1261685289] SERVICE NOTIFICATION: test_contact;i0test_host_180;i0test_random_18;OK;notify-service;mo REVOVERED: random servicecheck recovered
[1261687372] HOST NOTIFICATION: test_contact;i0test_host_198;DOWN;notify-host;mo DOWN: random hostcheck: parent host down
[1364135381] Event broker module '/usr/lib64/mod_gearman/mod_gearman.o' initialized successfully.
[1264111946] SERVICE ALERT: n0_test_host_000;n0_test_pending_01;WARNING;SOFT;1;warn
[1264111946] HOST ALERT: n0_test_host_000;DOWN;SOFT;1;down
