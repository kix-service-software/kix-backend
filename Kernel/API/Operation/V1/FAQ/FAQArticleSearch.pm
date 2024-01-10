# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleSearch - API FAQArticle Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
}

=item Run()

perform FAQArticleSearch Operation. This will return a FAQArticle ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQArticle => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get customer relevant ids if necessary
    my $CustomerFAQIDList;
    if ($Self->{Authorization}->{UserType} eq 'Customer') {
        $CustomerFAQIDList = $Self->_GetCustomerUserVisibleObjectIds(
            ObjectType             => 'FAQArticle',
            UserID                 => $Self->{Authorization}->{UserID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );

        # return empty result if there are no assigned faqs for customer
        return $Self->_Success(
            FAQArticle => [],
        ) if (!IsArrayRefWithData($CustomerFAQIDList));
    }

    my $Search = $Self->{Search}->{FAQArticle} // {};
    if ( IsArrayRef($CustomerFAQIDList) ) {
        push(
            @{$Search->{AND}},
            {
                Field    => 'ID',
                Operator => 'IN',
                Value    => $CustomerFAQIDList
            }
        );
    }

    my @ArticleIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
        ObjectType => 'FAQArticle',
        Result     => 'ARRAY',
        Search     => $Search,
        Limit      => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{FAQArticle},
        Debug      => $Param{Data}->{debug} // 0
    );

    # get already prepared FAQ data from FAQArticleGet operation
    if (
        @ArticleIDs
        && scalar(@ArticleIDs)
     ) {

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                FAQArticleID                => join( q{,}, @ArticleIDs ),
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues},
                RelevantOrganisationID      => $Param{Data}->{RelevantOrganisationID}
            }
        );

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{FAQArticle} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{FAQArticle}) ? @{$GetResult->{Data}->{FAQArticle}} : ( $GetResult->{Data}->{FAQArticle} );
        }

        if (
            @ResultList
            && scalar( @ResultList )
        ) {
            return $Self->_Success(
                FAQArticle => \@ResultList
            );
        }
    }

    # return result
    return $Self->_Success(
        FAQArticle => [],
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
