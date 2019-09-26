# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::KIXSidebarCustomer;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::System::Contact',
    'Kernel::System::LinkObject'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ContactObject} = $Kernel::OM->Get('Kernel::System::Contact');
    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');

    return $Self;
}

sub KIXSidebarCustomerSearch {
    my ( $Self, %Param ) = @_;

    my %Result;

    # get linked objects
    if ( $Param{TicketID} && $Param{LinkMode} && $Param{LinkType} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'Person',
            State   => $Param{LinkMode},
            Type    => $Param{LinkType},
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {
            my %Contact = $Self->{ContactObject}->ContactGet(
                ID => $ID,
            );

            if (
                %Contact
                && defined $Contact{Source}
                && defined $Contact{ValidID}
                && "$Contact{ValidID}" eq "1"
            ) {

                SOURCE:
                for my $Source ( @{ $Param{CustomerBackends} } ) {
                    if ($Contact{Source} eq $Source) {
                        $Result{ $ID } = \%Contact;
                        $Result{ $ID }->{'Link'} = 1;
                        last SOURCE;
                    }
                }

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );

            }
        }
    }

    # Search only if Search-String was given
    if ( $Param{SearchString} ) {

        my %Customers = $Self->{ContactObject}->CustomerSearch(
            Search => $Param{SearchString},
            Valid  => 1,
        );

        ID:
        for my $ID ( keys %Customers ) {
            next ID if ( $Result{ $ID } );

            my %Contact = $Self->{ContactObject}->ContactGet(
                ID => $ID,
            );

            if (
                %Contact
                && defined $Contact{Source}
                && defined $Contact{ValidID}
                && "$Contact{ValidID}" eq "1"
            ) {

                SOURCE:
                for my $Source ( @{ $Param{CustomerBackends} } ) {
                    if ($Contact{Source} eq $Source) {
                        $Result{ $ID } = \%Contact;
                        $Result{ $ID }->{'Link'} = 0;
                        last SOURCE;
                    }
                }

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }

    }

    return \%Result;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
