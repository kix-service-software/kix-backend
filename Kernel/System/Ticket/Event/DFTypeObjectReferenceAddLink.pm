# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::DFTypeObjectReferenceAddLink;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Contact
    LinkObject
    Log
    ObjectSearch
    Ticket
);

=item new()

create an object.

=cut

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
    for (qw(Data Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Need $_!"
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # handle only TicketDynamicFieldUpdate events
    return 1 if ( $Param{Event} !~ m/^TicketDynamicFieldUpdate_/ );
    if ( !IsHashRefWithData( $Param{Data}->{DynamicFieldConfig} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need DynamicFieldConfig in Data!',
        );
        return;
    }

    # check for relevant field type
    return 1 if ( $Param{Data}->{DynamicFieldConfig}->{FieldType} ne 'Contact' );

    return 1 if ( !IsArrayRefWithData( $Param{Data}->{Value} ) );

    # check in customer backend for this login
    my @ContactList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Contact',
        Result     => 'ARRAY',
        UserID     => $Param{UserID},
        Search => {
            AND => [
                {
                    Field    => 'Login',
                    Operator => 'EQ',
                    Value    => $Param{Data}->{Value}
                }
            ]
        }
    );

    for my $ContactID ( @ContactList ) {
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID
        );

        # add links to database
        my $Success = $Kernel::OM->Get('LinkObject')->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $ContactData{UserLogin},
            TargetObject => 'Ticket',
            TargetKey    => $Param{Data}->{TicketID},
            Type         => 'Customer',
            UserID       => $Param{UserID},
        );

        $Kernel::OM->Get('Ticket')->HistoryAdd(
            Name         => 'added involved person ' . $ContactData{UserLogin},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Param{Data}->{TicketID},
            CreateUserID => 1,
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
