# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroActionCreate - API MacroAction Create Operation backend

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
        'MacroAction' => {
            Type     => 'HASH',
            Required => 1
        },
        'MacroAction::Type' => {
            Required => 1,
        },
    }
}

=item Run()

perform MacroActionCreate Operation. This will return the created MacroActionID.

    my $Result = $OperationObject->Run(
        Data => {
            MacroID => 123,
            MacroAction  => {
                Type            => '...',
                Parameters      => {},                  # optional
                ResultVariables => {},                  # optional
                Comment         => 'Comment',              # optional
                ValidID         => 1,                      # optional
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            MacroActionID  => '',    # ID of the created MacroAction
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MacroAction parameter
    my $MacroAction = $Self->_Trim(
        Data => $Param{Data}->{MacroAction}
    );

    # check if macro exists
    my %Macro = $Kernel::OM->Get('Automation')->MacroGet(
        ID => $Param{Data}->{MacroID},
    );

    if ( !%Macro ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # create macro
    my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
        MacroID         => $Param{Data}->{MacroID},
        Type            => $MacroAction->{Type},
        Parameters      => $MacroAction->{Parameters},
        ResultVariables => $MacroAction->{ResultVariables},
        Comment         => $MacroAction->{Comment} || '',
        ValidID         => $MacroAction->{ValidID} || 1,
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$MacroActionID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        MacroActionID => 0 + $MacroActionID,
    );
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
