package Net::Meerkat;

# -------------------------------------------------------------------
# $Id: Meerkat.pm,v 1.6 2003/01/08 18:48:38 darren44 Exp $
# -------------------------------------------------------------------
# Net::Meerkat - Interface to Meerkat
#
# Copyright (C) 2001 darren chamberlain <darren@cpan.org>
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
# 
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software. If not, write to the Free Software
# Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
# -------------------------------------------------------------------

use strict;
use vars qw($VERSION $SEPARATOR $MEERKAT_SERVER);

$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d)\.(\d+)/;
$SEPARATOR = "&";   # PHP doesn't seem to understand ; as separator.
$MEERKAT_SERVER = q(http://meerkat.oreillynet.com/)
    unless defined $MEERKAT_SERVER;

use overload '""' => \&url;

use constant BOOLEAN    => 1;
use constant STRING     => 2;

use LWP::Simple qw($ua);
use IO::File;
use URI;
use URI::Escape;

my %flavors = map { $_ => 1 }
    qw(meerkat tofeerkat minimal rss rss10 xml js ns3 php);

# ----------------------------------------------------------------------
# search_for($text)
# search_for(qr(foo))
#
# Sets the search terms for the url.  Can be set to a regexp.
# ----------------------------------------------------------------------
sub s {
    my $self = shift;

    if (@_) {
        my $search_for = shift;
        if (ref $search_for eq 'Regexp') {
            $self->{'s'} = uri_escape("/" . $search_for . "/");
        }
        else {
            $self->{'s'} = uri_escape($search_for);
        }
    }

    return $self->{'s'} if defined $self->{'s'};
    return;
}
*search_for = *search_for = *s;

# ----------------------------------------------------------------------
# search_what(@_)
#
# Specify the fields to search over; default it title and description.
# ----------------------------------------------------------------------
my %search_what = map { $_ => 1 }
    qw( title description dc_title dc_creator dc_subject
        dc_description dc_publisher dc_contributor dc_type
        dc_format dc_identifier dc_source dc_language
        dc_relation dc_coverage dc_rights );
sub sw {
    my $self = shift;

    if (@_) {
        $self->{'sw'} = join  ',', grep { defined $search_what{$_} } @_;
    }

    return $self->{'sw'} if defined $self->{'sw'};
    return "title,description";
}
*search_what = *search_what = *sw;

# ----------------------------------------------------------------------
# channel($c)
#
# Get/set the channel for the request.  If setting, it must be passed
# an integer.
# ----------------------------------------------------------------------
sub c { shift->_int_accessor('c', @_) }
*channel = *channel = *c;

# ----------------------------------------------------------------------
# time_period($tp)
#
# How far back Meerkat should look for stories.  Should be in the form
# (\d+(MINUTE|HOUR|DAY)|ALL)
# ----------------------------------------------------------------------
sub t {
    my $self = shift;

    if (@_) {
        my $tp = uc shift;
        if ($tp =~ /^ALL$/i) {
            $self->{'t'} = 'ALL';
        }
        elsif ($tp =~ /^(\d+)\s*(MINUTE|HOUR|DAY)S?$/i) {
            $self->{'t'} = $1 . uc($2);
        }
        elsif ($tp =~ /^(\d+)\s*WEEKS?/i) {
            $self->{'t'} = ($1 * 7) . "DAY";
        }
    }

    return $self->{'t'} if defined $self->{'t'};
    return;
}
*time_period = *time_period = *t;

# ----------------------------------------------------------------------
# profile($p)
# ----------------------------------------------------------------------
sub p { shift->_int_accessor('p', @_) }
*profile = *profile = *p;

# ----------------------------------------------------------------------
# mob($mob)
#
# Displays the stories associated with a particular mob.
# ----------------------------------------------------------------------
sub m { shift->_int_accessor('m', @_) }
*mob = *mob = *m;

# ----------------------------------------------------------------------
# id($id)
#
# Displays a particular story
# ----------------------------------------------------------------------
sub i { shift->_int_accessor('i', @_) }
*id = *id = *i;

# ----------------------------------------------------------------------
# flavor($fl)
# ----------------------------------------------------------------------
sub _fl {
    my $self = shift;

    if (@_) {
        my $fl = shift;
        $self->{'_fl'} = $fl if defined $flavors{$fl};
    }

    return $self->{'_fl'} if defined $self->{'_fl'};
    return;
}
*flavor = *flavor = *_fl;

# ----------------------------------------------------------------------
# description($boolean)
# ----------------------------------------------------------------------
sub _de { shift->_boolean_accessor('_de', @_) }
*description = *description = *_de;

# ----------------------------------------------------------------------
# categories($boolean)
# ----------------------------------------------------------------------
sub _ca { shift->_boolean_accessor('_ca', @_) }
*categories = *categories = *_ca;

# ----------------------------------------------------------------------
# channels($boolean)
# ----------------------------------------------------------------------
sub _ch { shift->_boolean_accessor('_ch', @_) }
*channels = *channels = *_ch;

# ----------------------------------------------------------------------
# dates($boolean)
# ----------------------------------------------------------------------
sub _da { shift->_boolean_accessor('_da', @_) }
*dates = *dates = *_da;

# ----------------------------------------------------------------------
# dc_metadata($boolean)
# ----------------------------------------------------------------------
sub _dc { shift->_boolean_accessor('_dc', @_) }
*dc_metadata = *dc_metadata = *_dc;

# ----------------------------------------------------------------------
# _int_accessor($name, $new)
#
# Generic accessor/mutator for int-based data members.
# ----------------------------------------------------------------------
sub _int_accessor {
    my ($self, $member, $new) = @_;

    $self->{$member} = int($new) if defined $new;

    return $self->{$member} if defined $self->{$member};
    return;
}

# ----------------------------------------------------------------------
# _boolean_accessor($name, $on_off)
#
# Generic accessor/mutator for boolean attributes
# ----------------------------------------------------------------------
sub _boolean_accessor {
    my ($self, $member, $on_off) = @_;

    if (defined $on_off) {
        $self->{$member} = $on_off ? 1 : 0;
    }

    return $self->{$member} if defined $self->{$member};
    return;
}

# ----------------------------------------------------------------------
# Generate the "flavor methods", so the user can call:
#
#   my $data = $m->js();
#
# And get the content as JavaScript.
#
# These methods are also available in an "as_$flavor" form:
#
#   my $data = $m->as_javascript();
# ----------------------------------------------------------------------
{
    no strict qw(refs);
    for my $sub (keys %flavors) {
        *{$sub} = *{"as_$sub"} = sub {
            my $self = shift;
            $self = $self->new(@_) unless ref $self;
            $self->flavor($sub);
            return $self->get();
        };
    }
}

# ----------------------------------------------------------------------
# new(\%params)
#
# Creates a new Net::Meerkat instance.  Takes a hash of name => value
# pairs, the keys of which are assumed to be methods, and the values
# assumed to be the corresponding values.  For example, the following
# constructor call:
#
#   my $mk = Net::Meerkat->new("search" => "perl", "flavor" => "xml");
#
# Is the same as:
#
#   my $mk = Net::Meerkat->new();
#   $mk->search("perl");
#   $mk->flavor("xml");
#
# Parameters to new() can be specified in any case, though the case
# of values is preserved.
#
#   my $mk = Net::Meerkat->new(SEARCH => "apache");
#
# ----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $args = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };
    my $self = bless { __ERROR => '' } => $class;
    my ($debug, $meth, $destination);

    # Special key OUTPUT defines where to put the data
    # when it is retrieved by get()
    if (defined ($destination = delete $args->{ OUTPUT })) {
        $self->{ __OUTPUT } = $destination;
    }

    for $meth (keys %$args) {
        $meth = lc $meth;

        if (my $sub = $self->can($meth)) {
            $self->$sub($args->{$meth});
        }
        else {
            warn "No such method $meth";
        }
    }

    return $self;
}

