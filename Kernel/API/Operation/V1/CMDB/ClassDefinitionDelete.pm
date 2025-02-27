# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassDefinitionDelete;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassDefinitionDelete - API ClassDefinitionDelete Operation backend

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
        Valid => 1,
    );

    my @ClassIDs = sort keys %{$ItemList};

    return {
        'ClassID' => {
            DataType => 'NUMERIC',
            Required => 1,
            OneOf    => \@ClassIDs,
        },
        'DefinitionID' => {
            DataType => 'NUMERIC',
            Required => 1,
            Type     => 'ARRAY',
        },
    }
}

=item Run()

perform ClassDefinitionDelete Operation.

    my $Result = $OperationObject->Run(
        Data => {
            DefinitionID  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    foreach my $DefinitionID ( @{$Param{Data}->{DefinitionID}} ) {

        my $Definition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            DefinitionID => $DefinitionID,
        );

        if ( !IsHashRefWithData($Definition) ) {
            return $Self->_Error(
                Code => 'Object.NotFound'
            );
        }

        my $Success = $Kernel::OM->Get('ITSMConfigItem')->DefinitionDelete(
            DefinitionID => $DefinitionID,
            UserID       => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete class definition, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
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
