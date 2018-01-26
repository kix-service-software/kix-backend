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

package Kernel::API::Operation::V1::FAQ::FAQArticleVoteSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleVoteGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleVoteSearch - API FAQArticle Vote Search Operation backend

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

perform FAQArticleVoteSearch Operation. This will return a FAQArticleVote ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQVote => [
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
        Parameters => {
            'FAQArticleID' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform FAQVote search (at the moment without any filters - we do filtering in the API)
    my $VoteIDs = $Kernel::OM->Get('Kernel::System::FAQ')->VoteSearch(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQArticleVoteGet operation
    if ( IsArrayRefWithData($VoteIDs) ) {

        my $FAQArticleVoteGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQArticleVoteGet',
            Data      => {
                FAQArticleID => $Param{Data}->{FAQArticleID},
                FAQVoteID    => join(',', sort @{$VoteIDs}),
            }
        );

        if ( !IsHashRefWithData($FAQArticleVoteGetResult) || !$FAQArticleVoteGetResult->{Success} ) {
            return $FAQArticleVoteGetResult;
        }

        my @FAQArticleVoteDataList = IsArrayRefWithData($FAQArticleVoteGetResult->{Data}->{FAQVote}) ? @{$FAQArticleVoteGetResult->{Data}->{FAQVote}} : ( $FAQArticleVoteGetResult->{Data}->{FAQVote} );

        if ( IsArrayRefWithData(\@FAQArticleVoteDataList) ) {
            return $Self->_Success(
                FAQVote => \@FAQArticleVoteDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQVote => [],
    );
}


1;