# ----------------------------------------------------------------------
# error()
# error($error)
#
# Gets/sets the latest error.  If called with a value, returns undef;
# otherwise, returns the last error as a string.  Can be used as such:
#
#   $self->get("/tmp/foo") or die $self->error();
# ----------------------------------------------------------------------
sub error {
    my $self = shift;

    if (@_) {
        $self->{ __ERROR } = shift;
        return;
    }

    return $self->{ __ERROR };
}

# ----------------------------------------------------------------------
# get($destination)
#
# Does the actual fetching, using $ua imported from LWP::Simple.
# If passed a destination, attempt to print to it/invoke it/
# whatever is appropriate.
# ----------------------------------------------------------------------
sub get {
    my $self = shift;
    my ($url, $data, $destination, $ref);

    $url = $self->url;
    unless ($data = $ua->get($url)->content) {
        return $self->error("$url returned no content");
    }

    # If there is not a destination (specified as arguments
    # to get() or in the constructor as OUTPUT => "..."), the
    # the data is merely returned.
    return $data
        unless ($destination = shift || $self->{ __OUTPUT });

    # Otherwise, the user has requested that we do Something
    # with the data, and given us a pointer in the form of
    # $destination.
    if ($ref = ref $destination) {
        if (my $print = UNIVERSAL::can($destination, "print")) {
            $destination->$print($data);
        }
        elsif ($ref eq 'GLOB') {
            print $destination $data;
        }
        elsif ($ref eq 'SCALAR') {
            $$destination = $data;
        }
        elsif ($ref eq 'CODE') {
            eval {
                &$destination($data);
            };
            if ($@) {
                return $self->error($@);
            }
        }
        elsif ($ref eq 'ARRAY') {
            push @$destination, $data;
        }
    }
    else {
        # Not a ref: a filename
        my $fh = IO::File->new(">$destination")
            or return $self->error("Can't open $destination for writing: $!");
        $fh->print($data);
        $fh->close()
            or $self->error("Can't close $destination: $!");
    }

    return 1;
}

