# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactSearch - API Contact Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ContactSearch Operation. This will return a Contact ID list.

    my $Result = $OperationObject->Run(
        Data => { }
    );

    $Result = {
        Success     => 1,                                # 0 or 1
        Message     => '',                               # In case of an error
        Data        => {
            Contact => [
                { },
                { }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @ContactList;

    $Self->SetDefaultSort(
        Contact => [ 
            { Field => 'Lastname' },
            { Field => 'Firstname' },
        ]
    );

    # prepare search if given
    if ( IsHashRefWithData( $Self->{Search}->{Contact} ) ) {
        # do first OR to prevent replacement of prior AND search with empty result
        my %SearchParams;
        SEARCHTYPE:
        foreach my $SearchType ( qw(OR AND) ) {
            next SEARCHTYPE if ( !IsArrayRefWithData($Self->{Search}->{Contact}->{$SearchType}) );
            my @SearchTypeResult;
            foreach my $SearchItem ( @{ $Self->{Search}->{Contact}->{$SearchType} } ) {

                my $Value = $SearchItem->{Value};

                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                    $Value = '*' . $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                    $Value = $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                    $Value = '*' . $Value;
                } elsif ( $SearchItem->{Operator} eq 'LIKE' ) {
                    $Value .= '*';
                    # just prefix needed as config, because some DB do not use indices with leading wildcard - performance!
                    if( $Kernel::OM->Get('Config')->Get('ContactSearch::UseWildcardPrefix') ) {
                        $Value = '*' . $Value;
                    }
                }

                if ( $SearchItem->{Field} =~ /^(Login|UserLogin)$/ ) {
                    if ( $SearchItem->{Operator} eq 'EQ' ) {
                        $SearchParams{LoginEquals} = $Value;
                    } else {
                        $SearchParams{Login} = $Value;
                    }
                } elsif ( $SearchItem->{Field} =~ /^(AssignedUserID|UserID|OrganisationIDs|Title|Firstname|Lastname|City|Country|Fax|Mobil|Phone|Street|Zip|ValidID)$/ ) {
                    $SearchParams{$SearchItem->{Field}} = $Value;
                } elsif ( $SearchItem->{Field} eq 'Email' ) {
                    if ($SearchItem->{Operator} eq 'EQ') {
                        $SearchParams{EmailEquals} = $Value;
                    } elsif ($SearchItem->{Operator} eq 'IN') {
                        $SearchParams{EmailIn} = $Value;
                    } else {
                        $SearchParams{PostMasterSearch} = $Value;
                    }
                } elsif ( $SearchItem->{Field} eq 'PrimaryOrganisationID' ) {
                    $SearchParams{OrganisationID} = $Value;
                } elsif ($SearchItem->{Field} =~ /^DynamicField_/smx ) {
                    $SearchParams{DynamicField} = {
                        Field    => $SearchItem->{Field},
                        Operator => $SearchItem->{Operator},
                        Value    => $Value
                    };
                } else {
                    $SearchParams{Search} = $Value;
                }

                # merge results
                if ( $SearchType eq 'OR' ) {
                    my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
                        %SearchParams,
                        Valid => 0,
                        Limit => $Self->{SearchLimit}->{Contact} || $Self->{SearchLimit}->{'__COMMON'},
                    );

                    @SearchTypeResult = $Self->_GetCombinedList(
                        ListA => \@SearchTypeResult,
                        ListB => [ keys %SearchResult ],
                        Union => 1
                    );

                    # reset
                    %SearchParams = ();
                }
            }
            if ( $SearchType eq 'AND' ) {
                my %SearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
                    %SearchParams,
                    Valid => 0,
                    Limit => $Self->{SearchLimit}->{Contact} || $Self->{SearchLimit}->{'__COMMON'},
                );
                @SearchTypeResult = %SearchResult ? @{[keys %SearchResult]} : ();
            }

            if ( !@ContactList ) {
                @ContactList = @SearchTypeResult;
            } else {

                # combine both results (OR and AND)
                # remove all IDs from type result that we don't have in this search
                @ContactList = $Self->_GetCombinedList(
                    ListA => \@SearchTypeResult,
                    ListB => \@ContactList
                );
            }
        }
    } else {

        # get full contact list
        my %ContactList = $Kernel::OM->Get('Contact')->ContactList(
            Valid => 0
        );
        @ContactList = %ContactList ? @{[keys %ContactList]} : ();
    }

    if ( IsArrayRefWithData( \@ContactList ) ) {

        # get already prepared Contact data from ContactGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Contact::ContactGet',
            SuppressPermissionErrors => 1,
            Data          => {
                ContactID                   => join( ',', sort @ContactList ),
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues},
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Contact} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Contact}) ? @{$GetResult->{Data}->{Contact}} : ( $GetResult->{Data}->{Contact} );
        }

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                Contact => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
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
