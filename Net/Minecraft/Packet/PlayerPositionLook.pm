package Net::Minecraft::Packet::PlayerPositionLook;

use Net::Minecraft::Packer qw(mc_pack mc_unpack);

use Moose;

with "Net::Minecraft::Packet";

has [ qw(x y z stance yaw pitch) ] => ( is => "rw", isa => "Num" );
has "on_ground" => ( is => "rw", isa => "Bool");

sub id {
	return 0x0d;
}

sub size {
	my ($self) = @_;

	return 42;
}

sub as_blob {
	my ($self, %args) = @_;

	return mc_pack("B d d d d f f b",
		$self->id,
		$self->x,
		$args{sender} eq "client"
			? ($self->y, $self->stance)
			: ($self->stance, $self->y),
		$self->z,
		$self->yaw,
		$self->pitch,
		$self->on_ground,
	);
}

sub from_blob {
	my ($class, %args) = @_;

	my (undef, $x, $u1, $u2, $z, $yaw, $pitch, $on_ground)
		= mc_unpack("B d d d d f f b", $args{blob});

	return $class->new(
		x         => $x,
		y         => ($args{sender} eq "client" ? $u1 : $u2),
		stance    => ($args{sender} eq "client" ? $u2 : $u1),
		z         => $z,
		yaw       => $yaw,
		pitch     => $pitch,
		on_ground => $on_ground,
	);
}

1;
