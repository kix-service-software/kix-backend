# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionTypeGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroActionTypeGet - API MacroActionType Get Operation backend

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
        'MacroType' => {
            Required => 1
        },
        'MacroActionType' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform MacroActionGet Operation. This function is able to return
one or more entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MacroType => 'Ticket'
            MacroActionType => 'StateSet'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            MacroActionType => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @MacroActionTypeList;

    my $MacroActionTypesCommon = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::Common');

    my $MacroActionTypes = $Kernel::OM->Get('Config')->Get('Automation::MacroActionType::'.$Param{Data}->{MacroType});

    # start loop
    foreach my $MacroActionType ( @{$Param{Data}->{MacroActionType}} ) {

	    # get the MacroActionType data
	    my %MacroActionTypeData = $Kernel::OM->Get('Automation')->MacroActionTypeGet(
            MacroType => $Param{Data}->{MacroType},
	        Name      => $MacroActionType,
	    );

        if ( !%MacroActionTypeData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add some more data
        $MacroActionTypeData{Name}        = $MacroActionType;
        $MacroActionTypeData{DisplayName} = $MacroActionTypes->{$MacroActionType}->{DisplayName} || $MacroActionTypesCommon->{$MacroActionType}->{DisplayName};
        $MacroActionTypeData{MacroType}   = $Param{Data}->{MacroType},

        # add
        push(@MacroActionTypeList, \%MacroActionTypeData);
    }

    if ( scalar(@MacroActionTypeList) == 1 ) {
        return $Self->_Success(
            MacroActionType => $MacroActionTypeList[0],
        );
    }

    # return result
    return $Self->_Success(
        MacroActionType => \@MacroActionTypeList,
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
