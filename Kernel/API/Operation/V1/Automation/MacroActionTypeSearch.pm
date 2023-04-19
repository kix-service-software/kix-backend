# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::MacroActionTypeSearch - API Automation Macro Action Type Search Operation backend

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
        'MacroType' => {
            Required => 1
        }
    }
}

=item Run()

perform MacroActionTypeSearch Operation. This will return a list macro types.

    my $Result = $OperationObject->Run(
        Data => {
            MacroType => 'Ticket'
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MacroActionType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get common MacroAction types which are available for all macro types
    my $MacroActionTypesCommon = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::Common');

    # get MacroAction types for given macro type
    my $MacroActionTypes = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::'.$Param{Data}->{MacroType});

    # merge common types
    $MacroActionTypes = {
        %{$MacroActionTypesCommon || {}},
        %{$MacroActionTypes || {}}
    };

	# get already prepared MacroActionType data from MacroActionTypeGet operation
    if ( IsHashRefWithData($MacroActionTypes) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::Automation::MacroActionTypeGet',
            Data      => {
                MacroType       => $Param{Data}->{MacroType},
                MacroActionType => join(',', sort keys %{$MacroActionTypes}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{MacroActionType} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{MacroActionType}) ? @{$GetResult->{Data}->{MacroActionType}} : ( $GetResult->{Data}->{MacroActionType} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                MacroActionType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        MacroActionType => [],
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
