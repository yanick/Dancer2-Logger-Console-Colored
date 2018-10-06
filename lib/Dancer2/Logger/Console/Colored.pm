package Dancer2::Logger::Console::Colored;
# ABSTRACT: Dancer2 colored console logger.
# COPYRIGHT

BEGIN {
  # VERSION: generated by DZP::OurPkgVersion
}

use Term::ANSIColor;
use Moo;
use Dancer2::Core::Types qw( ArrayRef HashRef Str );

extends 'Dancer2::Logger::Console';

use namespace::clean;

has colored_origin => (
  is  => 'rw',
  isa => Str,
);

has colored_levels => (
  is      => 'rw',
  isa     => HashRef [Str],
  default => sub { {} },
);

has colored_messages => (
  is      => 'rw',
  isa     => HashRef [Str],
  default => sub { {} },
);

has colored_regex => (
  is      => 'rw',
  isa     => ArrayRef [ HashRef [Str] ],
  default => sub { [] },
);

sub colorize_origin {
  my ( $self, $string ) = @_;

  # Configured color.
  return colored( $string, $self->colored_origin ) if $self->colored_origin;

  # Default colors.
  return colored( $string, 'cyan' );
}

sub colorize_level {
  my ( $self, $level ) = @_;
  my $level_tmp = $level =~ s/\s+//gr;
  $level_tmp = 'warning' if $level_tmp eq 'warn';

  # Configured color.
  return colored( $level, $self->colored_levels->{$level_tmp} ) if $self->colored_levels->{$level_tmp};

  # Default colors.
  return colored( $level, 'bold bright_white' )  if $level_tmp eq 'core';
  return colored( $level, 'bold bright_blue' )   if $level_tmp eq 'debug';
  return colored( $level, 'bold green' )         if $level_tmp eq 'info';
  return colored( $level, 'bold yellow' )        if $level_tmp eq 'warning';
  return colored( $level, 'bold yellow on_red' ) if $level_tmp eq 'error';
  return colored( $level, 'bold magenta' );
}

sub colorize_message {
  my ( $self, $level, $message ) = @_;
  my $level_tmp = $level =~ s/\s+//gr;
  $level_tmp = 'warning' if $level_tmp eq 'warn';

  # Check for regex match.
  foreach my $pattern ( @{ $self->colored_regex } ) {
    if ($message =~ m/$pattern->{re}/) {
      $message =~ s{($pattern->{re})}{colored($1, $pattern->{color} )}eg;
      return $message;
    }
  }

  # Configured color.
  return colored( $message, $self->colored_messages->{$level_tmp} ) if $self->colored_messages->{$level_tmp};

  # Default colors.
  return colored( $message, 'bold bright_white' )  if $level_tmp eq 'core';
  return colored( $message, 'bold bright_blue' )   if $level_tmp eq 'debug';
  return colored( $message, 'bold green' )         if $level_tmp eq 'info';
  return colored( $message, 'bold yellow' )        if $level_tmp eq 'warning';
  return colored( $message, 'bold yellow on_red' ) if $level_tmp eq 'error';
  return colored( $message, 'bold magenta' );
}

# This comes original from Dancer2::Logger::Console. There are a few hooks
# required in order to colorize log messages propably.
sub format_message {
  my ( $self, $level, $message ) = @_;
  chomp $message;

  $level = sprintf( '%5s', $level );
  $message = Encode::encode( $self->auto_encoding_charset, $message )
    if $self->auto_encoding_charset;

  my @stack = caller(8);

  my $block_handler = sub {
    my ( $block, $type ) = @_;
    if ( $type eq 't' ) {
      return "[" . strftime( $block, localtime(time) ) . "]";
    }
    else {
      Carp::carp("{$block}$type not supported");
      return "-";
    }
  };

  my $chars_mapping = {
    a => sub { $self->colorize_origin( $self->app_name ) },
    t => sub {
      Encode::decode(
        setting('charset'),
        POSIX::strftime( "%d/%b/%Y %H:%M:%S", localtime(time) ) );
    },
    T => sub { POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime(time) ) },
    P => sub { $$ },
    L => sub { $self->colorize_level($level) },
    m => sub { $self->colorize_message( $level => $message ) },
    f => sub { $self->colorize_origin( $stack[1] || '-' ) },
    l => sub { $self->colorize_origin( $stack[2] || '-' ) },
  };

  my $char_mapping = sub {
    my $char = shift;

    my $cb = $chars_mapping->{$char};
    if ( !$cb ) {
      Carp::carp "\%$char not supported.";
      return "-";
    }
    $cb->($char);
  };

  my $fmt = $self->log_format;

  $fmt =~ s/
        (?:
            \%\{(.+?)\}([a-z])|
            \%([a-zA-Z])
        )
    / $1 ? $block_handler->($1, $2) : $char_mapping->($3) /egx;

  return $fmt . "\n";
}

1;

__END__

=pod

=head1 DESCRIPTION

This is a logging engine that allows you to print colored debug messages on
the standard error output. It is based on L<Dancer2::Logger::Console>. Refer
to its documentation for how to configure the format of your log message.

=head2 log

Writes the log message to the console.

=head1 CONFIGURATION

The setting C<logger> should be set to C<Console::Colored> in order to use
this logging engine in a Dancer2 application.

    # environment.yml or production.yml
    logger: "Console::Colored"

    # config.yml (these are the defaults)
    engines:
      logger:
        Console::Colored:
          colored_origin: "cyan"
          colored_levels:
            core: "bold bright_white"
            debug: "bold bright_blue"
            info: "bold green"
            warning: "bold yellow"
            error: "bold yellow on_red"
          colored_messages:
            core: "bold bright_white"
            debug: "bold bright_blue"
            info: "bold green"
            warning: "bold yellow"
            error: "bold yellow on_red"

=head2 Using Regex

You can also provide a configuration key C<colored_regex>, which will allow you
to give multiple pairs of regular expression patterns and colors. The logger will
then change the colors of anything that matches a pattern according to the configuration.

To enable it, use this (additional) configuration.

          colored_regex:
            - re: "customer number \d+"
              color: "bold red"

It can also be used to highlight full lines. Just provide a pattern that grabs everything.

          colored_regex:
            - re: ".+error.+"
              color: "white on_red"

Note that in YAML and other config formats, the pattern can only be a string. If you enable
this from within your application, you also also need to supply a string, not a C<qr//>.

    $logger->colored_regex(
        [
            {
                re    => 'foobar',
                color => 'cyan',
            },
            {
                re    => '\d+',
                color => 'magenta',
            },
        ]
    );

=head1 BREAKING CHANGES

If you are running on L<Dancer2> older than 0.166001_01 you will need to use
L<Dancer2::Logger::Console::Colored> version 0.001 because L<Dancer2> changed
the way the logging was handled.

=head1 SEE ALSO

L<Dancer2::Logger::Console>, L<Dancer2::Core::Role::Logger>,
L<Term::ANSIColor>

=for Pod::Coverage 
    colorize_message colorize_origin format_message colorize_level

=cut
