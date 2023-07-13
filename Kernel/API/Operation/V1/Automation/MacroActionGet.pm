# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroActionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroActionGet - API MacroAction Get Operation backend

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
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform MacroActionGet Operation. This function is able to return
one or more job entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MacroID => 123,
            MacroActionID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            MacroAction => [
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

    my @MacroActionList;

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

	    # get the MacroAction data
	    my %MacroActionData = $Kernel::OM->Get('Automation')->MacroActionGet(
	        ID => $MacroActionID,
	    );

        if ( !%MacroActionData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( $MacroActionData{MacroID} != $Param{Data}->{MacroID} ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@MacroActionList, \%MacroActionData);
    }

    if ( scalar(@MacroActionList) == 1 ) {
        return $Self->_Success(
            MacroAction => $MacroActionList[0],
        );
    }

    # return result
    return $Self->_Success(
        MacroAction => \@MacroActionList,
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
