# --
# Kernel/API/Operation/ConfigItem/ConfigItemCreate.pm - API ConfigItem Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
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

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # get valid CLassIDs
    my $ItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );
    my @ClassIDs = sort keys %{$ItemList};

    # prepare data (first check)
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'ConfigItem' => {
                Required => 1,
                Type     => 'HASH'
            },
            'ConfigItem::ClassID' => {
                Required => 1,
                OneOf    => \@ClassIDs,
            }
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }
    
    # isolate and trim ConfigItem parameter
    my $ConfigItem = $Self->_Trim(
        Data => $Param{Data}->{ConfigItem}
    );

    # check create permissions
    my $Permission = $Self->CheckCreatePermission(
        ConfigItem => $ConfigItem,
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create ConfigItems for this class!",
        );
    }

    # check ConfigItem attribute values
    my $ConfigItemCheck = $Self->_CheckConfigItem( 
        ConfigItem => $ConfigItem
    );


    if ( !$ConfigItemCheck->{Success} ) {
        return $Self->_Error(
            %{$ConfigItemCheck},
        );
    }

    # everything is ok, let's create the ConfigItem
    return $Self->_ConfigItemCreate(
        ConfigItem => $ConfigItem,
        UserID     => $Self->{Authorization}->{UserID},
    );
}

=begin Internal:

=item _ConfigItemCreate()

creates a configuration item.

    my $Response = $OperationObject->_ConfigItemCreate(
        ConfigItem     => $ConfigItem,             # all configuration item parameters
        UserID         => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everything is OK
        Data => {
            ConfigItemID => 123,
        }
    }

    $Response = {
        Success      => 0,                         # if unexpected error
        Code         => '...'
        Message      => '...',
    }
=cut

sub _ConfigItemCreate {
    my ( $Self, %Param ) = @_;

    my $ConfigItem = $Param{ConfigItem};

    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # create new config item
    my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => $ConfigItem->{Number},
        ClassID => $Self->{ReverseClassList}->{ $ConfigItem->{Class} },
        UserID  => $Param{UserID},
    );
# TODO!!!
    if ( !$ConfigItemID ) {
        return $Self->_Error(
            Code    => '',
            Message => 'Configuration Item could not be created, please contact the system administrator',
        );
    }

    # set attachments
    if ( IsArrayRefWithData($AttachmentList) ) {

        for my $Attachment ( @{$AttachmentList} ) {
            my $Result = $Self->CreateAttachment(
                Attachment   => $Attachment,
                ConfigItemID => $ConfigItemID,
                UserID       => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                my $ErrorMessage =
                    $Result->{ErrorMessage} || "Attachment could not be created, please contact the system administrator";

                return {
                    Success      => 0,
                    ErrorMessage => $ErrorMessage,
                };
            }
        }
    }

    # get ConfigItem data
    my $ConfigItemData = $ConfigItemObject->ConfigItemGet(
        ConfigItemID => $ConfigItemID,
    );

    if ( !IsHashRefWithData($ConfigItemData) ) {
        return {
            Success      => 0,
            ErrorMessage => 'Could not get new configuration item information, please contact the system administrator',
        };
    }

    return {
        Success => 1,
        Data    => {
            ConfigItemID => $ConfigItemID,
            Number       => $ConfigItemData->{Number},
        },
    };
}

1;

=end Internal:
