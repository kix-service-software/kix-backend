# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    my %ContactList;

    # TODO: filter search - currently not all properties are possible
    my %ContactSearch;
    if ( IsHashRefWithData( $Self->{Search}->{Contact} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{Contact} } ) {
            foreach my $SearchItem ( @{ $Self->{Search}->{Contact}->{$SearchType} } ) {
                next if ( 
                    !($SearchItem->{Operator} eq 'EQ' && $SearchItem->{Field} =~ m/^(PrimaryOrganisationID|AssignedUserID|UserID)$/)
                    && $SearchItem->{Field} !~ m/^(Fulltext|Email|Search|Login|OrganisationIDs)$/
                );
                next if ($SearchItem->{Operator} eq 'IN' && $SearchItem->{Field} ne 'OrganisationIDs');

                if (!$ContactSearch{$SearchType}) {
                    $ContactSearch{$SearchType} = [];
                }
                push(@{$ContactSearch{$SearchType}}, $SearchItem);
            }
        }
    }

    # prepare search if given
    if ( IsHashRefWithData( \%ContactSearch ) ) {
        foreach my $SearchType ( keys %ContactSearch ) {
            my %SearchTypeResult;
            foreach my $SearchItem ( @{ $ContactSearch{$SearchType} } ) {

                my %SearchResult;

                # perform Contact search
                if ( $SearchItem->{Field} eq 'Fulltext' ) {
                    %SearchResult = $Self->_DoFulltextSearch( Search => $SearchItem->{Value} );
                } else {
                    my $Value = $SearchItem->{Value};

                    if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                        $Value = '*' . $Value . '*';
                    } elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                        $Value = $Value . '*';
                    } elsif ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                        $Value = '*' . $Value;
                    }

                    my %SearchParam;

                    if ( $SearchItem->{Operator} eq 'EQ' && $SearchItem->{Field} eq 'Login' ) {
                        $SearchParam{LoginEquals} = $Value;
                    } elsif ( $SearchItem->{Field} =~ m/^(Login|AssignedUserID|UserID|OrganisationIDs)$/ ) {
                        $SearchParam{ $SearchItem->{Field} } = $Value;
                    } elsif ($SearchItem->{Operator} eq 'EQ' && $SearchItem->{Field} eq 'Email') {
                        $SearchParam{EmailEquals} = $Value;
                    } elsif ($SearchItem->{Field} eq 'Email') {
                        $SearchParam{PostMasterSearch} = $Value;
                    } elsif ($SearchItem->{Field} eq 'PrimaryOrganisationID') {
                        $SearchParam{OrganisationID} = $Value;
                    } elsif ($SearchItem->{Field} eq 'UserLogin') {
                        $SearchParam{Login} = $Value;
                    } else {
                        $SearchParam{Search} = $Value;
                    }

                    %SearchResult = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
                        %SearchParam,
                        Valid => 0
                    );
                }

                # merge results
                if ( $SearchType eq 'AND' ) {
                    if ( !%SearchTypeResult ) {
                        %SearchTypeResult = %SearchResult;
                    }
                    else {
                        # remove all IDs from type result that we don't have in this search
                        foreach my $Key ( keys %SearchTypeResult ) {
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

            if ( !%ContactList ) {
                %ContactList = %SearchTypeResult;
            }
            else {
                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                foreach my $Key ( keys %ContactList ) {
                    delete $ContactList{$Key} if !exists $SearchTypeResult{$Key};
                }
            }
        }
    }
    else {
        # get contact list
        %ContactList = $Kernel::OM->Get('Kernel::System::Contact')->ContactList(
            Valid => 0
        );
    }

    if ( IsHashRefWithData( \%ContactList ) ) {

        # get already prepared Contact data from ContactGet operation
        my $ContactGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Contact::ContactGet',
            SuppressPermissionErrors => 1,
            Data          => {
                ContactID => join( ',', sort keys %ContactList ),
                }
        );
        if ( !IsHashRefWithData($ContactGetResult) || !$ContactGetResult->{Success} ) {
            return $ContactGetResult;
        }

        my @ResultList = IsArrayRef( $ContactGetResult->{Data}->{Contact} ) ? @{ $ContactGetResult->{Data}->{Contact} } : ( $ContactGetResult->{Data}->{Contact} );

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

sub _DoFulltextSearch {
    my ( $Self, %Param ) = @_;

    my %EndSearchResult;
    if ( $Param{Search} ) {

        # split on OR
        my @OrCombinedGroups = split( /\|/, $Param{Search} );
        for my $OrCombined (@OrCombinedGroups) {

            my %AndResult;

            # split on AND
            my @AndCombinedGroups = split( /\+|\&/, $OrCombined );
            for my $AndSearchString (@AndCombinedGroups) {

                $AndSearchString = '*' . $AndSearchString . '*';
                my %SearchResult = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
                    Search => $AndSearchString,
                    Valid  => 0
                );
                my %LoginResult = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
                    Login => $AndSearchString,
                    Valid  => 0
                );

                # search and login are OR combined
                %SearchResult = (
                    %SearchResult,
                    %LoginResult
                );

                if ( !%AndResult ) {
                    %AndResult = %SearchResult;
                }
                else {

                    # remove all IDs from last result that we don't have in this search
                    foreach my $Key ( keys %AndResult ) {
                        delete $AndResult{$Key} if !exists $SearchResult{$Key};
                    }
                }
            }

            # merge OR results
            %EndSearchResult = (
                %EndSearchResult,
                %AndResult,
            );
        }

    }
    return %EndSearchResult;
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
