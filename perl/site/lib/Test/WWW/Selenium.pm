package Test::WWW::Selenium;
{
  $Test::WWW::Selenium::VERSION = '1.32';
}
# ABSTRACT: Test applications using Selenium Remote Control
use strict;
use base qw(WWW::Selenium);
use Carp qw(croak);


use Test::More;
use Test::Builder;

our $AUTOLOAD;

my $Test = Test::Builder->new;
$Test->exported_to(__PACKAGE__);

my %comparator = (
    is       => 'is_eq',
    isnt     => 'isnt_eq',
    like     => 'like',
    unlike   => 'unlike',
);

# These commands don't require a locator
# grep item lib/WWW/Selenium.pm | grep sel | grep \(\) | grep get
my %no_locator = map { $_ => 1 }
                qw( speed alert confirmation prompt location title
                    body_text all_buttons all_links all_fields
                    mouse_speed all_window_ids all_window_names
                    all_window_titles html_source cookie absolute_location );

sub no_locator {
    my $self   = shift;
    my $method = shift;
    return $no_locator{$method};
}

sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    return if $name eq 'DESTROY';
    my $self = $_[0];

    my $sub;
    if ($name =~ /(\w+)_(is|isnt|like|unlike)$/i) {
        my $getter = "get_$1";
        my $comparator = $comparator{lc $2};

        # make a subroutine that will call Test::Builder's test methods
        # with selenium data from the getter
        if ($self->no_locator($1)) {
            $sub = sub {
                my( $self, $str, $name ) = @_;
                diag "Test::WWW::Selenium running $getter (@_[1..$#_])"
                    if $self->{verbose};
                $name = "$getter, '$str'"
                    if $self->{default_names} and !defined $name;
                no strict 'refs';
                my $rc = $Test->$comparator( $self->$getter, $str, $name );
                if (!$rc && $self->error_callback) {
                    &{$self->error_callback}($name);
                }
                return $rc;
            };
        }
        else {
            $sub = sub {
                my( $self, $locator, $str, $name ) = @_;
                diag "Test::WWW::Selenium running $getter (@_[1..$#_])"
                    if $self->{verbose};
                $name = "$getter, $locator, '$str'"
                    if $self->{default_names} and !defined $name;
                no strict 'refs';
                my $rc = $Test->$comparator( $self->$getter($locator), $str, $name );
                if (!$rc && $self->error_callback) {
                    &{$self->error_callback}($name);
                }
		return $rc;
            };
        }
    }
    elsif ($name =~ /(\w+?)_?ok$/i) {
        my $cmd = $1;

        # make a subroutine for ok() around the selenium command
        $sub = sub {
            my( $self, $arg1, $arg2, $name ) = @_;
            if ($self->{default_names} and !defined $name) {
                $name = $cmd;
                $name .= ", $arg1" if defined $arg1;
                $name .= ", $arg2" if defined $arg2;
            }
            diag "Test::WWW::Selenium running $cmd (@_[1..$#_])"
                    if $self->{verbose};

            local $Test::Builder::Level = $Test::Builder::Level + 1;
            my $rc = '';
            eval { $rc = $self->$cmd( $arg1, $arg2 ) };
            die $@ if $@ and $@ =~ /Can't locate object method/;
            diag($@) if $@;
            $rc = ok( $rc, $name );
            if (!$rc && $self->error_callback) {
                &{$self->error_callback}($name);
            }
            return $rc;
        };
    }

    # jump directly to the new subroutine, avoiding an extra frame stack
    if ($sub) {
        no strict 'refs';
        *{$AUTOLOAD} = $sub;
        goto &$AUTOLOAD;
    }
    else {
        # try to pass through to WWW::Selenium
        my $sel = 'WWW::Selenium';
        my $sub = "${sel}::${name}";
        goto &$sub if exists &$sub;
        my ($package, $filename, $line) = caller;
        die qq(Can't locate object method "$name" via package ")
            . __PACKAGE__
            . qq(" (also tried "$sel") at $filename line $line\n);
    }
}

sub new {
    my ($class, %opts) = @_;
    my $default_names = defined $opts{default_names} ?
                            delete $opts{default_names} : 1;
    my $error_callback = defined $opts{error_callback} ?
	                    delete $opts{error_callback} : undef;
    my $self = $class->SUPER::new(%opts);
    $self->{default_names} = $default_names;
    $self->{error_callback} = $error_callback;
    $self->start;
    return $self;
}

sub error_callback {
    my ($self, $cb) = @_;
    if (defined($cb)) {
        $self->{error_callback} = $cb;
    }
    return $self->{error_callback};
}


sub debug {
    my $self = shift;
    require Devel::REPL;
    my $repl = Devel::REPL->new(prompt => 'Selenium$ ');
    $repl->load_plugin($_) for qw/History LexEnv Colors Selenium Interrupt/;
    $repl->selenium($self);
    $repl->lexical_environment->do($repl->selenium_lex_env);
    $repl->run;
}

1;



=pod

=head1 NAME

Test::WWW::Selenium - Test applications using Selenium Remote Control

=head1 VERSION

version 1.32

=head1 SYNOPSIS

Test::WWW::Selenium is a subclass of L<WWW::Selenium> that provides
convenient testing functions.

    use Test::More tests => 5;
    use Test::WWW::Selenium;

    # Parameters are passed through to WWW::Selenium
    my $sel = Test::WWW::Selenium->new( host => "localhost",
                                        port => 4444,
                                        browser => "*firefox",
                                        browser_url => "http://www.google.com",
                                        default_names => 1,
                                        error_callback => sub { ... },
                                      );

    # use special test wrappers around WWW::Selenium commands:
    $sel->open_ok("http://www.google.com", undef, "fetched G's site alright");
    $sel->type_ok( "q", "hello world");
    $sel->click_ok("btnG");
    $sel->wait_for_page_to_load_ok(5000);
    $sel->title_like(qr/Google Search/);
    $sel->error_callback(sub {...});

=head1 DESCRIPTION

This module is a L<WWW::Selenium> subclass providing some methods
useful for writing tests. For each Selenium command (open, click,
type, ...) there is a corresponding C<< <command>_ok >> method that
checks the return value (open_ok, click_ok, type_ok).

For each Selenium getter (get_title, ...) there are four autogenerated
methods (C<< <getter>_is >>, C<< <getter>_isnt >>, C<< <getter>_like >>,
C<< <getter>_unlike >>) to check the value of the attribute.

By calling the constructor with C<default_names> set to a true value your
tests will be given a reasonable name should you choose not to provide
one of your own.  The test name should always be the third argument.

=head1 NAME

Test::WWW::Selenium - Test applications using Selenium Remote Control

=head1 REQUIREMENTS

To use this module, you need to have already downloaded and started the
Selenium Server.  (The Selenium Server is a Java application.)

=head1 ADDITIONAL METHODS

Test::WWW::Selenium also provides some other handy testing functions
that wrap L<WWW::Selenium> commands:

=over 4

=item get_location

Returns the relative location of the current page.  Works with
_is, _like, ... methods.

=item error_callback

Sets the method to use when a corresponding selenium test is called and fails.
For example if you call text_like(...) and it fails the sub defined in the
error_callback will be called. This allows you to perform various tasks to
obtain additional details that occured when obtianing the error. If this is
set to undef then the callback will not be issued.

=back

=over 4

=item $sel-E<gt>debug()

Starts an interactive shell to pass commands to Selenium.

Commands are run against the selenium object, so you just need to type:

=item eg: click("link=edit")

=back

=head1 AUTHORS

=over 4

=item *

Maintained by: Matt Phillips <mattp@cpan.org>, Luke Closs <lukec@cpan.org>

=item *

Originally by Mattia Barbon <mbarbon@cpan.org>

=back

=head1 CONTRIBUTORS

Dan Dascalescu

Scott McWhirter

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 Matt Phillips <mattp@cpan.org>

Copyright (c) 2006 Luke Closs <lukec@cpan.org>

Copyright (c) 2005, 2006 Mattia Barbon <mbarbon@cpan.org>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


__END__

