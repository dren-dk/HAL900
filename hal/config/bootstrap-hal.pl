#!/usr/bin/perl
use strict;
use warnings;
use lib "/home/hal/hal/pm";
use HAL;
use HAL::UI;

HAL::UI::bootStrap({
    root=>"/home/hal/hal",
    test=>1,
    salt=>'345klj56kl',
    db=>'dbi:Pg:dbname=hal;port=5432'
});

1;
