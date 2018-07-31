# --
# Kernel/API/Operation/Lock/LockSearch.pm - API Lock Search operation backend
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

package Kernel::API::Operation::V1::Lock::LockSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Lock::LockGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Lock::LockSearch - API Lock Search Operation backend

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

perform LockSearch Operation. This will return a Lock ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Lock => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Lock search
    my %LockList = $Kernel::OM->Get('Kernel::System::Lock')->LockList(
        UserID => $Self->{Authorization}->{UserID},
    );

	# get already prepared Lock data from LockGet operation
    if ( IsHashRefWithData(\%LockList) ) {  	
        my $LockGetResult = $Self->ExecOperation(
            OperationType => 'V1::Lock::LockGet',
            Data      => {
                LockID => join(',', sort keys %LockList),
            }
        );    

        if ( !IsHashRefWithData($LockGetResult) || !$LockGetResult->{Success} ) {
            return $LockGetResult;
        }

        my @LockDataList = IsArrayRefWithData($LockGetResult->{Data}->{Lock}) ? @{$LockGetResult->{Data}->{Lock}} : ( $LockGetResult->{Data}->{Lock} );

        if ( IsArrayRefWithData(\@LockDataList) ) {
            return $Self->_Success(
                Lock => \@LockDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Lock => [],
    );
}

1;