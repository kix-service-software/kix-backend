# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::DynamicFieldSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'DynamicField',
    'DynamicField::Backend'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::DynamicFieldSet - A module to set a dynamic field value of a ticket

=head1 SYNOPSIS

All DynamicFieldSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets a dynamic field value of a ticket.'));
    $Self->AddOption(
        Name         => 'ObjectID',
        Label        => Kernel::Language::Translatable('Object ID'),
        Description  => Kernel::Language::Translatable('The ID of the object to which the value of the dynamic field should be set. If omitted, "${ObjectID}" is used'),
        Required     => 0,
        DefaultValue => '${ObjectID}',
        Placeholder => {
            Richtext  => 0,
            Translate => 0,
        },
    );
    $Self->AddOption(
        Name        => 'DynamicFieldName',
        Label       => Kernel::Language::Translatable('Dynamic Field Name'),
        Description => Kernel::Language::Translatable('The name of the dynamic field.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'DynamicFieldValue',
        Label       => Kernel::Language::Translatable('Dynamic Field Value'),
        Description => Kernel::Language::Translatable('The value for the dynamic field to be set. Leave empty and uncheck "Append" to clear relevant dynamic field value of ticket.'),
        Required    => 0,
        Placeholder => {
            Richtext  => 0,
            Translate => 1,
        },
    );
    $Self->AddOption(
        Name        => 'DynamicFieldAppend',
        Label       => Kernel::Language::Translatable('Append'),
        Description => Kernel::Language::Translatable('Specifies whether the new value should be appended or set.'),
        Required    => 0,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            DynamicFieldName  => 'SomeDFName',
            DynamicFieldValue => 'New Value'
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    # get required DynamicField config
    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => $Param{Config}->{DynamicFieldName},
    );

    # check if we have a valid DynamicField
    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Can't get DynamicField config for DynamicField: \"$Param{Config}->{DynamicFieldName}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my $ObjectID = $Param{Config}->{ObjectID} || $Param{ObjectID} || $Self->{RootObjectID};

    if (!$ObjectID) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "No ObjectID given!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my %Object;
    if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
        %Object = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $ObjectID,
            DynamicFields => 1
        );
    } elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {
        %Object = $Kernel::OM->Get('Ticket')->ArticleGet(
            ArticleID     => $ObjectID,
            DynamicFields => 1,
        );
    }

    if (!%Object) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't get $DynamicFieldConfig->{ObjectType} with id \"$ObjectID\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my @NewValue = $Self->_PrepareValue(
        %Param,
        Object => \%Object
    );

    # set the new value
    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $ObjectID,
        Value              => \@NewValue,
        UserID             => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting dynamic field \"$Param{Config}->{DynamicFieldName}\" failed!",
            UserID   => $Param{UserID}
        );
        return;
    }

    return 1;
}


sub _PrepareValue {
    my ( $Self, %Param ) = @_;

    my @NewValue;
    if ( defined( $Param{Config}->{DynamicFieldValue} ) ) {
        if ( IsArrayRefWithData( $Param{Config}->{DynamicFieldValue} ) ) {
            @NewValue = @{ $Param{Config}->{DynamicFieldValue} };
        } elsif ( defined( $Param{Config}->{DynamicFieldValue} ) ) {
            @NewValue = ( $Param{Config}->{DynamicFieldValue} );
        }
    }

    if (
        $Param{Config}->{DynamicFieldAppend}
        && $Param{Object}->{ 'DynamicField_'. $Param{Config}->{DynamicFieldName} }
    ) {
        if ( IsArrayRefWithData( $Param{Object}->{ 'DynamicField_' . $Param{Config}->{DynamicFieldName} } ) ) {
            unshift( @NewValue, @{ $Param{Object}->{ 'DynamicField_' . $Param{Config}->{DynamicFieldName} } } );
        } else {
            unshift( @NewValue, $Param{Object}->{ 'DynamicField_' . $Param{Config}->{DynamicFieldName} } );
        }
    }

    return $Kernel::OM->Get('Main')->GetUnique(@NewValue);
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
