# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::DynamicFieldFromContact;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Contact',
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
    for my $Needed (qw(Data UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }
    for my $Needed (qw(TicketID)) {
        if ( !$Param{Data}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed! in Data",
            );
            return;
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get mapping config,
    my %Mapping = %{ $ConfigObject->Get('DynamicFieldFromContact::Mapping') || {} };

    # no mapping is OK
    return 1 if !%Mapping;

    # get customer user data, so that values can be stored in dynamic fields
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    return if !%Ticket;
    return if !$Ticket{ContactID};

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get dynamic fields list
    my $DynamicFields = $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ObjectType => 'Ticket',
        ResultType => 'HASH',
    );

    my $DynamicFieldsReverse = { reverse %{$DynamicFields} };

    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $Ticket{ContactID},
    );

    # also continue if there was no Contact data found - erase values
    # loop over the configured mapping of customer data variables to dynamic fields
    CUSTOMERUSERVARIABLENAME:
    for my $ContactVariableName ( sort keys %Mapping ) {

        # check config for the particular mapping
        if ( !defined $DynamicFieldsReverse->{ $Mapping{$ContactVariableName} } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "DynamicField $Mapping{$ContactVariableName} in DynamicFieldFromContact::Mapping must be set in system and valid.",
            );
            next CUSTOMERUSERVARIABLENAME;
        }

        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $Mapping{$ContactVariableName},
        );

        # update dynamic field value for ticket
        $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{Data}->{TicketID},
            Value              => $ContactData{$ContactVariableName} || '',
            UserID             => $Param{UserID},
        );
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
