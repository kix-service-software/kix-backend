# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::JobMacroIDCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobMacroIDCreate - API Job MacroID Create Operation backend

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
        'JobID' => {
            Required => 1
        },
        'MacroID' => {
            Required => 1
        }
    }
}

=item Run()

perform JobMacroIDCreate Operation. This will return the ID of the assigned Macro.

    my $Result = $OperationObject->Run(
        Data => {
            JobID   => 123,
            MacroID => 321
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            MacroID  => '',    # ID of the assigned Macro
            JobID    => '',    # ID of the relevant Job
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # assign Macro to Job
    my $Result = $Kernel::OM->Get('Automation')->JobMacroAdd(
        JobID    => $Param{Data}->{JobID},
        MacroID  => $Param{Data}->{MacroID},
        UserID   => $Self->{Authorization}->{UserID}
    );

    if ( !$Result ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code    => 'Object.Created',
        MacroID => 0 + $Param{Data}->{MacroID}
    );
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
