#!/usr/bin/perl
# vim: set ft=perl:

# This series of tests tests the time parsing stuff.  That's all.

use Net::Meerkat;
use Test::More;

my $m = Net::Meerkat->new;
my @tests = (
    [ '7DAY'        => '7DAY' ],
    [ '7 days'      => '7DAY' ], 
    [ '2 weeks'     => '14DAY' ],
    [ '160 minutes' => '160MINUTE' ],
    [ '22 hours'    => '22HOUR' ],
    [ 'ALL'         => 'ALL' ],
    [ 'all'         => 'ALL' ],
    [ 'All'         => 'ALL' ],
    [ '1 Week'      => '7DAY' ],
);

plan tests => scalar @tests;

for (@tests) {
    my ($set, $expected) = @$_;
    $m->t($set);
    is($m->t(), $expected, "'$set' => '$expected'");
}