# ----------------------------------------------------------------------
# terms()
#
# Returns the defined search terms.
# ----------------------------------------------------------------------
sub terms {
    my $self = shift;
    return sort grep !/^__/, keys %$self;
}

# ----------------------------------------------------------------------
# url([$separator])
#
# Returns the URL generated from the current state of the instance.
# If $separator is supplied, each param will be joined on that,
# otherwise the value of the package global $SEPARATOR will be used.
# ----------------------------------------------------------------------
sub url {
    my ($self, $joint) = @_;
    my (@terms, $url);

    $joint = $SEPARATOR unless defined $joint;
    @terms = $self->terms;

    if (@terms) {
        $url = join '?', $MEERKAT_SERVER,
               join $joint,
               grep { defined }
               map { my $v = $self->$_();
                     defined $v ? join('=', $_, $v)
                                : undef
                    } @terms;
    }
    else {
        $url = $MEERKAT_SERVER;
    }

    URI->new($url)->canonical;
}

# ----------------------------------------------------------------------
# Dump()
#
# Returns a Data::Dumper interpretation of the current instance, for
# debugging.
# ----------------------------------------------------------------------
sub Dump {
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper->Dump([$self], ['meerkat']);
}

sub DESTROY { }

sub Version { shift->VERSION }

1;
__END__

=head1 NAME

Net::Meerkat - Perl interface to O'ReillyNet's Meerkat

=head1 SYNOPSIS

  use Net::Meerkat;
  my $m = Net::Meerkat->new('flavor' => 'rss');
  my $data = $m->get;

  # Shortcut usage:
  use XML::RSS;
  my $rss = XML::RSS->new;
  $rss->parse(Net::Meerkat->rss);

=head1 DESCRIPTION

C<Net::Meerkat> is a Perl interface to O'ReillyNet's Meerkat web
service.  It is little more than a straightforward front-end for
creating Meerkat URLs and fetching the content from
L<http://meerkat.oreillynet.com/>; it doesn't provide data handling
methods, since Meerkat makes its data in many forms, and there are
already convenient modules for handling many of these forms, such as
RSS.  See
L<http://www.oreillynet.com/lpt/a/rss/2000/05/09/meerkat_api.html> for
more information on the Meerkat Web API.

Typical usage:

  my $m = Net::Meerkat->new();
  $m->search("perl apache");
  $m->time("7DAY");
  $m->flavor('rss');

  my $data = $m->get();

C<Net::Meerkat>'s class method shortcuts allow the same data to be
retrieved as follows:

  my $data = Net::Meerkat->rss(search => "perl apache",
                               time => "1 week");

=head1 METHODS

C<Net::Meerkat> implements methods for all of the Meerkat API
functions, including display, query, and flavor attributes.

=head2 Net::Meerkat methods

=over 4

=item new(%options)

Creates a new C<Net::Meerkat> instance.  Takes (name, value) pairs,
which will be used to populate the instance.  The names can be passed
in any case:

  my $m = Net::Meerkat->new(SEARCH_FOR => "perl",
                            FLAVOR => "ns3");

