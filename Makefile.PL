use strict;
use ExtUtils::MakeMaker;

my %PREREQ_PM = (
    'URI'         => undef,
    'LWP::Simple' => undef,
    'URI::Escape' => undef,
);

my %clean = (
    FILES => '$(DISTVNAME).tar$(SUFFIX) *.asc distdir',
);

my %macro = (
    'GPG'    => 'gpg',
    'AUTHOR' => 'darren@cpan.org',
    'SIGN'   => '--detach-sign --armor',
);


WriteMakefile(
    'NAME'          => 'Net::Meerkat',
    'VERSION_FROM'  => 'Meerkat.pm',
    'AUTHOR'        => 'darren chamberlain <darren@cpan.org>',
    'PREREQ_PM'     => \%PREREQ_PM,
    'macro'         => \%macro,
    'clean'         => \%clean,
);

package MY;
sub dist_dir {
    my $self = shift;
    my $stuff = $self->SUPER::dist_dir(@_);

    return "$stuff\ttouch distdir\n\n";
}

sub postamble {
    return <<'P';
distsign :: $(DISTVNAME).tar$(SUFFIX)
	$(GPG) $(SIGN) -u $(AUTHOR) $(DISTVNAME).tar$(SUFFIX)
	@cat $(DISTVNAME).tar$(SUFFIX).asc
P
}
