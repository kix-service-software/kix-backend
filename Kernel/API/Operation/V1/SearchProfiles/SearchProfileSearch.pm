# --
# Kernel/API/Operation/SearchProfile/SearchProfileSearch.pm - API SearchProfile Search operation backend
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

package Kernel::API::Operation::V1::SearchProfile::SearchProfileSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SearchProfile::SearchProfileGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SearchProfile::SearchProfileSearch - API SearchProfile Search Operation backend

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

perform SearchProfileSearch Operation. This will return a SearchProfile ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SearchProfile => [
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
            Code    => 'WebService.InvalidConfiguration',
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

    # perform SearchProfile search
    my %SearchProfileList = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileList();

	# get already prepared SearchProfile data from SearchProfileGet operation
    if ( IsHashRefWithData(\%SearchProfileList) ) {  	
        my $SearchProfileGetResult = $Self->ExecOperation(
            OperationType => 'V1::SearchProfile::SearchProfileGet',
            Data      => {
                SearchProfileID => join(',', sort keys %SearchProfileList),
            }
        );    

        if ( !IsHashRefWithData($SearchProfileGetResult) || !$SearchProfileGetResult->{Success} ) {
            return $SearchProfileGetResult;
        }

        my @SearchProfileDataList = IsArrayRefWithData($SearchProfileGetResult->{Data}->{SearchProfile}) ? @{$SearchProfileGetResult->{Data}->{SearchProfile}} : ( $SearchProfileGetResult->{Data}->{SearchProfile} );

        if ( IsArrayRefWithData(\@SearchProfileDataList) ) {
            return $Self->_Success(
                SearchProfile => \@SearchProfileDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SearchProfile => [],
    );
}

1;