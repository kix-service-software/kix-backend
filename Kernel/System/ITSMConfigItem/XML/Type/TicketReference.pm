# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::TicketReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Ticket'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::TicketReference - xml backend module

=head1 SYNOPSIS

All xml functions of TicketReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::TicketReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject}    = $Kernel::OM->Get('Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Ticket');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{Value};

    my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
        TicketID => $Param{Value},
    );

    if ( !$TicketNumber ) {
        $TicketNumber = $Param{Value};
    }

    return $TicketNumber;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup number for given Ticket ID
    my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
        TicketID => $Param{Value},
    );
    if ( $TicketNumber ) {
        return $TicketNumber;
    }

    return '';
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup number for given Ticket ID
    my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
        TicketID => $Param{Value},
    );
    if ( $TicketNumber ) {
        return $TicketNumber;
    }

    return '';
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if Ticket number was given
    my $TicketID = $Self->{TicketObject}->TicketIDLookup(
        TicketNumber => $Param{Value},
    );
    return $TicketID if $TicketID;

    # check if given value is a valid Ticket ID
    if ( $Param{Value} !~ /\D/ ) {
        my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
            TicketID => $Param{Value},
        );
        return $Param{Value} if $TicketNumber;
    }

    return '';
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if Ticket number was given
    my $TicketID = $Self->{TicketObject}->TicketIDLookup(
        TicketNumber => $Param{Value},
    );
    return $TicketID if $TicketID;

    # check if given value is a valid Ticket ID
    if ( $Param{Value} !~ /\D/ ) {
        my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
            TicketID => $Param{Value},
        );
        return $Param{Value} if $TicketNumber;
    }

    return '';
}

1;


=head1 VERSION

$Revision$ $Date$

=cut




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
