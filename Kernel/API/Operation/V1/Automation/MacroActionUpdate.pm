# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroActionUpdate - API MacroAction Update Operation backend

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
            Required => 1
        },
        'MacroAction' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform MacroActionUpdate Operation. This will return the updated MacroActionID.

    my $Result = $OperationObject->Run(
        Data => {
            MacroID => 123,
            MacroActionID => 123,
            MacroAction  => {
                Type            => '...',                     # (optional)
                Parameters      => {},                        # (optional)
                ResultVariables => {},                        # (optional)
                Comment         => 'Comment',                 # (optional)
                ValidID         => 1,                         # (optional)
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            MacroActionID  => 123,       # ID of the updated MacroAction
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

    # check if MacroAction exists
    my %MacroActionData = $Kernel::OM->Get('Automation')->MacroActionGet(
        ID => $Param{Data}->{MacroActionID},
    );

    if ( !%MacroActionData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update MacroAction
    my $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID              => $Param{Data}->{MacroActionID},
        Type            => $MacroAction->{Type} || $MacroActionData{Type},
        Name            => $MacroAction->{Name} || $MacroActionData{Name},
        Parameters      => exists $MacroAction->{Parameters} ? $MacroAction->{Parameters} : $MacroActionData{Parameters},
        ResultVariables => exists $MacroAction->{ResultVariables} ? $MacroAction->{ResultVariables} : $MacroActionData{ResultVariables},
        Comment         => exists $MacroAction->{Comment} ? $MacroAction->{Comment} : $MacroActionData{Comment},
        ValidID         => exists $MacroAction->{ValidID} ? $MacroAction->{ValidID} : $MacroActionData{ValidID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        MacroActionID => 0 + $Param{Data}->{MacroActionID},
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
