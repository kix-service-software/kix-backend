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
    my @ArticleIDs;

    # prepare search
    my %FAQSearch;
    if ( IsHashRefWithData( $Self->{Search}->{FAQArticle} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{FAQArticle} } ) {
            my @FilteredList;
            foreach my $SearchItem ( @{ $Self->{Search}->{FAQArticle}->{$SearchType} } ) {

                if (
                    $SearchItem->{Field} =~ m/DynamicField_/ ||
                    ( $SearchItem->{Field} eq 'Language' && $SearchItem->{Operator} eq 'IN' ) ||
                    ( $SearchItem->{Field} eq 'CustomerVisible' && $SearchItem->{Operator} eq 'EQ' ) ||
                    ( $SearchItem->{Field} eq 'ValidID' && $SearchItem->{Operator} eq 'IN' ) ||
                    ( $SearchItem->{Field} eq 'CategoryID' && $SearchItem->{Operator} eq 'IN' ) ||
                    (
                        $SearchItem->{Field} =~ m/(Fulltext|Number|Title|Keywords|Field)/ &&
                        $SearchItem->{Operator} =~ m/(CONTAINS|STARTSWITH|ENDSWITH|LIKE)/
                    )
                ) {
                    if (!$FAQSearch{$SearchType}) {
                        $FAQSearch{$SearchType} = [];
                    }
                    push(@{$FAQSearch{$SearchType}}, $SearchItem);
                }

                # keep "not" searchable properties they are used as filter, see below (HandleSearchInAPI)
                else {
                    push(@FilteredList, $SearchItem);
                }
            }
            $Self->{Search}->{FAQArticle}->{$SearchType} = \@FilteredList;
        }
    }

    # do search if given
    if ( IsHashRefWithData( \%FAQSearch ) ) {
        # do first OR to prevent replacement of prior AND search with empty result
        my %SearchParams;
        SEARCHTYPE:
        foreach my $SearchType ( qw(OR AND) ) {
            next SEARCHTYPE if ( !IsArrayRefWithData($FAQSearch{$SearchType}) );
            my @SearchTypeResult;
            foreach my $SearchItem ( @{ $FAQSearch{$SearchType} } ) {

                my $Value = $SearchItem->{Value};
                my $Operator = 'Like';

                # FIXME: adjust "core names" to api known properties on core search rework
                if ( $SearchItem->{Field} eq 'Fulltext' ) {
                    $SearchItem->{Field} = 'What';
                } elsif ( $SearchItem->{Field} eq 'Keywords' ) {
                    $SearchItem->{Field} = 'Keyword';
                } elsif ( $SearchItem->{Field} eq 'Language' ) {
                    $SearchItem->{Field} = 'Languages';
                } elsif ( $SearchItem->{Field} eq 'CustomerVisible' ) {
                    $SearchItem->{Field} = 'Visibility';
                    $SearchItem->{Operator} = 'IN';
                    $Value = $Value ? ['external', 'public'] : ['internal'];
                } elsif ( $SearchItem->{Field} eq 'ValidID' ) {
                    $SearchItem->{Field} = 'ValidIDs';
                } elsif ( $SearchItem->{Field} eq 'CategoryID' ) {
                    $SearchItem->{Field} = 'CategoryIDs';
                }

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

                $SearchParams{ $SearchItem->{Field} } = $SearchItem->{Field} =~ m/DynamicField_/ ?
                    { $Operator => $Value } :
                    $Value;

                if ( $SearchType eq 'OR' ) {
                    # perform faq search
                    my @SearchResult = $Kernel::OM->Get('FAQ')->FAQSearch(
                        UserID   => $Self->{Authorization}->{UserID},
                        Limit    => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
                        ValidIDs => \@ValidIDs, # add all ids because by default just "valid" is used - can be overwritten in %Search
                        %SearchParams,

                        # use ids of customer if given
                        ArticleIDs => $CustomerFAQIDList
                    );

                    # merge results
                    @SearchTypeResult = $Self->_GetCombinedList(
                        ListA => \@SearchTypeResult,
                        ListB => \@SearchResult,
                        Union => 1
                    );

                    # reset
                    %SearchParams = ();
                }
            }
            if ( $SearchType eq 'AND' ) {

                # perform faq search
                @SearchTypeResult = $Kernel::OM->Get('FAQ')->FAQSearch(
                    UserID   => $Self->{Authorization}->{UserID},
                    Limit    => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
                    ValidIDs => \@ValidIDs, # add all ids because by default just "valid" is used - can be overwritten in %Search
                    %SearchParams,

                    # use ids of customer if given
                    ArticleIDs => $CustomerFAQIDList
                );
            }

            if ( !@ArticleIDs ) {
                @ArticleIDs = @SearchTypeResult;
            } else {

                # combine both results (OR and AND)
                # remove all IDs from type result that we don't have in this search
                @ArticleIDs = $Self->_GetCombinedList(
                    ListA => \@SearchTypeResult,
                    ListB => \@ArticleIDs
                );
            }
        }
    } else {

        # perform FAQArticle search (at the moment without any filters - we do filtering in the API)
        @ArticleIDs = $Kernel::OM->Get('FAQ')->FAQSearch(
            UserID   => $Self->{Authorization}->{UserID},
            Limit    => $Self->{SearchLimit}->{FAQArticle} || $Self->{SearchLimit}->{'__COMMON'},
            ValidIDs => \@ValidIDs, # add all ids because by default just "valid" is used

            # use ids of customer if given
            ArticleIDs => $CustomerFAQIDList
        );
    }

    # get already prepared FAQ data from FAQArticleGet operation
    if (IsArrayRefWithData(\@ArticleIDs) ) {

        # we don't do any core search filtering, inform the API to do it for us, based on the given search
        $Self->HandleSearchInAPI();

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                FAQArticleID                => join( ',', sort @ArticleIDs ),
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

    return $Param{Union} ? keys %Union : keys %Isect;
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
