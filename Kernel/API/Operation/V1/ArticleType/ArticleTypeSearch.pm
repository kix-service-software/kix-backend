# --
# Kernel/API/Operation/ArticleType/ArticleTypeCreate.pm - API ArticleType Create operation backend
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

package Kernel::API::Operation::V1::ArticleType::ArticleTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::ArticleType::ArticleTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ArticleType::ArticleTypeSearch - API ArticleType Search Operation backend

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

perform ArticleTypeSearch Operation. This will return a ArticleType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ArticleType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform ArticleType search
    my %ArticleTypeList = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeList(
        Result => 'HASH',
    );

	# get already prepared ArticleType data from ArticleTypeGet operation
    if ( IsHashRefWithData(\%ArticleTypeList) ) {  	
        my $ArticleTypeGetResult = $Self->ExecOperation(
            OperationType => 'V1::ArticleType::ArticleTypeGet',
            Data      => {
                ArticleTypeID => join(',', sort keys %ArticleTypeList),
            }
        );    

        if ( !IsHashRefWithData($ArticleTypeGetResult) || !$ArticleTypeGetResult->{Success} ) {
            return $ArticleTypeGetResult;
        }

        my @ArticleTypeDataList = IsArrayRefWithData($ArticleTypeGetResult->{Data}->{ArticleType}) ? @{$ArticleTypeGetResult->{Data}->{ArticleType}} : ( $ArticleTypeGetResult->{Data}->{ArticleType} );

        if ( IsArrayRefWithData(\@ArticleTypeDataList) ) {
            return $Self->_Success(
                ArticleType => \@ArticleTypeDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ArticleType => [],
    );
}

1;