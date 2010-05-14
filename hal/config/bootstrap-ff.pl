#!/usr/bin/perl
use strict;
use warnings;
use lib "/home/ff/projects/osaa/hal/pm";
use HAL;
use HAL::UI;

setTestMode(1);
setHALRoot("/home/ff/projects/osaa/hal");
HAL::UI::bootStrap();

1;
