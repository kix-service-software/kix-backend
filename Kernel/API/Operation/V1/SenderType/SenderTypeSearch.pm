# --
# Kernel/API/Operation/SenderType/SenderTypeCreate.pm - API SenderType Create operation backend
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

package Kernel::API::Operation::V1::SenderType::SenderTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SenderType::SenderTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SenderType::SenderTypeSearch - API SenderType Search Operation backend

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

perform SenderTypeSearch Operation. This will return a SenderType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SenderType => [
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

    # perform SenderType search
    my %SenderTypeList = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleSenderTypeList(
        Result => 'HASH',
#        Type   => 'Customer', # optional to get only customer viewable article types
    );

	# get already prepared SenderType data from SenderTypeGet operation
    if ( IsHashRefWithData(\%SenderTypeList) ) {  	
        my $SenderTypeGetResult = $Self->ExecOperation(
            OperationType => 'V1::SenderType::SenderTypeGet',
            Data      => {
                SenderTypeID => join(',', sort keys %SenderTypeList),
            }
        );    

        if ( !IsHashRefWithData($SenderTypeGetResult) || !$SenderTypeGetResult->{Success} ) {
            return $SenderTypeGetResult;
        }

        my @SenderTypeDataList = IsArrayRefWithData($SenderTypeGetResult->{Data}->{SenderType}) ? @{$SenderTypeGetResult->{Data}->{SenderType}} : ( $SenderTypeGetResult->{Data}->{SenderType} );

        if ( IsArrayRefWithData(\@SenderTypeDataList) ) {
            return $Self->_Success(
                SenderType => \@SenderTypeDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SenderType => [],
    );
}

1;