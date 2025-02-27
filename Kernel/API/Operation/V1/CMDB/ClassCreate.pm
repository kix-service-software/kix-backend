# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassCreate - API Class Create Operation backend

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
        'ConfigItemClass' => {
            Type     => 'HASH',
            Required => 1
        },
        'ConfigItemClass::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform ClassCreate Operation. This will return the created ClassID.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItemClass  => {
                Name    => 'class name',
                ValidID => 1,
                Comment => 'Comment',              # (optional)
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ConfigItemClassID  => '',       # ID of the created ConfigItemClassID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ConfigItemClass parameter
    my $ConfigItemClass = $Self->_Trim(
        Data => $Param{Data}->{ConfigItemClass}
    );

    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    foreach my $Item ( keys %$ItemList ) {
        if ( $ItemList->{$Item} eq $ConfigItemClass->{Name} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot create class. A class with the same name '$ConfigItemClass->{Name}' already exists.",
            );
        }
    }

    # validate definition if given
    if ( $ConfigItemClass->{DefinitionString} ) {
        my $Check = $Self->_CheckDefinition(
            Definition => $ConfigItemClass->{DefinitionString},
        );

        if ( !$Check->{Success} ) {
            my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'error',
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => $LogMessage || 'Cannot create class. The given definition string is invalid.',
            );
        }
    }

    # create class
    my $GeneralCatalogItemID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ConfigItemClass->{Name},
        Comment  => $ConfigItemClass->{Comment} || '',
        ValidID  => $ConfigItemClass->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$GeneralCatalogItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create class, please contact the system administrator',
        );
    }

    if ( $ConfigItemClass->{DefinitionString} ) {
        my $Result = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ClassDefinitionCreate',
            Data          => {
                ClassID                   => $GeneralCatalogItemID,
                ConfigItemClassDefinition => {
                    DefinitionString => $ConfigItemClass->{DefinitionString}
                }
            }
        );

        if ( !$Result->{Success} ) {
            return $Self->_Error(
                %{$Result},
            )
        }
    }

    # return result
    return $Self->_Success(
        Code              => 'Object.Created',
        ConfigItemClassID => $GeneralCatalogItemID,
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
