#!/usr/bin/perl
# vim: set ft=perl:

# This series of tests tests that an instance has the correct
# parameters and so on, based on the methods called.

use Net::Meerkat;
use Test::More;

plan tests => 5;

my ($m, $server, $url);
$server = $Net::Meerkat::MEERKAT_SERVER;

# Test 1 => No options, default server
$m = Net::Meerkat->new();
is($m->url, $server, "No parameters");

# Test 2 => No options, different server
{ 
    local $Net::Meerkat::MEERKAT_SERVER = "http://meerkat.sevenroot.org/";
    is($m->url, "http://meerkat.sevenroot.org/", "No parameters, different default server");
}

# Test 3 => Some options
$m->search_what("title");
$m->search_for("perl");
$url = $m->url();
is($url, "$server?s=perl&sw=title", $url);

# Test 4 => Options, set a flavor
$m->flavor("ns3");
$url = $m->url();
is($url, "$server?_fl=ns3&s=perl&sw=title", $url);

# Test 5 => Options, with a flavor, duplicate search_for
$m->search_for("apache");
$url = $m->url();
is($url, "$server?_fl=ns3&s=apache&sw=title", $url);
