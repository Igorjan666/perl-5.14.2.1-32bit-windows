use strict;
use warnings;
package Mixin::Linewise::Readers;

our $VERSION = '0.003';

use Carp ();
use IO::File;
use IO::String;

use Sub::Exporter -setup => {
  exports => { map {; "read_$_" => \"_mk_read_$_" } qw(file string) },
  groups  => {
    default => [ qw(read_file read_string) ],
    readers => [ qw(read_file read_string) ],
  },
};

=head1 NAME

Mixin::Linewise::Readers - get linewise readers for strings and filenames

=head1 SYNOPSIS

  package Your::Pkg;
  use Mixin::Linewise::Readers -readers;

  sub read_handle {
    my ($self, $handle) = @_;

    LINE: while (my $line = $handle->getline) {
      next LINE if $line =~ /^#/;

      print "non-comment: $line";
    }
  }

Then:

  use Your::Pkg;

  Your::Pkg->read_file($filename);

  Your::Pkg->read_string($string);

  Your::Pkg->read_handle($fh);

=head1 EXPORTS

C<read_file> and C<read_string> are exported by default.  Either can be
requested individually, or renamed.  They are generated by
L<Sub::Exporter|Sub::Exporter>, so consult its documentation for more
information.

Both can be generated with the option "method" which requests that a method
other than "read_handle" is called with the created IO::Handle.

=head2 read_file

  Your::Pkg->read_file($filename);

If generated, the C<read_file> export attempts to open the named file for
reading, and then calls C<read_handle> on the opened handle.

Any arguments after C<$filename> are passed along after to C<read_handle>.

=cut

sub _mk_read_file {
  my ($self, $name, $arg) = @_;

  my $method = defined $arg->{method} ? $arg->{method} : 'read_handle';

  sub {
    my ($invocant, $filename) = splice @_, 0, 2;

    # Check the file
    Carp::croak "no filename specified"           unless $filename;
    Carp::croak "file '$filename' does not exist" unless -e $filename;
    Carp::croak "'$filename' is not a plain file" unless -f _;

    my $handle = IO::File->new($filename, '<')
      or Carp::croak "couldn't read file '$filename': $!";

    $invocant->$method($handle, @_);
  }
}

=head2 read_string

  Your::Pkg->read_string($string);

If generated, the C<read_string> creates an IO::String handle from the given
string, and then calls C<read_handle> on the opened handle.

Any arguments after C<$string> are passed along after to C<read_handle>.

=cut

sub _mk_read_string {
  my ($self, $name, $arg) = @_;

  my $method = defined $arg->{method} ? $arg->{method} : 'read_handle';

  sub {
    my ($invocant, $string) = splice @_, 0, 2;

    Carp::croak "no string provided" unless defined $string;

    my $handle = IO::String->new(\$string);

    $invocant->$method($handle, @_);
  }
}

=head1 BUGS

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mixin-Linewise>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Ricardo SIGNES, C<< E<lt>rjbs@cpan.orgE<gt> >>

=head1 COPYRIGHT

Copyright 2008, Ricardo SIGNES.

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
