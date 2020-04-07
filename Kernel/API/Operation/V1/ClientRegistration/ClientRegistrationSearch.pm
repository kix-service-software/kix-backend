# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ClientRegistration::ClientRegistrationSearch - API ClientRegistration Search Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
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

perform ClientRegistrationSearch Operation. This will return a ClientRegistration list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ClientRegistration => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform ClientRegistration search
    my $ClientList = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();

	# get already prepared ClientRegistration data from ClientRegistrationGet operation
    if ( IsArrayRefWithData($ClientList) ) {  	
        my $ClientRegistrationGetResult = $Self->ExecOperation(
            OperationType            => 'V1::ClientRegistration::ClientRegistrationGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ClientID => join(',', @{$ClientList}),
            }
        );    

        if ( !IsHashRefWithData($ClientRegistrationGetResult) || !$ClientRegistrationGetResult->{Success} ) {
            return $ClientRegistrationGetResult;
        }

        my @ClientRegistrationDataList = IsArrayRef($ClientRegistrationGetResult->{Data}->{ClientRegistration}) ? @{$ClientRegistrationGetResult->{Data}->{ClientRegistration}} : ( $ClientRegistrationGetResult->{Data}->{ClientRegistration} );

        if ( IsArrayRefWithData(\@ClientRegistrationDataList) ) {
            return $Self->_Success(
                ClientRegistration => \@ClientRegistrationDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ClientRegistration => [],
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
