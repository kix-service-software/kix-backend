# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SystemAddress::SystemAddressUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SystemAddress::SystemAddressUpdate - API SystemAddress Create Operation backend

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
        'SystemAddressID' => {
            Required => 1
        },
        'SystemAddress' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform SystemAddressUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SystemAddressID => 123,
            SystemAddress  => {
                Name     => 'info@example.com',
                Realname => 'Hotline',
                ValidID  => 1,
                Comment  => 'some comment',
            },
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SystemAddressID  => 123,                     # ID of the updated SystemAddress
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
    my %SystemAddressData = $Kernel::OM->Get('SystemAddress')->SystemAddressGet(
        ID => $Param{Data}->{SystemAddressID},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !%SystemAddressData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update SystemAddress
    my $Success = $Kernel::OM->Get('SystemAddress')->SystemAddressUpdate(
        ID       => $Param{Data}->{SystemAddressID},
        Name     => $SystemAddress->{Name} || $SystemAddressData{Name},
        Comment  => exists $SystemAddress->{Comment} ? $SystemAddress->{Comment} : $SystemAddressData{Comment},
        ValidID  => $SystemAddress->{ValidID} || $SystemAddressData{ValidID},
        Realname => $SystemAddress->{Realname} || $SystemAddressData{Realname},
        QueueID  => exists $SystemAddress->{QueueID} ? $SystemAddress->{QueueID} : $SystemAddressData{QueueID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        SystemAddressID => $Param{Data}->{SystemAddressID},
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
