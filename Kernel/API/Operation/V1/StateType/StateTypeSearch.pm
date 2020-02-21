# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::StateType::StateTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::StateType::StateTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::StateType::StateTypeSearch - API StateType Search Operation backend

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

perform StateTypeSearch Operation. This will return a StateType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            StateType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform StateType search
    my %StateTypeList = $Kernel::OM->Get('Kernel::System::State')->StateTypeList(
        UserID => $Self->{Authorization}->{UserID},
        Valid => 1,
    );

	# get already prepared StateType data from StateTypeGet operation
    if ( IsHashRefWithData(\%StateTypeList) ) {  	
        my $StateTypeGetResult = $Self->ExecOperation(
            OperationType => 'V1::StateType::StateTypeGet',
            Data      => {
                StateTypeID => join(',', sort keys %StateTypeList),
            }
        );    

        if ( !IsHashRefWithData($StateTypeGetResult) || !$StateTypeGetResult->{Success} ) {
            return $StateTypeGetResult;
        }

        my @StateTypeDataList = IsArrayRef($StateTypeGetResult->{Data}->{StateType}) ? @{$StateTypeGetResult->{Data}->{StateType}} : ( $StateTypeGetResult->{Data}->{StateType} );

        if ( IsArrayRefWithData(\@StateTypeDataList) ) {
            return $Self->_Success(
                StateType => \@StateTypeDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        StateType => [],
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
