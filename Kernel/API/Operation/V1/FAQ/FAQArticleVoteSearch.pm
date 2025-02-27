# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleVoteSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleVoteGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleVoteSearch - API FAQArticle Vote Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

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

    # perform FAQVote search (at the moment without any filters - we do filtering in the API)
    my $VoteIDs = $Kernel::OM->Get('FAQ')->VoteSearch(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    # get already prepared FAQ data from FAQArticleVoteGet operation
    if ( IsArrayRefWithData($VoteIDs) ) {

        # we don't do any core search filtering, inform the API to do it for us, based on the given search
        $Self->HandleSearchInAPI();

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleVoteGet',
            SuppressPermissionErrors => 1,
            Data      => {
                FAQArticleID => $Param{Data}->{FAQArticleID},
                FAQVoteID    => join(',', sort @{$VoteIDs}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{FAQVote} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{FAQVote}) ? @{$GetResult->{Data}->{FAQVote}} : ( $GetResult->{Data}->{FAQVote} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                FAQVote => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQVote => [],
    );
}


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
