# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassDefinitionCreate;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassDefinitionCreate - API ClassDefinitionCreate Operation backend

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

    # get valid ClassIDs
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 0,
    );

    my @ClassIDs = sort keys %{$ItemList};

    return {
        'ClassID' => {
            Required => 1,
            OneOf    => \@ClassIDs,
        },
        'ConfigItemClassDefinition' => {
            Type     => 'HASH',
            Required => 1,
        },
        'ConfigItemClassDefinition::DefinitionString' => {
            Required => 1,
        },
    }
}

=item Run()

perform ClassDefinitionCreate Operation.

    my $Result = $OperationObject->ClassDefinitionCreate(
        ClassID = 123,
        Data => {
            ...
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ConfigItemClassDefinitionID  => '',     # ConfigItemClassDefinitionID
        },
    };


=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ConfigItemClassDefinition parameter
    my $Definition = $Self->_Trim(
        Data => $Param{Data}->{ConfigItemClassDefinition}
    );

    my $DefinitionCheck = $Self->_CheckDefinition(
        ClassID    => $Param{Data}->{ClassID},
        Definition => $Definition->{DefinitionString},
    );

    if ( !$DefinitionCheck->{Success} ) {
        return $Self->_Error(
            %{$DefinitionCheck},
        );
    }

    my $ConfigItemClassDefinitionID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
        ClassID    => $Param{Data}->{ClassID},
        Definition => $Definition->{DefinitionString},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ConfigItemClassDefinitionID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    return $Self->_Success(
        Code                        => 'Object.Created',
        ConfigItemClassDefinitionID => $ConfigItemClassDefinitionID,
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
