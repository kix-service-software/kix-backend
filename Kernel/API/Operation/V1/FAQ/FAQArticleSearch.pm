# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    my %ValidList = $Kernel::OM->Get('Valid')->ValidList();
    my @ValidIDs = %ValidList && keys %ValidList ? keys %ValidList : [ 1, 2, 3 ];
    my $ArticleIDs;

    # prepare search (dynamic fields are possible)
    my %FAQDFSearch;
    if ( IsHashRefWithData( $Self->{Search}->{FAQArticle} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{FAQArticle} } ) {
            my @FilteredList;
            foreach my $SearchItem ( @{ $Self->{Search}->{FAQArticle}->{$SearchType} } ) {

                # removed them from search-param (is used as filter, see below)
                if ($SearchItem->{Field} =~ m/DynamicField_/) {
                    if (!$FAQDFSearch{$SearchType}) {
                        $FAQDFSearch{$SearchType} = [];
                    }
                    push(@{$FAQDFSearch{$SearchType}}, $SearchItem);
                } else {
                    push(@FilteredList, $SearchItem);
                }
            }
            $Self->{Search}->{FAQArticle}->{$SearchType} = \@FilteredList;
        }
    }

    # do search if given (only with dfs and valid)
    if ( IsHashRefWithData( \%FAQDFSearch ) ) {
        foreach my $SearchType ( keys %FAQDFSearch ) {
            my @SearchTypeResult;
            foreach my $SearchItem ( @{ $FAQDFSearch{$SearchType} } ) {

                my $Value = $SearchItem->{Value};
                my $Operator = 'Like';

                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                    $Value = '*' . $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                    $Value = '' . $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                    $Value = '*' . $Value;
                } elsif ( $SearchItem->{Operator} eq 'IN' ) {
                    $Operator = 'Equals';
                } elsif ( $SearchItem->{Operator} eq 'EQ' ) {
                    $Operator = 'Equals';
                    $Value = "$Value";
                } elsif ( $SearchItem->{Operator} eq 'LT' ) {
                    $Operator = 'SmallerThan';
                } elsif ( $SearchItem->{Operator} eq 'LTE' ) {
                    $Operator = 'SmallerThanEquals';
                } elsif ( $SearchItem->{Operator} eq 'GT' ) {
                    $Operator = 'GreaterThan';
                } elsif ( $SearchItem->{Operator} eq 'GTE' ) {
                    $Operator = 'GreaterThanEquals';
                }

                # perform faq search
                my @SearchResult = $Kernel::OM->Get('FAQ')->FAQSearch(
                    UserID   => $Self->{Authorization}->{UserID},
                    Limit    => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
                    ValidIDs => \@ValidIDs,
                    $SearchItem->{Field} => {
                        $Operator => $Value
                    },

                    # use ids of customer if given
                    ArticleIDs => $CustomerFAQIDList
                );

                # merge results
                if ( $SearchType eq 'AND' ) {
                    if ( !@SearchTypeResult ) {
                        @SearchTypeResult = @SearchResult;
                    } else {

                        # remove all IDs from type result that we don't have in this search
                        @SearchTypeResult = $Self->_GetCombinedList(
                            ListA => \@SearchTypeResult,
                            ListB => \@SearchResult
                        );
                    }
                } elsif ( $SearchType eq 'OR' ) {
                    @SearchTypeResult = $Self->_GetCombinedList(
                        ListA => \@SearchTypeResult,
                        ListB => \@SearchResult,
                        Union => 1
                    );
                }
            }

            if ( !defined $ArticleIDs ) {
                $ArticleIDs = \@SearchTypeResult;
            } else {

                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                $ArticleIDs = $Self->_GetCombinedList(
                    ListA => \@SearchTypeResult,
                    ListB => $ArticleIDs
                );
            }
        }
    } else {

        # perform FAQArticle search (at the moment without any filters - we do filtering in the API)
        $ArticleIDs = [ $Kernel::OM->Get('FAQ')->FAQSearch(
            UserID   => $Self->{Authorization}->{UserID},
            Limit   => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
            ValidIDs => \@ValidIDs,

            # use ids of customer if given
            ArticleIDs => $CustomerFAQIDList
        ) ];
    }

    # get already prepared FAQ data from FAQArticleGet operation
    if (IsArrayRefWithData($ArticleIDs) ) {

        # we don't do any core search filtering, inform the API to do it for us, based on the given search
        $Self->HandleSearchInAPI();

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                FAQArticleID                => join( ',', sort @{$ArticleIDs} ),
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

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                FAQArticle => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQArticle => [],
    );
}

sub _GetCombinedList {
    my ( $Self, %Param ) = @_;

    my %Union;
    my %Isect;
    for my $E ( @{ $Param{ListA} }, @{ $Param{ListB} } ) {
        $Union{$E}++ && $Isect{$E}++
    }

    return $Param{Union} ? [ keys %Union ] : [ keys %Isect ];
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
