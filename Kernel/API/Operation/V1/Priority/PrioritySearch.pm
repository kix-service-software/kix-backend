# --
# Kernel/API/Operation/Priority/PriorityCreate.pm - API Priority Create operation backend
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

package Kernel::API::Operation::V1::Priority::PrioritySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Priority::PriorityGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PrioritySearch - API Priority Search Operation backend

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

perform PrioritySearch Operation. This will return a Priority ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data         => {
            Priority => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Priority search
    my %PriorityList = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList(
        ValidID => 1,
    );

    if (IsHashRefWithData(\%PriorityList)) {
        my $PriorityGetResult = $Self->ExecOperation(
            OperationType => 'V1::Priority::PriorityGet',
            Data      => {
                PriorityID => join(',', sort keys %PriorityList),
            }
        );
 
        if ( !IsHashRefWithData($PriorityGetResult) || !$PriorityGetResult->{Success} ) {
            return $PriorityGetResult;
        }

        my @PriorityDataList = IsArrayRefWithData($PriorityGetResult->{Data}->{Priority}) ? @{$PriorityGetResult->{Data}->{Priority}} : ( $PriorityGetResult->{Data}->{Priority} );

        if ( IsArrayRefWithData(\@PriorityDataList) ) {
            return $Self->_Success(
                Priority => \@PriorityDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Priority => [],
    );
}

1;