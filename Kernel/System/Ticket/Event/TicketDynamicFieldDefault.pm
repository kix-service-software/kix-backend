# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketDynamicFieldDefault;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'DynamicField::Backend',
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # get settings from sysconfig
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my $CacheKey = '_TicketDynamicFieldDefault::AlreadyProcessed';

    # loop protection: only execute this handler once for each ticket
    return if ( $TicketObject->{$CacheKey}->{ $Param{Data}->{TicketID} } );

    # get ticket data in silent mode, it could be that the ticket was deleted
    # in the meantime
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 1,
        Silent        => 1,
    );

    if ( !%Ticket ) {

        # remember that the event was executed for this TicketID to avoid multiple executions
        # store the information in the ticket object
        $TicketObject->{$CacheKey}->{ $Param{Data}->{TicketID} } = 1;

        return;
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get the dynamic fields
    my $DynamicField = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    # get settings from sysconfig
    my $ConfigSettings = $Kernel::OM->Get('Config')->Get('Ticket::TicketDynamicFieldDefault');

    # create a lookup table by name (since name is unique)
    my %DynamicFieldLookup;
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicField} ) {

        next DYNAMICFIELD if !$DynamicField->{Name};

        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    ELEMENT:
    for my $ElementName ( sort keys %{$ConfigSettings} ) {

        my $Element = $ConfigSettings->{$ElementName};

        if ( $Param{Event} eq $Element->{Event} ) {

            # do not set default dynamic field if already set
            next ELEMENT if $Ticket{ 'DynamicField_' . $Element->{Name} };

            # check if field is defined and valid
            next ELEMENT if !$DynamicFieldLookup{ $Element->{Name} };

            # get dynamic field config
            my $DynamicFieldConfig = $DynamicFieldLookup{ $Element->{Name} };

            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Param{Data}->{TicketID},
                Value              => $Element->{Value},
                UserID             => $Param{UserID},
            );

            if ( !$Success ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Cannot set value $Element->{Value} for dynamic field $Element->{Name}!"
                );
            }
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
