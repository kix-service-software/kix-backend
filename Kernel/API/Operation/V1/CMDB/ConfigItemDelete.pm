# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemDelete;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemDelete - API ConfigItemDelete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
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
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform Operation. 

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required 
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    # if necessary check if config item is accessible for current customer user
    my $CustomerCheck = $Self->_CheckCustomerAssignedConfigItem(
        ConfigItemIDList => $Param{Data}->{ConfigItemID}
    );
    if ( !$CustomerCheck->{Success} ) {
        return $Self->_Error(
            %{$CustomerCheck},
        );
    }

    foreach my $ConfigItemID ( @{$Param{Data}->{ConfigItemID}} ) {

        my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        if (!IsHashRefWithData($ConfigItem)) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }     

        my $Success = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemDelete(
            ConfigItemID => $ConfigItemID,
            UserID       => $Self->{Authorization}->{UserID}
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToDelete',
            );
        }
    }

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
