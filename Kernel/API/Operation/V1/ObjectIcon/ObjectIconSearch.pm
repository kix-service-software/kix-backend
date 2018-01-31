# --
# Kernel/API/Operation/ObjectIcon/ObjectIconCreate.pm - API ObjectIcon Create operation backend
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

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::ObjectIcon::ObjectIconGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ObjectIcon::ObjectIconSearch - API ObjectIcon Search Operation backend

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

perform ObjectIconSearch Operation. This will return a ObjectIcon list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ObjectIcon => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform ObjectIcon search
    my $ObjectIconList = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconList();

	# get already prepared ObjectIcon data from ObjectIconGet operation
    if ( IsArrayRefWithData($ObjectIconList) ) {  	
        my $ObjectIconGetResult = $Self->ExecOperation(
            OperationType => 'V1::ObjectIcon::ObjectIconGet',
            Data      => {
                ObjectIconID => join(',', sort @{$ObjectIconList}),
            }
        );    

        if ( !IsHashRefWithData($ObjectIconGetResult) || !$ObjectIconGetResult->{Success} ) {
            return $ObjectIconGetResult;
        }

        my @ObjectIconDataList = IsArrayRefWithData($ObjectIconGetResult->{Data}->{ObjectIcon}) ? @{$ObjectIconGetResult->{Data}->{ObjectIcon}} : ( $ObjectIconGetResult->{Data}->{ObjectIcon} );

        if ( IsArrayRefWithData(\@ObjectIconDataList) ) {
            return $Self->_Success(
                ObjectIcon => \@ObjectIconDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ObjectIcon => [],
    );
}

1;