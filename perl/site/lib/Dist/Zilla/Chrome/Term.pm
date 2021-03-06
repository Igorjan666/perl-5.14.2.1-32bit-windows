package Dist::Zilla::Chrome::Term;
{
  $Dist::Zilla::Chrome::Term::VERSION = '4.300007';
}
use Moose;
# ABSTRACT: chrome used for terminal-based interaction


use Dist::Zilla::Types qw(OneZero);
use Log::Dispatchouli 1.102220;

use namespace::autoclean;

has logger => (
  is  => 'ro',
  isa => 'Log::Dispatchouli',
  init_arg => undef,
  writer   => '_set_logger',
  default  => sub {
    Log::Dispatchouli->new({
      ident     => 'Dist::Zilla',
      to_stdout => 1,
      log_pid   => 0,
      to_self   => ($ENV{DZIL_TESTING} ? 1 : 0),
      quiet_fatal => 'stdout',
    });
  }
);

has term_ui => (
  is   => 'ro',
  isa  => 'Object',
  lazy => 1,
  default => sub {
    require Term::ReadLine;
    require Term::UI;
    Term::ReadLine->new('dzil')
  },
);

sub decode_utf8 ($;$)
{
    require Encode;
    no warnings 'redefine';
    *decode_utf8 = \&Encode::decode_utf8;
    goto \&decode_utf8;
}


sub prompt_str {
  my ($self, $prompt, $arg) = @_;
  $arg ||= {};
  my $default = $arg->{default};
  my $check   = $arg->{check};

  if ($arg->{noecho}) {
    require Term::ReadKey;
    Term::ReadKey::ReadMode('noecho');
  }
  my $input_bytes = $self->term_ui->get_reply(
    prompt => $prompt,
    allow  => $check || sub { defined $_[0] and length $_[0] },
    (defined $default ? (default => $default) : ()),
  );
  if ($arg->{noecho}) {
    Term::ReadKey::ReadMode('normal');
    # The \n ending user input disappears under noecho; this ensures
    # the next output ends up on the next line.
    print "\n";
  }

  my $input = decode_utf8( $input_bytes );
  chomp $input;

  return $input;
}

sub prompt_yn {
  my ($self, $prompt, $arg) = @_;
  $arg ||= {};
  my $default = $arg->{default};

  my $input = $self->term_ui->ask_yn(
    prompt  => $prompt,
    (defined $default ? (default => OneZero->coerce($default)) : ()),
  );

  return $input;
}

sub prompt_any_key {
  my ($self, $prompt) = @_;
  $prompt ||= 'press any key to continue';

  my $isa_tty = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));

  if ($isa_tty) {
    local $| = 1;
    print $prompt;

    require Term::ReadKey;
    Term::ReadKey::ReadMode('cbreak');
    Term::ReadKey::ReadKey(0);
    Term::ReadKey::ReadMode('normal');
    print "\n";
  }
}

with 'Dist::Zilla::Role::Chrome';

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Chrome::Term - chrome used for terminal-based interaction

=head1 VERSION

version 4.300007

=head1 OVERVIEW

This class provides a L<Dist::Zilla::Chrome> implementation for use in a
terminal environment.  It's the default chrome used by L<Dist::Zilla::App>.

=head1 AUTHOR

Ricardo SIGNES <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

