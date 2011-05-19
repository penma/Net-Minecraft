package Net::Minecraft::Packet::MapChunk;

use Net::Minecraft::Packer qw(mc_pack mc_unpack);

use Moose;

with "Net::Minecraft::Packet";

has [ qw(x y z size_x size_y size_z) ] => ( is => "rw", isa => "Int" );
has "compressed_data" => ( is => "rw" );

sub id {
	return 0x33;
}

sub size {
	my ($self) = @_;

	return 18 + length($self->compressed_data);
}

sub as_blob {
	my ($self, %args) = @_;

	return mc_pack("B i s i b b b ci p",
		$self->id,
		$self->x,
		$self->y,
		$self->z,
		$self->size_x - 1,
		$self->size_y - 1,
		$self->size_z - 1,
		length($self->compressed_data),
		$self->compressed_data,
	);
}

sub from_blob {
	my ($class, %args) = @_;

	my (undef, $x, $y, $z, $size_x, $size_y, $size_z, $compressed_data)
		= mc_unpack("B i s i b b b ci p", $args{blob});

	return $class->new(
		x      => $x,
		y      => $y,
		z      => $z,
		size_x => $size_x + 1,
		size_y => $size_y + 1,
		size_z => $size_z + 1,
		compressed_data => $compressed_data,
	);
}

1;
