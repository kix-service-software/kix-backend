# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
    'Config',
    'Contact',
    'DynamicField',
    'LinkObject',
    'Log',
    'Ticket',
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
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');
    $Self->{ContactObject} = $Kernel::OM->Get('Contact');
    $Self->{LinkObject}         = $Kernel::OM->Get('LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Log');
    $Self->{TicketObject}       = $Kernel::OM->Get('Ticket');

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
