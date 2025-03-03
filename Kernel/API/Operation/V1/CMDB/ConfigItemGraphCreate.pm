# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemGraphCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemGraphCreate - API ConfigItemGraph Create Operation backend

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
        'ConfigItemID' => {
            Required => 1,
        },
    }
}

=item Run()

perform ConfigItemGraphCreate Operation. This will return the created graph.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItemID => 123,
            ConfigItemLinkGraphConfig  => {
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            Graph  => {
                ...
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get config item data
    my $Exist = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
        ConfigItemID => $Param{Data}->{ConfigItemID}
    );

    # check if ConfigItem exists
    if ( !$Exist ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # isolate and trim GraphConfig parameter
    my $GraphConfig;
    if ( $Param{Data}->{ConfigItemLinkGraphConfig} ) {
        $GraphConfig = $Self->_Trim(
            Data => $Param{Data}->{ConfigItemLinkGraphConfig}
        );
    }

    # everything is ok, let's create the image
    my $Graph = $Kernel::OM->Get('ITSMConfigItem')->GenerateLinkGraph(
        ConfigItemID => $Param{Data}->{ConfigItemID},
        Config       => $GraphConfig,
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$Graph ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    return $Self->_Success(
        Code  => 'Object.Created',
        Graph => $Graph,
    )
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
