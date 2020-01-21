# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::DFTypeObjectReferenceAddLink;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Contact',
    'Kernel::System::DynamicField',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{ContactObject} = $Kernel::OM->Get('Kernel::System::Contact');
    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}       = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_ in Data!" );
            return;
        }
    }

    # get current ticket data
    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 1,
    );

    # check event
    if ( $Param{Event} =~ /TicketDynamicFieldUpdate_(.*)/ ) {

        my $Field = "DynamicField_" . $1;
        my $DynamicFieldData =
            $Self->{DynamicFieldObject}->DynamicFieldGet( Name => $1 );

        # nothing to do if Danamic Field not of type Contact or if customer was deleted
        return if ( $DynamicFieldData->{FieldType} ne "Contact" );
        return if ( !$Ticket{$Field} );
        return
            if ( ref( $Ticket{$Field} ) eq 'ARRAY'
            && scalar( @{ $Ticket{$Field} } )
            && !$Ticket{$Field}->[0] );

        # check in customer backend for this login
        my %UserListCustomer =
            $Self->{ContactObject}
            ->CustomerSearch( UserLogin => $Ticket{$Field}->[0], );

        for my $CurrUserID ( keys(%UserListCustomer) ) {

            my %ContactData = $Self->{ContactObject}->ContactGet( ID => $CurrUserID, );

            # add links to database
            my $Success = $Self->{LinkObject}->LinkAdd(
                SourceObject => 'Person',
                SourceKey    => $ContactData{UserLogin},
                TargetObject => 'Ticket',
                TargetKey    => $Ticket{TicketID},
                Type         => 'Customer',
                UserID       => $Param{UserID},
            );

            $Self->{TicketObject}->HistoryAdd(
                Name         => 'added involved person ' . $UserListCustomer{$CurrUserID},
                HistoryType  => 'TicketLinkAdd',
                TicketID     => $Ticket{TicketID},
                CreateUserID => 1,
            );
        }

    }

    return 1;
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
