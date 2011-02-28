package Geo::BUFR::EC;

use 5.010001;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Geo::BUFR::EC ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Geo::BUFR::EC', $VERSION);

# Preloaded methods go here.

1;
__END__

=head1 NAME

Geo::BUFR::EC - Perl extension for the LibECBUFR library

=head1 SYNOPSIS

  use Geo::BUFR::EC;

=head1 DESCRIPTION

Stub documentation for Geo::BUFR::EC, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

=head2 EXPORT

None by default.

=head1 SEE ALSO

L<http://launchpad.net/libecbufr>

=head1 AUTHOR

Christophe Beauregard, E<lt>chris.beauregard@ec.gc.caE<gt>

=head1 COPYRIGHT AND LICENSE

Licence:
Copyright Her Majesty The Queen in Right of Canada, Environment Canada, 2009-2010.
Copyright Sa Majeste la Reine du Chef du Canada, Environnement Canada, 2009-2010.

    libECBUFR is free software: you can redistribute it and/or modify
    it under the terms of the Lesser GNU General Public License,
    version 3, as published by the Free Software Foundation.

    libECBUFR is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    Lesser GNU General Public License for more details.

    You should have received a copy of the Lesser GNU General Public
    License along with libECBUFR.  If not, see <http://www.gnu.org/licenses/>.

=cut
