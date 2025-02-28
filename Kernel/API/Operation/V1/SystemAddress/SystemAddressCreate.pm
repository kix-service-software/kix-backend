# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SystemAddress::SystemAddressCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SystemAddress::SystemAddressCreate - API SystemAddress SystemAddressCreate Operation backend

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
        'SystemAddress' => {
            Type     => 'HASH',
            Required => 1
        },
        'SystemAddress::Name' => {
            Required => 1
        },
        'SystemAddress::Realname' => {
            Required => 1
        },
    }
}

=item Run()

perform SystemAddressCreate Operation. This will return the created SystemAddressID.

    my $Result = $OperationObject->Run(
        Data => {
            SystemAddress  => {
                Name     => 'info@example.com',
                Realname => 'Hotline',
                ValidID  => 1,
                Comment  => 'some comment',
            },
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            SystemAddressID  => '',                         # ID of the created SystemAddress
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim SystemAddress parameter
    my $SystemAddress = $Self->_Trim(
        Data => $Param{Data}->{SystemAddress},
    );

    # check if SystemAddress exists
    my $Exists = $Kernel::OM->Get('SystemAddress')->SystemAddressLookup(
        Name => $SystemAddress->{Name},
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create SystemAddress. SystemAddress with the name '$SystemAddress->{Name}' already exists.",
        );
    }

    # create SystemAddress
    my $SystemAddressID = $Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
        Name     => $SystemAddress->{Name},
        Comment  => $SystemAddress->{Comment} || '',
        ValidID  => $SystemAddress->{ValidID} || 1,
        Realname => $SystemAddress->{Realname},
        QueueID  => $SystemAddress->{QueueID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$SystemAddressID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create SystemAddress, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        SystemAddressID => $SystemAddressID,
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
