#!/usr/bin/perl
# vim: set ft=perl:

# This series of tests tests the get() method's ability to write
# to arbitary things.
# NOTE: This test requires an actual fetch of live data.

use IO::File;
use Net::Meerkat;
use POSIX qw(tmpnam);
use Test::More;

my $m = Net::Meerkat->new(flavor => "minimal");
my ($data, @data, $fh, $fname);
my @cleanup;
local *DATA;

eval {
    local $SIG{ALRM} = sub { die "alarm\n"; };
    alarm 5;
    $m->get();  # This is just to test whether we
                # are online; if not, skip all the
                # rest of the tests.
    alarm 0;
};
if ($@ and $@ eq 'alarm') {
    skip_all => 'No network!';
    exit(0);
} else {
    plan tests => 8;
}

# Test 1 => Return data
ok($m->get(), "get()");

# Test 2 => put into scalar
$m->get(\$data);
ok($data, 'get(\$data)');

# Test 3 => Reference to array
$m->get(\@data);
ok(@data, 'get(\@data)');
ok($data[0], '$data[0]');

# Test 4, 5 => Append
$m->get(\@data);
is(scalar @data, 2, 'Append to array');
ok($data[1], '$data[1]');

SKIP: {
    $fname = tmpnam();
    push @cleanup, $fname;
    unless (open DATA, $fname) {
        skip 1 => "Can't open tmp file $fname: $!";
    }
    $m->get(\*DATA);
    close DATA;
    ok(-s $fname, "Writing to GLOB");
}

SKIP: {
    # Test 6 => object that UNIVERSAL::can("print")
    $fname = tmpnam();
    push @cleanup, $fname;
    $fh = IO::File->new(">$fname")
        or skip 1 => "Can't open tmpfile $fname: $!";
    $m->get($fh);
    $fh->close();
ok(-s $fname, "Passing object that can print");
}

SKIP: {
    # Test 7 => plain old filename
    $fname = tmpnam();
    push @cleanup, $fname;
    $m->get($fname);
    ok(-s $fname, "Passing filename (string)");
}


# Final stuff: cleanup
for $fname (@cleanup) {
    unlink $fname;
}
