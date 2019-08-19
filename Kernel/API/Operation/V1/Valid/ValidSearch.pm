# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Valid::ValidSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Valid::ValidGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Valid::ValidSearch - API Valid Search Operation backend

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

perform ValidSearch Operation. This will return a Valid ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Valid => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Valid search
    my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

	# get already prepared Valid data from ValidGet operation
    if ( IsHashRefWithData(\%ValidList) ) {  	
        my $ValidGetResult = $Self->ExecOperation(
            OperationType => 'V1::Valid::ValidGet',
            Data      => {
                ValidID => join(',', sort keys %ValidList),
            }
        );    

        if ( !IsHashRefWithData($ValidGetResult) || !$ValidGetResult->{Success} ) {
            return $ValidGetResult;
        }

        my @ValidDataList = IsArrayRefWithData($ValidGetResult->{Data}->{Valid}) ? @{$ValidGetResult->{Data}->{Valid}} : ( $ValidGetResult->{Data}->{Valid} );

        if ( IsArrayRefWithData(\@ValidDataList) ) {
            return $Self->_Success(
                Valid => \@ValidDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Valid => [],
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
