# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::ITSMConfigItemLinkAdd;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'LinkObject',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject}       = $Kernel::OM->Get('Config');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');
    $Self->{LinkObject}         = $Kernel::OM->Get('LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # handle only with configured link type
    return 1 if ( !$Param{Config}->{LinkType} );

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
    return 1 if ( $Param{Data}->{DynamicFieldConfig}->{FieldType} ne 'ITSMConfigItemReference' );

    return 1 if ( !IsArrayRefWithData( $Param{Data}->{Value} ) );

    for my $Value ( @{ $Param{Data}->{Value} } ) {
        # add links to database
        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $Param{Data}->{TicketID},
            TargetObject => 'ConfigItem',
            TargetKey    => $Value,
            Type         => $Param{Config}->{LinkType},
            UserID       => $Param{UserID},
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
