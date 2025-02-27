# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::GeneralCatalog::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemUpdate - API GeneralCatalogItem Update Operation backend

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
        'GeneralCatalogItemID' => {
            Required => 1
        },
        'GeneralCatalogItem' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform GeneralCatalogItemUpdate Operation. This will return the updated GeneralCatalogItemID.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItemID => 123,
            GeneralCatalogItem  => {
                Class         => 'ITSM::Service::Type',     # (optional)
                Name          => 'Item Name',               # (optional)
                ValidID       => 1,                         # (optional)
                Comment       => 'Comment',                 # (optional)
                Preferences   => [                          # (optional)
                    {
                        Name => 'pref name',
                        Vaule => 'some value'
                    }
                ]
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            GeneralCatalogItemID  => 123,       # ID of the updated GeneralCatalogItem
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim GeneralCatalogItem parameter
    my $GeneralCatalogItem = $Self->_Trim(
        Data => $Param{Data}->{GeneralCatalogItem}
    );

    # check if GeneralCatalog exists
    my $GeneralCatalogData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        ItemID => $Param{Data}->{GeneralCatalogItemID},
    );

    if ( !$GeneralCatalogData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my $Class = $GeneralCatalogItem->{Class} || $GeneralCatalogData->{Class};
    if ( IsArrayRefWithData( $GeneralCatalogItem->{Preferences} ) ) {
        my $Result = $Self->_CheckPreferences(
            Preferences => $GeneralCatalogItem->{Preferences},
            Class       => $Class
        );
        if (!$Result->{Success}) {
            return $Self->_Error(
                Code    => $Result->{Code} || 'Object.UnableToUpdate',
                Message => $Result->{Message} || 'Preferences config check failed.',
            );
        }
    }

    # update GeneralCatalog
    my $Success = $Kernel::OM->Get('GeneralCatalog')->ItemUpdate(
        ItemID   => $Param{Data}->{GeneralCatalogItemID},
        Class    => $Class,
        Name     => $GeneralCatalogItem->{Name} || $GeneralCatalogData->{Name},
        Comment  => exists $GeneralCatalogItem->{Comment} ? $GeneralCatalogItem->{Comment} : $GeneralCatalogData->{Comment},
        ValidID  => $GeneralCatalogItem->{ValidID} || $GeneralCatalogData->{ValidID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # set known preferences
    if ( IsArrayRefWithData( $GeneralCatalogItem->{Preferences} ) ) {
        $Self->_SetPreferences(
            Preferences => $GeneralCatalogItem->{Preferences},
            Class       => $Class,
            ItemID      => $Param{Data}->{GeneralCatalogItemID}
        );
    }

    # return result
    return $Self->_Success(
        GeneralCatalogItemID => 0 + $Param{Data}->{GeneralCatalogItemID},
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
