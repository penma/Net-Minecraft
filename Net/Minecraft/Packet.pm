package Net::Minecraft::Packet;

use Moose::Role;

requires qw(id size as_blob from_blob);

for my $func (qw(as_blob from_blob)) {
	around $func => sub {
		my ($orig, $self, %args) = @_;

		if (!defined($args{sender}) or ($args{sender} ne "server" and $args{sender} ne "client")) {
			die("Invalid sender for $func, requires 'client' or 'server'");
		}

		$self->$orig(%args);
	};
}

around "from_blob" => sub {
	my ($orig, $self, %args) = @_;

	if (!defined($args{blob})) {
		die("from_blob requires a blob to create a packet from");
	}

	$self->$orig(%args);
};

1;