Known options are the same as the display-related methods (see
L<"Display Properties">) and query-related methods (see L<"Query
Properties">), plus OUTPUT, which will be passed to C<get>; see
L<"get"> for details about OUTPUT.

=item error([$error])

If something goes wrong, the error string will be available via the
C<error> method:

  $m->get() or die $m->error();

Errors can also be set with this metehod:

  $m->error("Bad things happened");

If C<error> is used to set an error, then it returns undef; otherwise,
it returns the error string.

=item url()

Returns the URL that will be passed to the Meerkat server, as a
URI-encoded string.  It will not be HTML encoded; if it is to be
displayed in a web page, it will need to be further encoded:

  use HTML::Entities;

  printf '<a href="%s">', encode_entities($m->url);

=item get([$destination])

The C<get> method does the hard work of talking to the server,
getting the data, and returning it to the caller.  When called with no
arguments, C<get> returns the results to the caller as a string:

  my $data = $m->get();

However, C<get> can be called with an argument, $destination, that
determines what will happen to the data that is returned from the
server.  Passing C<OUTPUT> to C<new> is the same as specifying
$destination.

$destination can be one of the following:

=over 4

=item \$string

If passed a reference to $string, the data is put into $string.

=item \@array

The data will be pushed onto the end of @array.

=item $obj

If $obj supports a C<print> method, the data will be passed to it:

  $obj->print($data);

=item sub { ... }

A subroutine will be invoked with $data as the sole argument:

  &$sub($data);

C<&$sub> will be invoked from within an eval; if something goes wrong,
the error will be available via the C<error> method:

  $m->get(sub { ... }) or die $m->error();

=item IO::File->new(...), \*GLOB

The data will be printed to this object.

=item terms()

Returns a list of the query terms that will be passed to the Meerkat
server when the data is requested:

  my @terms = $m->terms;
  my $last_term = pop @terms;
  my $term_string = join " and ", join(", ", @terms), $last_term;

  print "You have added the terms $term_string.";

=back

=back

=head2 Query Properties

=over 4

=item $m-E<gt>search_for($query) or $m-E<gt>s($query) 

Instructs Meerkat to search for something in the story title or
description.  The same effect as entering a search query into the
search box in Meerkat's standard control panel.

=item $m-E<gt>search_what($sw) or $m-E<gt>sw($sw) 

By default, Meerkat's searches meander through story titles and
descriptions.  This option instructs Meerkat instead to search another
field in particular.  Currently supported are the Dublin Core Metadata
elements: The same effect as choosing a field to search from Meerkat's
standard control panel. 

=item $m-E<gt>channel($channel) or $m-E<gt>c($channel) 

Instructs Meerkat to display only a particular channel. The same
effect as selecting a channel from the Categories/Channels menu in
Meerkat's standard control panel. 

=item $m-E<gt>time_period($time) or $m-E<gt>t($time) 

How far back Meerkat should look for stories. The same effect as
choosing a time period from Meerkat's standard control panel. 

=item $m-E<gt>profile($profile) or $m-E<gt>p($profile) 

Restores the settings from a particular Meerkat profile, whether
global or yours personally. The same effect as choosing a profile to
restore from Meerkat's standard control panel. 

=item $m-E<gt>mob($mob) or $m-E<gt>m($mob) 

Retrieves the stories associated with a particular Mob.

=item $m-E<gt>id($id) or $m-E<gt>i($id) 

Retrieves a particular story by id.

=back

=head2 Display Properties

Other than the C<flavor()> method, these methods all take and return
boolean values.

=over 4

=item $m-E<gt>flavor('B<$flavor>')

The flavor of the returned data; see L<"Meerkat Flavors">, above.

=item $m-E<gt>descriptions([$bool]) or $m-E<gt>_de([$bool])

Turn on or off story descriptions or blurlbs.  You lose some of the
story detail, but gain a compact display for easy scanning.

=item $m-E<gt>cateogries([$bool]) or $m-E<gt>_ca([$bool])

Meerkat's channels are cataloged into a category hierarchy; if these
categories aren't useful to you, feel free to turn them off.

B<Note>: Some Meerkat flavors (e.g., RSS) may exclude the display of
categories, ignoring this setting.

=item $m-E<gt>channels([$bool]) or $m-E<gt>_ch([$bool])

Meerkat's stories are picked up from hundreds of channels.  Don't
really care from which channel a particular story comes from? Turn the
channel display off.

B<Note>: Some Meerkat flavors (e.g., RSS) may exclude the display of
channels, ignoring this setting.

=item $m-E<gt>dates([$bool]) or $m-E<gt>_da([$bool])

When Meerkat first noticed and picked up a story.

B<Note>: Some Meerkat flavors (e.g., RSS) may exclude the display of
dates, ignoring this setting.

=item $m-E<gt>dc_metadata([$bool]) or $m-E<gt>_dc([$bool])

Meerkat supports the RSS 1.0 Dublin Core Module, augmenting RSS's
standard title, link, and description with such attributes as creator
(author), subject, rights, language, publisher, format, and so on.

B<Note>: Some Meerkat flavors (e.g., Minimal) may exclude the display
of Dublin Core Metadata, ignoring this setting.

=back

=head2 Meerkat Flavors

Meerkat's "flavors" define the format of the data returned.

=over 4

=item $m-E<gt>flavor('B<meerkat>') or $m-E<gt>meerkat()

Meerkat's default flavour, providing a comprehensive interface for your
RSS-reading convenience.  This is HTML. 

=item $m-E<gt>flavor('B<tofeerkat>') or $m-E<gt>tofeerkat()

For those who prefer something a little lighter, the Tofeerkat
interface is a compact version of the default, optimized for those who
take full advantage of the power of Meerkat's Profiles.

=item $m-E<gt>flavor('B<minimal>') or $m-E<gt>minimal()

Designed for the minimalist, Meerkat's Minimal flavour is ideal for
Lynx browsers, handhelds using AvantGo or the like, and wireless
micro-browsers.

=item $m-E<gt>flavor('B<rss>') or $m-E<gt>rss()

Meerkat's RSS 0.91 flavour returns 15 stories as well-formed RSS 0.91. 

=item $m-E<gt>flavor('B<rss10>') or $m-E<gt>rss10()

Coming full-circle, returns 15 stories as RSS 1.0, ready for
incorporation into your web site or insertion into a database. Similar
to the RSS 0.91 flavour below, Meerkat's RSS 1.0 includes Dublin Core
Metadata via the RSS 1.0 Dublin Core module and will continue to
evolve, supporting any other standard modules as they become available

=item $m-E<gt>flavor('B<xml>') or $m-E<gt>xml()

Modeled loosely on RSS/0.91 format, the XML flavour gives you more of
the information Meerkat collects for each story: source, category, and
date. The rather simplistic DTD (Document Type Description),
meerkat_xml_flavour.dtd is available for your perusal.

=item $m-E<gt>flavor('B<js>') or $m-E<gt>js()

Meerkat's JavaScript Source (.js) flavour is probably the most
exciting to Web designers with little or no programming experience. If
you know basic HTML, you can insert Meerkat stories right into your
web site with a copy and a paste.

=item $m-E<gt>flavor('B<ns3>') or $m-E<gt>ns3()

An experimental implementation of Tim Berners-Lee's Notation 3
RDF-alike. "This is not designed as an alternative to RDF's XML syntax
which has the fundamental advantage that it is in XML. This is an
academic excercise in language designed for a human-readable and
scribblable language."

=item $m-E<gt>flavor('B<php>') or $m-E<gt>php()

Results available a PHP serialized string.

=back


=head1 EXAMPLES, SHORTCUTS, and TIPS

=head2 Examples

The Meertkat API Documentation gives 4 examples; their C<Net::Meerkat>
equivalents follow.  All examples assume a fresh C<Net::Meerkat>
instance:

  my $m = Net::Meerkat->new;

=over 4

=item o

"Show me today's Macintosh-related stories as RSS 1.0 and go
ahead and include the Dublin Core Metadata."

  $m->profile(1065);
  $m->flavor("xml");
  my $data = $m->get();

Or:

  $data = $m->xml(profile => 1065);

=item o

"I'd like to, as simply as possible, insert the latest Wireless
stories into my homepage."

It's tough to apply this one directly, unless you are running mod_perl
or calling this from a CGI script (in which case it will be easier to
use a different form).

Inserting a JavaScript version (like the answer to the above question
suggests) using C<Net::Meerkat> could be done, under mod_perl:

  my $data = Net::Meerkat->js(profile => 9)
  $r->print($data);

Or even:

  Net::Meerkat->js(profile => 9, OUTPUT => $r);

By passing $r as the OUTPUT parameter, C<Net::Meerkat> will call it's
C<print> method.

=item o

"Let's build an RSS channel devoded to Apache modules."

  $m->search("mod_");
  $m->time_period("ALL");
  $m->flavor("rss");

  $m->get("apache.html");

=item o

"I want to use my Palm Pilot and AvantGo to grab just the latest
headlines and their descriptions."

  $m->categories(0);
  $m->channel(0);
  $m->date(0);
  $m->flavor("minimal");

=back

C<Net::Meerkat> works very well from cron jobs; because Meerkat can
output so many types of data, it is ideal for creating, e.g., sidebars
for a personal home page:

  perl -MNet::Meerkat -e 'Net::Meerkat->minimal(mob => 12345, OUTPUT => "sidebar.html")'

(Assuming that mob 12345 is a mob you created with your specific
interests.)

F<sidebar.html> can then be included in your home page:

  <!--#include file="sidebar.html" -->
  Data from Meerkat last updated on <!--#flastmod file="sidebar.html" -->.

If your ISP provides PHP, for example a Sourceforge project page, a similar
technique can be used:

  perl -MNet::Meerkat -e 'Net::Meerkat->php(mob => 12345, OUTPUT => "meerkat.php")'

The RSS or XML versions are ideal for feeding templating systems and
the like.  For systems that can utilize XML directly via extensions,
like Template Toolkit, simply passing the RSS directly might be
enough:

  use Template;
  use Net::Meerkat;

  my $t = Template->new(\%template_options);
  my $xml = Net::Meerkat->new(%meerkat_options, flavor => "xml");

  $t->process("my.template", { meerkat_source => $xml })
      or die $t->error();

Then F<my.template> could use, for example, the C<XML.XPath> plugin:

  [% USE xp = XML.XPath(xml => meerkat_source) %]
  [% FOREACH item = xp.findnodes('/meerkat/story') %]
    ...

For templating systems like C<HTML::Template>, which don't support an
extension architecture, some more work will need to be done up front:

  use HTML::Template;
  use Net::Meerkat;
  use XML::RSS;

  my $t = HTML::Template->new(%template_options);
  my $xml = Net::Meerkat->new(%meerkat_options, flavor => "rss");
  my $rss = XML::RSS->new;
  my @links;

  $rss->parse($xml);

  $t->param("channel_title" => $rss->{'channel'}->{'title'},
            "channel_link"  => $rss->{'channel'}->{'link'});
  for my $item (@{$rss->{'items'}}) {
      push @links, { "title" => $item->{'title'},
                     "link" => $item->{'link'}
                   };
  }

  $t->param("items" => \@links);

  print $t->output;

The template might look like:

  <h1><a href="<tmpl_var name="channel_link">">
      <tmpl_var name="channel_name"></a>
  </h1>

  <ul>
  <tmpl_loop name="links">
    <li><a href="<tmpl_var name="link">"><tmpl_var name="name"></a>
  </tmpl_loop>
  </ul>

Which would display an ugly but functional unordered list of items.
(Hey, I'm a programmer, not a designer.)

=head2 Shortcuts

There are several builtin shortcuts for common activities.

=over 4

=item B<flavor-named methods>

There are methods named after each of the available flavors
(currently, C<meerkat>, C<tofeerkat>, C<minimal>, C<rss>, C<rss10>,
C<xml>, C<js>, C<ns3>, and C<php>) which set the flavor and then call
get.  In other words, these two statements are equivalent, assuming
that B<$m> is an initialized Net::Meerkat object:

  # 1:
  $m->flavor("xml");
  $content  = $m->get;

  # 2:
  $content  = $m->xml;

These are convenience methods only; internally, the second example
does the same as the first, but it is easier for the programmer to
type.

These methods are also available prefixed with "as_":

  # 2a:
  $content  = $m->as_xml;

=item B<Default actions and class methods>

The flavor-named methods are available as class methods as well, and,
when called as such, optionally take the same parameters as the
constructor.

The quickest way to get the default stuff (with no extra parameters or
anything) in RSS format:

  my $content = Net::Meerkat->rss;

To add parameters:

  $content = Net::Meerkat->rss(mob => 4);

These class methods create objects internally and then call the
appropriate fetching methods, so there is no speed gain, but a concise
class method like this is ideal for things like cron entries:

  15,30,45,60 * * * * /usr/bin/perl -MNet::Meerkat -e 'Net::Meerkat->rss(OUTPUT => "/www/includes/meerkat.rss")'

=item B<Changing Meerkat Servers>

To use a Meerkat server other than the default at
L<http://meerkat.oreillynet.com>, set C<$Net::Meerkat::MEERKAT_SERVER>
to the new servername.  This would primarily be useful for testing a
new implementation of the server software, though, as far as I know,
the server side of Meerkat is not publicly available.

=back

=head1 SEE ALSO

L<Perl>, L<LWP::Simple>, L<URI>, L<URI::Escape>, L<IO::File>,
L<http://www.oreillynet.com/lpt/a//rss/2000/05/09/meerkat_api.html>

=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
