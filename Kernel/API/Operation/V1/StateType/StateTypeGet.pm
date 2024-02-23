# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::StateType::StateTypeGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StateType::StateTypeGet - API StateType Get Operation backend

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
        'StateTypeID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform StateTypeGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            StateTypeID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            StateType => [
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

    my @StateTypeList;

    # start loop
    foreach my $StateTypeID ( @{$Param{Data}->{StateTypeID}} ) {

        # get the StateType data
        my $StateTypeName = $Kernel::OM->Get('State')->StateTypeLookup(
            StateTypeID => $StateTypeID,
        );

        if ( !$StateTypeName ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        my %StateType;

        $StateType{ID} = $StateTypeID;
        $StateType{Name} = $StateTypeName;

        # add
        push(@StateTypeList, \%StateType);
    }

    if ( scalar(@StateTypeList) == 1 ) {
        return $Self->_Success(
            StateType => $StateTypeList[0],
        );
    }

    # return result
    return $Self->_Success(
        StateType => \@StateTypeList,
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
