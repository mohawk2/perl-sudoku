#!perl -w

use strict;

#use Data::Dumper; print Data::Dumper::Dumper([ Sudoko::Bigsquare::init2nonblank(@ESCARGOT) ]);
#use Data::Dumper; print Data::Dumper::Dumper([ Sudoko::Bigsquare::related_xys(4, 6) ]);

die "usage: $0 <inputfile>\n" unless @ARGV;
my @input = split ' ', read_file($ARGV[0]);

my $bigsquare = Sudoko::Bigsquare->new(@input);
print_bigsquare($bigsquare);

while (my @solved = $bigsquare->get_solved) {
 print '.';
 map { $bigsquare->setvalue(@$_) } @solved;
}
print "---\n";
#use Data::Dumper; print Data::Dumper::Dumper([ $bigsquare->allvalues ]);#$bigsquare->{xy2possvalue21});#
print_bigsquare($bigsquare);

sub print_bigsquare {
 my $bigsquare = shift;
 map { print join('', @$_), "\n" } $bigsquare->allvalues;
}

sub read_file {
 my $file = shift;
 local *FH;
 open FH, $file or die "open($file): $!\n";
 local $/;
 <FH>;
}

package Sudoko::Bigsquare;

# a bigsquare has 3 types of sets: x, y, square
# within square is each row left-right, top row first
# square offset is same
# all offsets and xy coords start from 0

# internal data structures: xy2possvalue21 (i.e. the value is 1, so do "keys" on it to get poss nums)
#  when the xy is setvalue'd, the key is deleted

sub new {
 my ($class, @init) = @_;
 my $self = {};
 $self->{sets} = [];
 $self->{y2x2value} = [];
 my @all_xys = map {
  my $y = $_;
  map {
   [ $_, $y ]
  } (0..8)
 } (0..8);
 map {
  my $this_xy = $_;
  $self->{y2x2value}->[$this_xy->[1]]->[$this_xy->[0]] = 0;
  map { $self->{xy2possvalue21}->{join '', @$this_xy}->{$_} = 1; } (1..9);
 } @all_xys;
#use Data::Dumper; print Data::Dumper::Dumper($self->{xy2possvalue21});die;#[ $bigsquare->get_solved ]);
 bless $self, $class;
 my @nonblank = init2nonblank(@init) if @init;
 map { $self->setvalue(@$_) } @nonblank;
 $self;
}

sub setvalue {
 my ($self, $x, $y, $value) = @_;
 $self->{y2x2value}->[$y]->[$x] = $value;
#warn "$self ($x, $y, $value)\n";
#use Data::Dumper; print Data::Dumper::Dumper([ xy2type_set_offset($x, $y) ]);
 map {
  my ($type, $set, $offset) = @$_;
  $self->{sets}->[$type]->[$set]->[$offset] = $value;
 } xy2type_set_offset($x, $y);
 $self->remove_poss($x, $y);
 map { $self->remove_poss(@$_, $value); } related_xys($x, $y);
}

# if $value not defined, delete all possibilities
sub remove_poss {
 my ($self, $x, $y, $value) = @_;
#warn "removing ($x, $y, $value)\n";
 if (defined $value) {
  delete $self->{xy2possvalue21}->{"$x$y"}->{$value} if exists $self->{xy2possvalue21}->{"$x$y"};
 } else {
  delete $self->{xy2possvalue21}->{"$x$y"};
 }
}

# output list of [ x, y, value ]
sub get_solved {
 my $self = shift;
 my $xy2pn = $self->{xy2possvalue21};
 map { [ (split //, $_), (keys %{ $xy2pn->{$_} })[0] ] } grep { keys %{ $xy2pn->{$_} } == 1 } keys %$xy2pn;
}

# output list of rows
sub allvalues {
 my $self = shift;
 @{ $self->{y2x2value} };
}

# input (x, y)
# output list of [ x, y ] in same x, same y, same square
sub related_xys {
 my ($x, $y) = @_;
 my $x_left_square = 3 * int($x / 3);
 my $y_top_square = 3 * int($y / 3);
 my @other_in_square = map {
  my $thisy = $_;
  map { [ $_, $thisy ] } grep { $_ != $x } ($x_left_square .. $x_left_square + 2)
 } grep { $_ != $y } ($y_top_square .. $y_top_square + 2);
 (
  (map { [ $_, $y ] } grep { $_ != $x } (0..8) ),
  (map { [ $x, $_ ] } grep { $_ != $y } (0..8) ),
  @other_in_square,
 );
}

# output offset number of square
sub xy2square {
 my ($x, $y) = @_;
 int($x / 3) + 3 * int($y / 3);
}

# input (x, y)
# output 3 x [ type, set, offset ]
sub xy2type_set_offset {
 my ($x, $y) = @_;
 my $whichsquare = xy2square($x, $y);
 my $square_offset = ($x % 3) + 3 * ($y % 3);
 (
  [ 0, $y, $x ],
  [ 1, $x, $y ],
  [ 2, $whichsquare, $square_offset ],
 );
}

# input is list of 27 3-char strings
# output is list of listrefs: [ x, y, value ]
sub init2nonblank {
 die "wrong number of inputs: @_ != 27\n" unless @_ == 27;
 my @wrong = grep { length != 3 } @_;
 die "wrong-length inputs: (@wrong)\n" if @wrong;
 my @nonblank;
 for (my $triplet = 0; $triplet < @_; $triplet++) {
  my @chars = split //, $_[$triplet];
  my ($basex, $basey) = @{ triplet2xy($triplet) };
  for (my $char = 0; $char < 3; $char++) {
   push @nonblank, [ $basex + $char, $basey, $chars[$char] ] if $chars[$char] > 0;
  }
 }
 @nonblank;
}

# input = 0..26, output = [ x, y ] of first character
sub triplet2xy {
 [ ($_[0] % 3) * 3, int($_[0] / 3) ];
}

1;
