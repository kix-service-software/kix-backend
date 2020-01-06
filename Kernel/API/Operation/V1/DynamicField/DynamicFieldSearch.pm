# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::DynamicField::DynamicFieldGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::DynamicField::DynamicFieldSearch - API DynamicField Search Operation backend

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

perform DynamicFieldSearch Operation. This will return a DynamicField ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            DynamicField => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform DynamicField search
    my $DynamicFieldList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(Valid => 0);

	# get already prepared DynamicField data from DynamicFieldGet operation
    if ( IsArrayRefWithData($DynamicFieldList) ) {  	
        my $DynamicFieldGetResult = $Self->ExecOperation(
            OperationType => 'V1::DynamicField::DynamicFieldGet',
            Data      => {
                DynamicFieldID => join(',', sort @{$DynamicFieldList}),
                include        => $Param{Data}->{include},
            }
        );    

        if ( !IsHashRefWithData($DynamicFieldGetResult) || !$DynamicFieldGetResult->{Success} ) {
            return $DynamicFieldGetResult;
        }

        my @DynamicFieldDataList = IsArrayRefWithData($DynamicFieldGetResult->{Data}->{DynamicField}) ? @{$DynamicFieldGetResult->{Data}->{DynamicField}} : ( $DynamicFieldGetResult->{Data}->{DynamicField} );

        if ( IsArrayRefWithData(\@DynamicFieldDataList) ) {
            return $Self->_Success(
                DynamicField => \@DynamicFieldDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        DynamicField => [],
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
