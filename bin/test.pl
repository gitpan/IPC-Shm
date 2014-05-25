#!/usr/bin/perl
use warnings;
use strict;
use lib '.';

use IPC::Shm;

my $variable : shm = "onetwothree";

print "variable1: ", $variable, "\n";

$variable = 'fourfivesix';

print "variable2: ", $variable, "\n";


