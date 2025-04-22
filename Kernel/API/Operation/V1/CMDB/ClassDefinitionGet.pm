# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassDefinitionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassDefinitionGet - API ClassDefinitionGet Operation backend

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
        'ClassID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'DefinitionID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ClassDefinitionGet Operation.

    my $Result = $OperationObject->Run(
        ClassID      => 1,                                # required
        DefinitionID => 1                                 # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItemClassDefinition => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @DefinitionList;
    foreach my $DefinitionID ( @{$Param{Data}->{DefinitionID}} ) {

        my $DefinitionRef = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            DefinitionID => $DefinitionID,
        );

        if (!IsHashRefWithData($DefinitionRef) || $DefinitionRef->{ClassID} != $Param{Data}->{ClassID}) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        my %Definition = %{$DefinitionRef};

        # rename some attributes
        $Definition{DefinitionString} = $Definition{Definition};
        $Definition{Definition}       = $Definition{DefinitionRef};
        delete $Definition{DefinitionRef};

        push(@DefinitionList, \%Definition);
    }

    if ( scalar(@DefinitionList) == 0 ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }
    elsif ( scalar(@DefinitionList) == 1 ) {
        return $Self->_Success(
            ConfigItemClassDefinition => $DefinitionList[0],
        );
    }

    return $Self->_Success(
        ConfigItemClassDefinition => \@DefinitionList,
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
