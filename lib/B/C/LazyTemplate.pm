package B::C::LazyTemplate;

use strict;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/replace_later/;

my @RULES;

sub replace_later {
	my $todo_later = shift;
	push @RULES, $todo_later;
	return join('', '~LZY', scalar @RULES - 1, '~');
}

sub substitute_all {
	my $ref_str = shift;
	return unless $ref_str && defined $$ref_str;

	$$ref_str =~ s{~LZY([0-9]+)~}{_dorule($1)}ge;

	return;
}

sub _dorule {
	my $i = shift;

	return '' unless defined $i && defined $RULES[$i] && ref $RULES[$i];

	return $RULES[$i]->();
}

1;