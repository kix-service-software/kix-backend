# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SLA::SLASearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SLA::SLAGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SLA::SLASearch - API SLA Search Operation backend

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

perform SLASearch Operation. This will return a SLA ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SLA => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform SLA search
    my %SLAList = $Kernel::OM->Get('Kernel::System::SLA')->SLAList(
        UserID  => $Self->{Authorization}->{UserID},
    );

	# get already prepared SLA data from SLAGet operation
    if ( IsHashRefWithData(\%SLAList) ) {  	
        my $SLAGetResult = $Self->ExecOperation(
            OperationType            => 'V1::SLA::SLAGet',
            SuppressPermissionErrors => 1,
            Data      => {
                SLAID => join(',', sort keys %SLAList),
            }
        );    

        if ( !IsHashRefWithData($SLAGetResult) || !$SLAGetResult->{Success} ) {
            return $SLAGetResult;
        }

        my @SLADataList = IsArrayRef($SLAGetResult->{Data}->{SLA}) ? @{$SLAGetResult->{Data}->{SLA}} : ( $SLAGetResult->{Data}->{SLA} );

        if ( IsArrayRefWithData(\@SLADataList) ) {
            return $Self->_Success(
                SLA => \@SLADataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SLA => [],
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
