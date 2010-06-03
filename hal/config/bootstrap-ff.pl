#!/usr/bin/perl
use strict;
use warnings;
use lib "/home/ff/projects/osaa/hal/pm";
use HAL;
use HAL::UI;

HAL::UI::bootStrap({
    root=>"/home/ff/projects/osaa/hal",
    test=>1,
    salt=>'345klj56kl',
    db=>'dbi:Pg:dbname=hal;port=5433',
});

1;
