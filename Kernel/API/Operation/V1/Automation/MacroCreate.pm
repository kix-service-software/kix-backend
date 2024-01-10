# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroCreate - API Macro Create Operation backend

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
    my @MacroTypes;

    if ( IsHashRefWithData($Kernel::OM->Get('Config')->Get('Automation::MacroType')) ) {
        @MacroTypes = sort keys %{ $Kernel::OM->Get('Config')->Get('Automation::MacroType') };
    }

    return {
        'Macro' => {
            Type     => 'HASH',
            Required => 1
        },
        'Macro::Type' => {
            Required => 1,
            OneOf    => \@MacroTypes,
        },
        'Macro::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform MacroCreate Operation. This will return the created MacroID.

    my $Result = $OperationObject->Run(
        Data => {
            Macro  => {
                Name    => 'Item Name',
                Type    => 'Ticket',
                Comment => 'Comment',              # optional
                ValidID => 1,                      # optional
                Actions => [                       # optional
                    {
                        Type    => '...',
                        Parameters => {},              # optional
                        Comment => 'Comment',          # optional
                        ValidID => 1,                  # optional
                    },
                    ...
                ]
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            MacroID  => '',    # ID of the created Macro
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Macro parameter
    my $Macro = $Self->_Trim(
        Data => $Param{Data}->{Macro}
    );

    my $MacroID = $Kernel::OM->Get('Automation')->MacroLookup(
        Name => $Macro->{Name},
    );

    if ( $MacroID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create macro. A macro with the same name '$Macro->{Name}' already exists.",
        );
    }

    # create Macro
    $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
        Name      => $Macro->{Name},
        Type      => $Macro->{Type},
        Comment   => $Macro->{Comment} || '',
        ValidID   => $Macro->{ValidID} || 1,
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !$MacroID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    my @ExecOrder;

    # create actions
    if ( IsArrayRefWithData( $Macro->{Actions} ) ) {
        foreach my $Action ( @{ $Macro->{Actions} } ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Automation::MacroActionCreate',
                Data          => {
                    MacroID     => $MacroID,
                    MacroAction => $Action,
                }
            );

            if ( !$Result->{Success} ) {

                # cleanup
                # delete macro actions
                for my $ActionID (@ExecOrder) {
                    $Kernel::OM->Get('Automation')->MacroActionDelete(
                        ID     => $ActionID,
                        UserID => $Self->{Authorization}->{UserID},
                    );
                }

                # delete macro
                $Kernel::OM->Get('Automation')->MacroDelete(
                    ID     => $MacroID,
                    UserID => $Self->{Authorization}->{UserID},
                );

                return $Self->_Error(
                    %{$Result},
                )
            }

            push(@ExecOrder, $Result->{Data}->{MacroActionID});
        }
    }

    if (scalar @ExecOrder) {
        my $Result = $Self->ExecOperation(
            OperationType => 'V1::Automation::MacroUpdate',
            Data          => {
                MacroID  => $MacroID,
                Macro    => {
                    ExecOrder => \@ExecOrder
                },
            }
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        MacroID => $MacroID,
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
