# --# --
# Kernel/API/Operation/FAQ/FAQArticleSearch.pm - API FAQArticle Search operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleHistorySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleHistorySearch - API FAQArticle History Search Operation backend

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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'FAQArticleID' => {
            Required => 1
        },      
    }
}

=item Run()

perform FAQArticleHistorySearch Operation. This will return a FAQArticleHistory ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQHistory => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform FAQHistory search (at the moment without any filters - we do filtering in the API)
    my $HistoryIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQHistoryList(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQArticleHistoryGet operation
    if ( IsArrayRefWithData($HistoryIDs) ) {

        my $FAQArticleHistoryGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQArticleHistoryGet',
            Data      => {
                FAQArticleID => $Param{Data}->{FAQArticleID},
                FAQHistoryID => join(',', sort @{$HistoryIDs}),
            }
        );

        if ( !IsHashRefWithData($FAQArticleHistoryGetResult) || !$FAQArticleHistoryGetResult->{Success} ) {
            return $FAQArticleHistoryGetResult;
        }

        my @FAQArticleHistoryDataList = IsArrayRefWithData($FAQArticleHistoryGetResult->{Data}->{FAQHistory}) ? @{$FAQArticleHistoryGetResult->{Data}->{FAQHistory}} : ( $FAQArticleHistoryGetResult->{Data}->{FAQHistory} );

        if ( IsArrayRefWithData(\@FAQArticleHistoryDataList) ) {
            return $Self->_Success(
                FAQHistory => \@FAQArticleHistoryDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQHistory => [],
    );
}


1;