# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::GeneralCatalog::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemCreate - API GeneralCatalogItem Create Operation backend

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
        'GeneralCatalogItem' => {
            Type     => 'HASH',
            Required => 1
        },
        'GeneralCatalogItem::Class' => {
            Required => 1
        },
        'GeneralCatalogItem::Name' => {
            Required => 1
        }
    }
}

=item Run()

perform GeneralCatalogItemCreate Operation. This will return the created GeneralCatalogItemItemID.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItem  => {
                Class       => 'ITSM::Service::Type',
                Name        => 'Item Name',
                ValidID     => 1,
                Comment     => 'Comment',              # (optional)
                Preferences => [                       # (optional)
                    {
                        Name => 'pref name',
                        Vaule => 'some value'
                    }
                ]
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      #
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            GeneralCatalogItemID  => '',    # ID of the created GeneralCatalogItem
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim GeneralCatalogItem parameter
    my $GeneralCatalogItem = $Self->_Trim(
        Data => $Param{Data}->{GeneralCatalogItem}
    );

    if ( IsArrayRefWithData( $GeneralCatalogItem->{Preferences} ) ) {
        my $Result = $Self->_CheckPreferences(
            Preferences => $GeneralCatalogItem->{Preferences},
            Class       => $GeneralCatalogItem->{Class}
        );
        if (!$Result->{Success}) {
            return $Self->_Error(
                Code    => $Result->{Code} || 'Object.UnableToCreate',
                Message => $Result->{Message} || 'Preferences config check failed.',
            );
        }
    }

    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => $GeneralCatalogItem->{Class},
    );

    foreach my $Item ( keys %$ItemList ) {
        if ( $ItemList->{$Item} eq $GeneralCatalogItem->{Name} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot create GeneralCatalog item. GeneralCatalog item with the name '$GeneralCatalogItem->{Name}' already exists.",
            );
        }
    }

    # create GeneralCatalog
    my $GeneralCatalogItemID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
        Class    => $GeneralCatalogItem->{Class},
        Name     => $GeneralCatalogItem->{Name},
        Comment  => $GeneralCatalogItem->{Comment} || '',
        ValidID  => $GeneralCatalogItem->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$GeneralCatalogItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create GeneralCatalog item, please contact the system administrator',
        );
    }

    # set known preferences
    if ( IsArrayRefWithData( $GeneralCatalogItem->{Preferences} ) ) {
        $Self->_SetPreferences(
            Preferences => $GeneralCatalogItem->{Preferences},
            Class       => $GeneralCatalogItem->{Class},
            ItemID      => $GeneralCatalogItemID
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        GeneralCatalogItemID => $GeneralCatalogItemID,
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
