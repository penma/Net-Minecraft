package Net::Minecraft::Packet::Disconnect;

use Net::Minecraft::Packer qw(mc_pack mc_unpack);

use Moose;

with "Net::Minecraft::Packet";

has "message" => ( is => "rw" );

sub id {
	return 0xff;
}

sub size {
	my ($self) = @_;

	return 3 + length($self->message) * 2;
}

sub as_blob {
	my ($self, %args) = @_;

	return mc_pack("B a", $self->id, $self->message);
}

sub from_blob {
	my ($class, %args) = @_;

	my (undef, $message) = mc_unpack("B a", $args{blob});
	return $class->new(message => $message);
}

1;
