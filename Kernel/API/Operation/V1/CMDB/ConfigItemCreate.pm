# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemCreate - API ConfigItem Create Operation backend

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
        'ConfigItem' => {
            Required => 1,
            Type     => 'HASH'
        },
        'ConfigItem::ClassID' => {
            Required => 1,
            OneOf    => \@ClassIDs,
        },
        'ConfigItem::Version' => {
            Required => 1,
            Type     => 'HASH'
        },
        'ConfigItem::Version::Name' => {
            Required => 1,
        },
        'ConfigItem::Version::DeplStateID' => {
            Required => 1,
        },
        'ConfigItem::Version::InciStateID' => {
            Required => 1,
        },
    }
}

=item Run()

perform ConfigItemCreate Operation. This will return the created ConfigItemLogin.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItem => {
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ConfigItemID  => '',                    # ConfigItemID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ConfigItem parameter
    my $ConfigItem = $Self->_Trim(
        Data => $Param{Data}->{ConfigItem}
    );

    # check ConfigItem attribute values
    my $ConfigItemCheck = $Self->_CheckConfigItem(
        ConfigItem => $ConfigItem
    );

    if ( !$ConfigItemCheck->{Success} ) {
        return $Self->_Error(
            %{$ConfigItemCheck},
        );
    }

    # create new config item
    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        Number  => $ConfigItem->{Number},
        ClassID => $ConfigItem->{ClassID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$ConfigItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Configuration Item could not be created, please contact the system administrator',
        );
    }

    # create images
    if ( IsArrayRefWithData($ConfigItem->{Images}) ) {
        foreach my $Image ( @{$ConfigItem->{Images}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ConfigItemImageCreate',
                Data          => {
                    ConfigItemID => $ConfigItemID,
                    Image        => $Image,
                }
            );

            if ( !$Result->{Success} ) {
                return $Result;
            }
        }
    }

    # create version
    if ( IsHashRefWithData($ConfigItem->{Version}) ) {
        my $Result = $Self->ExecOperation(
            OperationType           => 'V1::CMDB::ConfigItemVersionCreate',
            IgnoreParentPermissions => 1,
            Data                    => {
                ConfigItemID           => $ConfigItemID,
                ConfigItemVersion      => $ConfigItem->{Version},
                RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}                
            }
        );
        if ( IsHashRefWithData($Result) && !$Result->{Success} ) {
            return $Result;
        }
    }

    return $Self->_Success(
        Code         => 'Object.Created',
        ConfigItemID => 0 + $ConfigItemID,
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
