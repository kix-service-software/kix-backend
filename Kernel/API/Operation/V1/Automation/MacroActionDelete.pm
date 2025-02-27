# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroActionDelete - API MacroAction Delete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'MacroID' => {
            Required => 1
        },
        'MacroActionID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform MacroActionDelete Operation. This will return {}.

    my $Result = $OperationObject->Run(
        Data => {
            MacroID => 123,
            MacroActionID  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if macro exists
    my %Macro = $Kernel::OM->Get('Automation')->MacroGet(
        ID => $Param{Data}->{MacroID},
    );

    if ( !%Macro ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # start loop
    foreach my $MacroActionID ( @{$Param{Data}->{MacroActionID}} ) {

        # check if macro action belongs to the given macro
        my %MacroAction = $Kernel::OM->Get('Automation')->MacroActionGet(
            ID      => $MacroActionID,
            UserID  => $Self->{Authorization}->{UserID},
        );
        if ( !IsHashRefWithData(\%MacroAction) || $MacroAction{MacroID} != $Param{Data}->{MacroID} ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # delete macro action
        my $Success = $Kernel::OM->Get('Automation')->MacroActionDelete(
            ID      => $MacroActionID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToDelete',
            );
        }
    }

    # return result
    return $Self->_Success();
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
