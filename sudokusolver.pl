#!perl -w

use strict;

die "usage: $0 <inputfile>\n" unless @ARGV;
my @input = split ' ', read_file($ARGV[0]);

my $bigsquare = Sudoko::Bigsquare->new;
map { $bigsquare->setvalue(@$_) } Sudoko::Bigsquare::init2nonblank(@input);
print_bigsquare($bigsquare);

while (my @solved = $bigsquare->get_solved) {
 print '.';
 map { $bigsquare->setvalue(@$_) } @solved;
#die if $::count++ > 2;
}
print "---\n";
#use Data::Dumper; print Data::Dumper::Dumper($bigsquare->{settype_id2set});
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

package Sudoku::Set;

# has 9 locations, each of which can have 1 value, which is 1-9, which can only occur once each

sub new {
 my ($class) = @_;
 my $self = {};
 map {
  my $value = $_;
  map {
   my $loc = $_;
   $self->{value2loc21}->{$value}->{$loc} = 1;
  } (0..8);
 } (1..9);
 bless $self, $class;
}

# if $loc undef, remove all that value's possible locations
# if $value undef, remove all that location's possible values
sub remove_poss {
 my ($self, $value, $loc) = @_;
 if (not defined $value) {
  die "must define either value or loc\n" unless defined $loc;
  map {
   my $value = $_;
   delete $self->{value2loc21}->{$value}->{$loc} if exists $self->{value2loc21}->{$value}; # no auto-viv
  } (1..9);
  return;
 }
 return unless exists $self->{value2loc21}->{$value};
 if (not defined $loc) {
  delete $self->{value2loc21}->{$value};
  return;
 }
 delete $self->{value2loc21}->{$value}->{$loc};
}

# returns list of [ loc, value ]
sub get_solved {
 my $self = shift;
 my @loc_vals;
 map {
  my $value = $_;
  my @locs = keys %{ $self->{value2loc21}->{$value} };
  if (@locs == 1) {
   push @loc_vals, [ $locs[0], $value ];
  }
 } keys %{ $self->{value2loc21} };
 @loc_vals;
}

package Sudoko::Bigsquare;

# a bigsquare has 3 types of sets: row, col, square
# within square is each row left-right, top row first
# square offset is same
# all offsets and xy coords start from 0

# internal data structures:
# settype_id2value2loc21: "$type$id" -> value -> loc -> 1 (as above, keys to get possibilities)

sub new {
 my ($class) = @_;
 my $self = {};
 $self->{settype_id2set} = {};
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
 } @all_xys;
 map {
  my $settype = $_;
  map {
   my $set = $_;
   $self->{settype_id2set}->{$settype.$set} = Sudoku::Set->new;
  } (0..8);
 } (0..2);
 bless $self, $class;
}

sub setvalue {
 my ($self, $x, $y, $value) = @_;
 $self->{y2x2value}->[$y]->[$x] = $value;
#warn "$self->setvalue($x, $y, $value)\n";
#use Data::Dumper; print Data::Dumper::Dumper([ xy2type_set_offset($x, $y) ]);
 $self->remove_poss($x, $y);
 map { $self->remove_poss(@$_, $value); } related_xys($x, $y);
}

# if $value not defined, delete all possibilities
sub remove_poss {
 my ($self, $x, $y, $value) = @_;
#warn "removing ($x, $y, @{[ defined($value) ? $value : 'undef' ]})\n";
 map {
  my ($type, $set, $offset) = @$_;
  $self->{settype_id2set}->{$type.$set}->remove_poss($value, $offset);
 } xy2type_set_offset($x, $y);
}

# output list of [ x, y, value ]
sub get_solved {
 my $self = shift;
 my %xy2v;
 my $si2set = $self->{settype_id2set};
 map {
  my $si = $_;
  my $set = $si2set->{$si};
  map {
   my ($loc, $value) = @$_;
   my ($settype, $setid) = split //, $si;
   my ($x, $y) = type_set_offset2xy($settype, $setid, $loc);
#warn "GOT SOLVED: $loc, $value = ($settype, $setid) = $x, $y\n";
   $xy2v{$x.$y} = $value;
  } $set->get_solved;
 } keys %$si2set;
 map { [ (split //, $_), $xy2v{$_} ] } keys %xy2v;
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

# input (x, y)
# output 3 x [ type, set, offset ]
sub xy2type_set_offset {
 my ($x, $y) = @_;
 my $whichsquare =  int($x / 3) + 3 * int($y / 3);
 my $square_offset = ($x % 3) + 3 * ($y % 3);
 (
  [ 0, $y, $x ],
  [ 1, $x, $y ],
  [ 2, $whichsquare, $square_offset ],
 );
}

# input (type, set, offset)
# output (x, y)
sub type_set_offset2xy {
 my ($type, $setid, $offset) = @_;
 if ($type == 0) {
  return ($offset, $setid);
 } elsif ($type == 1) {
  return ($setid, $offset);
 } elsif ($type == 2) {
  my $x_left_square = 3 * ($setid % 3);
  my $y_top_square = 3 * int($setid / 3);
  my $x_offset = $offset % 3;
  my $y_offset = int($offset / 3);
  return ($x_left_square + $x_offset, $y_top_square + $y_offset);
 }
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
