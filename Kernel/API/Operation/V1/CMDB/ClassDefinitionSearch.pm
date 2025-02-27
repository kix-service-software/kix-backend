# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassDefinitionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ClassDefinitionSearch - API CMDB Search Operation backend

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
    }
}

=item Run()

perform ClassDefinitionSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
            ClassID => 123                      # required
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItemClassDefinition => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    # check if ClassID exists in GeneralCatalog
    my $ItemData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        ItemID  => $Param{Data}->{ClassID},
    );

    if (!IsHashRefWithData($ItemData) || $ItemData->{Class} ne 'ITSM::ConfigItem::Class') {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # get definitions for given class
    my $DefinitionList = $Kernel::OM->Get('ITSMConfigItem')->DefinitionList(
        ClassID => $Param{Data}->{ClassID}
    );

	# get already prepared definition data from ClassDefinitionGet operation
    if ( IsArrayRefWithData($DefinitionList) ) {
        # prepare ID list
        my @DefinitionIDs;
        foreach my $Definition (@{$DefinitionList}) {
            push(@DefinitionIDs, $Definition->{DefinitionID});
        }

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::CMDB::ClassDefinitionGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ClassID      => $Param{Data}->{ClassID},
                DefinitionID => join(',', sort @DefinitionIDs),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConfigItemClassDefinition} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConfigItemClassDefinition}) ? @{$GetResult->{Data}->{ConfigItemClassDefinition}} : ( $GetResult->{Data}->{ConfigItemClassDefinition} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConfigItemClassDefinition => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItemClass => [],
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
