package Net::Minecraft::PacketFactory;

use strict;
use warnings;

use Module::Pluggable::Object;

sub from_blob {
	my ($class, %args) = @_;

	if (!defined($args{blob})) {
		die("from_blob requires a blob to create a packet from");
	}

	my $id = unpack("C", $args{blob});

	my $finder = Module::Pluggable::Object->new(
		search_path => [ "Net::Minecraft::Packet" ],
		require => 1,
	);

	for my $plugin ($finder->plugins) {
		if ($plugin->id == $id) {
			return $plugin->from_blob(%args);
		}
	}

	die("Unknown packet with ID $id");
}

1;
