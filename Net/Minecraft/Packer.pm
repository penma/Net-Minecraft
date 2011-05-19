package Net::Minecraft::Packer;

use strict;
use warnings;

use Sub::Exporter -setup => { exports => [ qw(mc_pack mc_unpack) ] };

use Encode;
use Readonly;

Readonly my %codemap => (
	B => "C",
	b => "c",
	s => "s>",
	i => "l>",
	l => "q>",
	f => "f>",
	d => "d>",
);

Readonly my $incomplete_error => "Incomplete packed string";

sub mc_pack {
	my ($template, @elements) = @_;

	my $expr = "";

	while (length($template)) {
		$template =~ s/^c//;

		my $next_elem = shift(@elements);

		if ($template =~ /^\(([^)]+)\)(\/?)(?:\s+(.*))?$/) {
			my ($sub, $array, $template_rest) = ($1, $2, $3);
			$template = $template_rest;

			if (defined($array) and $array eq "/") {
				for my $subelem (@{$next_elem}) {
					$expr .= mc_pack($sub, @{$subelem});
				}
			} else {
				$expr .= mc_pack($sub, @{$next_elem});
			}
		} else {
			my ($code, $array, $template_rest) = ($template =~ /^(.)(\/?)(?:\s+(.*))?$/);
			$template = $template_rest;

			if (defined($array) and $array eq "/") {
				for my $subelem (@{$next_elem}) {
					$expr .= mc_pack($code, $subelem);
				}
			} else {
				if ($code ~~ [keys(%codemap)]) {
					$expr .= pack($codemap{$code}, $next_elem);
				} elsif ($code eq "u") {
					$expr .= pack("s>/a", $next_elem);
				} elsif ($code eq "a") {
					$expr .= pack("s> a*", length($next_elem), encode("ucs2", $next_elem));
				} elsif ($code eq "m") {
					die("Not implemented");
				} elsif ($code eq "e") {
					if ($next_elem->[0] == -1) {
						$expr .= pack("s>", @{$next_elem});
					} else {
						$expr .= pack("s> c s>", @{$next_elem});
					}
				} elsif ($code eq "p") {
					$expr .= $next_elem;
				} else {
					die("Unknown code $code");
				}
			}
		}
	}

	return $expr;
}

sub _require_length {
	my ($expr, $length) = @_;

	if (length($expr) < $length) {
		die($incomplete_error);
	}
}

sub mc_unpack {
	my ($template, $expr) = @_;

	my $count;
	my @elements;

	while (length($template)) {
		my $value;

		my $target = "elements";
		if ($template =~ /^c/) {
			$target = "count";
			$template =~ s/^c//;
		}

		if ($template =~ /^\(([^)]+)\)(\/?)(?:\s+(.*))?$/) {
			my ($sub, $array, $template_rest) = ($1, $2, $3);
			$template = $template_rest;

			if (defined($array) and $array eq "/") {
				$value = [];

				if (!defined($count)) {
					die("Array without preceding count");
				}

				for (1..$count) {
					my @stuff = mc_unpack("$sub r", $expr);
					my $rest = pop(@stuff);
					push(@{$value}, [ @stuff ]);
					$expr = $rest;
				}
			} else {
				my @stuff = mc_unpack("$sub r", $expr);
				my $rest = pop(@stuff);
				$value = [ @stuff ];
				$expr = $rest;
			}
		} else {
			my ($code, $array, $template_rest) = ($template =~ /^(.)(\/?)(?:\s+(.*))?$/);
			$template = $template_rest;

			if (defined($array) and $array eq "/") {
				$value = [];

				if (!defined($count)) {
					die("Array without preceding count");
				}

				for (1..$count) {
					my @stuff = mc_unpack("$code r", $expr);
					my $rest = pop(@stuff);

					if (@stuff > 1) {
						die("Code $code unexpectedly produced more than one element");
					}

					push(@{$value}, $stuff[0]);
					$expr = $rest;
				}
			} else {
				if ($code ~~ [keys(%codemap)]) {
					_require_length($expr, length(pack($codemap{$code}, 0)));

					($value, $expr) = unpack("$codemap{$code} a*", $expr);
				} elsif ($code eq "u") {
					($value, $expr) = unpack("s>/a a*", $expr);
				} elsif ($code eq "a") {
					_require_length($expr, 2);
					my ($length, $stuff) = unpack("s> a*", $expr);

					_require_length($expr, 2 + $length * 2);
					$value = decode("ucs2", substr($expr, 2, $length * 2));

					$expr = substr($expr, 2 + $length * 2);
				} elsif ($code eq "m") {
					die("Not implemented");
				} elsif ($code eq "e") {
					_require_length($expr, 2);
					my ($id, $stuff) = unpack("s> a*", $expr);

					if ($id != -1) {
						_require_length($stuff, 3);
						my ($icount, $iuses, $morestuff) = unpack("c s> a*", $stuff);

						$expr = $morestuff;
						$value = [ $id, $icount, $iuses ];
					} else {
						$expr = $stuff;
						$value = [ $id ];
					}
				} elsif ($code eq "p") {
					if (!defined($count)) {
						die("Binary string without preceding length");
					}

					_require_length($expr, $count);

					$value = substr($expr, 0, $count);
					$expr = substr($expr, $count);
				} elsif ($code eq "r") {
					$value = $expr;
					$expr = "";
				} else {
					die("Unknown code $code");
				}
			}
		}

		if ($target eq "count") {
			$count = $value;
		} else {
			push(@elements, $value);
		}
	}

	return @elements;
}

1;

__END__

=head1 TEMPLATE CODES

 B  1  unsigned byte
 b  1  byte
 s  2  short
 i  4  int
 l  8  long
 f  4  float
 d  8  double
 u  v  modified utf8 string prefixed by short
 a  v  ucs2 string prefixed by short
 p  v  byte string of specified length (no array suffix needed)
 m  v  minecraft metadata
 e  v  item (short optionally followed by byte and short)

Additionally, a numeric specifier prefixed by C<c> will not be
returned but instead stored as a length for arrays. Arrays of
elements are specified by suffixing a code with a slash, and
the whole list will be returned as an arrayref. Codes can also
be grouped by enclosing them in parentheses, producing an
arrayref. (An array of groups will therefore return an arrayref
of arrayrefs.)
