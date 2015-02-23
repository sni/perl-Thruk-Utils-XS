#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;

use lib 'blib/lib';
use lib 'blib/arch';

use_ok('Thruk::Utils::XS');
