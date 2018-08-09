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

package Kernel::API::Operation::V1::CMDB::ConfigItemVersionCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemVersionCreate - API ConfigItemVersion Create Operation backend

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
        'ConfigItemID' => {
            Required => 1,
        },
        'Version' => {
            Required => 1,
            Type     => 'HASH'
        },
        'Version::Name' => {
            Required => 1,
        },
        'Version::DeplStateID' => {
            Required => 1,
        },
        'Version::InciStateID' => {
            Required => 1,
        },
    }
}

=item Run()

perform ConfigItemVersionCreate Operation. This will return the created VersionID.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItemID => 123,
            Version => {
                ...                                
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            VersionID  => '',                       # VersionID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    # isolate and trim Version parameter
    my $Version = $Self->_Trim(
        Data => $Param{Data}->{Version}
    );

    # get config item data
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID}
    );

    # check if ConfigItem exists
    if ( !$ConfigItem ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ConfigItem $Param{Data}->{ConfigItemID}",
        );
    }

    # check create permissions
    my $Permission = $Self->CheckCreatePermission(
        ConfigItem => $ConfigItem,
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create a version for this ConfigItem!",
        );
    }

    # check ConfigItem attribute values
    my $VersionCheck = $Self->_CheckConfigItemVersion( 
        ConfigItem => $ConfigItem,
        Version    => $Version
    );

    if ( !$VersionCheck->{Success} ) {
        return $Self->_Error(
            %{$VersionCheck},
        );
    }

    # get current definition
    my $DefinitionData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->DefinitionGet(
        ClassID => $ConfigItem->{ClassID},
    );

    if ( !IsHashRefWithData($DefinitionData) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "Unable to get current definition of CI Class!",
        );
    }
    
    my $FormattedData;
    if ( $Version->{Data} ) {
        $FormattedData = $Self->ConvertDataToInternal(
            Data => $Version->{Data},
        );
    }

    # everything is ok, let's create the version
    my $VersionID = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionAdd(
        %{$ConfigItem},
        DefinitionID => $DefinitionData->{DefinitionID},
        DeplStateID  => $Version->{DeplStateID},
        InciStateID  => $Version->{InciStateID},
        Name         => $Version->{Name},
        XMLData      => $FormattedData,
        UserID       => $Self->{Authorization}->{UserID},
    );

    return $Self->_Success(
        Code      => 'Object.Created',
        VersionID => $VersionID,
    )
}

=begin Internal:

1;

=end Internal: