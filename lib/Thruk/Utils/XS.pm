package Thruk::Utils::XS;

use 5.014002;
use strict;
use warnings;
use Carp qw/croak/;

require Exporter;
use AutoLoader;

our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT_OK   = qw();

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Thruk::Utils::XS::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
        no strict 'refs';
        *$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Thruk::Utils::XS', $VERSION);

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Thruk::Utils::XS - Thruk XS Utils

=head1 SYNOPSIS

  use Thruk::Utils::XS;

=head1 DESCRIPTION

Thruk::Utils::XS will be used automatically if available.

=head1 SEE ALSO

More information about Thruk is available on http://www.thruk.org

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
