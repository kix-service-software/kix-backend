# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::OrganisationSearch - API Organisation Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform OrganisationSearch Operation. This will return a Organisation list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Organisation => [
                {
                },
                {
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $OrgList;

    $Self->SetDefaultSort(
        Organisation => [
            { Field => 'Name' },
            { Field => 'Number' },
        ]
    );

    # TODO: filter search - currently not all properties are possible
    my %OrgSearch;
    if ( IsHashRefWithData( $Self->{Search}->{Organisation} ) ) {
        for my $SearchType ( keys %{ $Self->{Search}->{Organisation} } ) {
            for my $SearchItem ( @{ $Self->{Search}->{Organisation}->{$SearchType} } ) {
                next if ($SearchItem->{Operator} eq 'IN' && $SearchItem->{Field} !~ m/^DynamicField_/sxm);
                next if ($SearchItem->{Field} !~ m/^(?:Fulltext|Name|Number|DynamicField_\w+)$/sxm);

                if (!$OrgSearch{$SearchType}) {
                    $OrgSearch{$SearchType} = [];
                }
                push( @{$OrgSearch{$SearchType}}, $SearchItem );
            }
        }
    }

    # prepare search if given
    if ( IsHashRefWithData( \%OrgSearch ) ) {
        for my $SearchType ( keys %OrgSearch ) {
            my %SearchTypeResult;
            for my $SearchItem ( @{ $OrgSearch{$SearchType} } ) {
                my %SearchResult;
                next if( !$SearchItem->{Field} );

                # prepare search params..
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
                    if( $Kernel::OM->Get('Config')->Get('OrganisationSearch::UseWildcardPrefix') ) {
                        $Value = '*' . $Value;
                    }
                }

                my %SearchParam;

                if ($SearchItem->{Field} eq 'Number') {
                    $SearchParam{Number} = $Value;
                } elsif ($SearchItem->{Field} eq 'Name') {
                    $SearchParam{Name} = $Value;
                } elsif ($SearchItem->{Field} =~ /^DynamicField_/smx ) {
                    $SearchParam{DynamicField} = {
                        Field    => $SearchItem->{Field},
                        Operator => $SearchItem->{Operator},
                        Value    => $Value
                    };
                } else {
                    $SearchParam{Search} = $Value;
                }

                # perform search...
                %SearchResult = $Kernel::OM->Get('Organisation')->OrganisationSearch(
                    %SearchParam,
                    Valid => 0,
                    Limit => $Self->{SearchLimit}->{Organisation} || $Self->{SearchLimit}->{'__COMMON'}
                );

                # merge results
                if ( $SearchType eq 'AND' ) {
                    if ( !%SearchTypeResult ) {
                        %SearchTypeResult = %SearchResult;
                    }
                    else {

                        # remove aIDs from collected results, not contained in current...
                        for my $Key ( keys %SearchTypeResult ) {
                            delete $SearchTypeResult{$Key} if !exists $SearchResult{$Key};
                        }
                    }
                }
                elsif ( $SearchType eq 'OR' ) {
                    %SearchTypeResult = (
                        %SearchTypeResult,
                        %SearchResult,
                    );
                }
            }

            if ( !defined $OrgList ) {
                $OrgList = \%SearchTypeResult;
            } else {

                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                for my $Key ( keys %{$OrgList} ) {
                    delete $OrgList->{$Key} if !exists $SearchTypeResult{$Key};
                }
            }
        }
    } else {

        # get full organisation list
        $OrgList = { $Kernel::OM->Get('Organisation')->OrganisationSearch(
            Valid => 0,
            Limit => $Self->{SearchLimit}->{Organisation} || $Self->{SearchLimit}->{'__COMMON'}
        ) };
    }


    if (IsHashRefWithData($OrgList)) {

        # get already prepared Organisation data from OrganisationGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Organisation::OrganisationGet',
            SuppressPermissionErrors => 1,
            Data          => {
                OrganisationID              => join(',', sort keys %{$OrgList}),
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues},
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Organisation} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Organisation}) ? @{$GetResult->{Data}->{Organisation}} : ( $GetResult->{Data}->{Organisation} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Organisation => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Organisation => [],
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
