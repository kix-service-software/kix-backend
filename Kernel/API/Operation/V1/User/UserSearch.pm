# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::UserSearch - API User Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform UserSearch Operation. This will return a User ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            User => [
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
    my $UserList;

    my %SupportedRequiredPermission = (
        TicketRead => {
            Target => '/tickets',
            Permission => 'READ'
        },
        TicketCreate => {
            Target => '/tickets',
            Permission => 'CREATE'
        }
    );

    # extend limit to broaden the result list for permission filter (requiredPermissions)
    my $SearchLimit = $Self->{SearchLimit}->{User} || $Self->{SearchLimit}->{'__COMMON'};
    # remember search limitation for end result
    my $OrgSearchLimit = $SearchLimit;
    if ($Param{Data}->{requiredPermission} && $SearchLimit && $SearchLimit < 100) {
        $SearchLimit = 100;
    }

    my %UserSearch;
    if ( IsHashRefWithData( $Self->{Search}->{User} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{User} } ) {
            foreach my $SearchItem ( @{ $Self->{Search}->{User}->{$SearchType} } ) {
                if ( $SearchItem->{Field} =~ /^(UserLogin|Search|IsAgent|IsCustomer|ValidID|Preferences\..*?)$/ ) {
                    if (!$UserSearch{$SearchType}) {
                        $UserSearch{$SearchType} = [];
                    }
                    push(@{$UserSearch{$SearchType}}, $SearchItem);
                }
            }
        }
    }

    # prepare search if given
    if ( IsHashRefWithData( \%UserSearch ) ) {
        SEARCH_TYPE:
        foreach my $SearchType ( keys %UserSearch ) {
            my %SearchTypeResult;

            # FIXME: combine OR and AND in one search (in core?)
            if ($SearchType eq 'OR') {
                foreach my $SearchItem ( @{ $UserSearch{$SearchType} } ) {
                    my %SearchResult;

                    # special handling for preference search
                    if ( $SearchItem->{Field} =~ /Preferences.(.*?)$/ ) {
                        %SearchResult = $Self->_GetPreferenceSearchResult(
                            SearchItem  => $SearchItem,
                            SearchLimit => $SearchLimit
                        );
                    } else {
                        my %SearchParam = $Self->_GetSearchParam(
                            SearchItem => $SearchItem
                        );

                        if ( !%SearchResult && %SearchParam ) {
                            %SearchResult = $Kernel::OM->Get('User')->UserSearch(
                                %SearchParam,
                                Limit => $SearchLimit,
                                Valid => 0
                            );
                        }
                    }

                    # merge results
                    %SearchTypeResult = (
                        %SearchTypeResult,
                        %SearchResult,
                    );
                }
            } else {
                my %SearchParam;
                foreach my $SearchItem ( @{ $UserSearch{$SearchType} } ) {

                    # special handling for preference search
                    if ( $SearchItem->{Field} =~ /Preferences.(.*?)$/ ) {
                        my %PrefSearchResult = $Self->_GetPreferenceSearchResult(
                            SearchItem => $SearchItem,
                            NoLimit    => 1
                        );

                        # if nothing found, exit search
                        if (!IsHashRefWithData(\%PrefSearchResult)) {
                            $UserList = undef;
                            last SEARCH_TYPE;
                        }

                        my @UserIDs = keys %PrefSearchResult;
                        %SearchParam = (
                            %SearchParam,
                            UserIDs => \@UserIDs
                        );
                    } else {
                        %SearchParam = (
                            %SearchParam,
                            $Self->_GetSearchParam(
                                SearchItem => $SearchItem
                            )
                        );
                    }
                }

                if (%SearchParam) {
                    %SearchTypeResult = $Kernel::OM->Get('User')->UserSearch(
                        %SearchParam,
                        Limit => $SearchLimit,
                        Valid => 0
                    );
                }
            }

            if ( !defined $UserList ) {
                $UserList = \%SearchTypeResult;
            }
            else {
                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                foreach my $Key ( keys %{$UserList} ) {
                    delete $UserList->{$Key} if !exists $SearchTypeResult{$Key};
                }
            }
        }
    }
    else {
        # perform User search without any search params
        $UserList = { $Kernel::OM->Get('User')->UserList(
            Type  => 'Short',
            Limit => $SearchLimit,
            Valid => 0
        ) };
    }

    if (IsHashRefWithData($UserList)) {

        # check requested permissions (AND combined)
        my @GetUserIDs = keys %{$UserList};
        if( $Param{Data} && $Param{Data}->{requiredPermission} ) {
            my @Permissions = split(/, ?/, $Param{Data}->{requiredPermission});

            PERMISSION:
            for my $Permission (@Permissions) {
                next PERMISSION if !$SupportedRequiredPermission{$Permission};

                my @AllowedUserIDs;
                for my $UserID (@GetUserIDs) {

                    my ($Granted) = $Kernel::OM->Get('User')->CheckResourcePermission(
                        UserID              => $UserID,
                        Target              => $SupportedRequiredPermission{$Permission}->{Target},
                        RequestedPermission => $SupportedRequiredPermission{$Permission}->{Permission},
                        UsageContext        => $Self->{Authorization}->{UserType}
                    );

                    if ($Granted) {
                        push(@AllowedUserIDs, $UserID);
                    }
                }

                # set allowed ids for next permission
                @GetUserIDs = @AllowedUserIDs;
            }
        }

        # limit results if necessary (0 = no limit)
        if ($OrgSearchLimit && scalar(@GetUserIDs) > $OrgSearchLimit) {
            splice(@GetUserIDs, $OrgSearchLimit);
        }

        # get already prepared user data from UserGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::User::UserGet',
            SuppressPermissionErrors => 1,
            Data          => {
                UserID => join(',', @GetUserIDs),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{User} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{User}) ? @{$GetResult->{Data}->{User}} : ( $GetResult->{Data}->{User} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                User => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        User => [],
    );
}

sub _GetSearchParam {
    my ( $Self, %Param ) = @_;

    my $Value = $Self->_PrepareSearchValue(%Param);
    my %SearchParam;

    if ( $Param{SearchItem}->{Operator} eq 'EQ' && $Param{SearchItem}->{Field} eq 'UserLogin' ) {
        $SearchParam{UserLoginEquals} = $Value;
    }
    elsif ( $Param{SearchItem}->{Field} eq 'UserLogin' ) {
        $SearchParam{UserLogin} = $Value;
    }
    elsif ( $Param{SearchItem}->{Field} =~ /^(IsAgent|IsCustomer)$/ ) {
        $SearchParam{$Param{SearchItem}->{Field}} = $Value;
    }
    elsif ( $Param{SearchItem}->{Field} eq 'ValidID' ) {
        $SearchParam{ValidID} = $Value;
    } else {
        $SearchParam{Search} = $Value;
    }

    return %SearchParam;
}

sub _GetPreferenceSearchResult {
    my ( $Self, %Param ) = @_;

    my $Value = $Self->_PrepareSearchValue(%Param);
    my %PrefSearchResult;

    my @Values = ( $Value );
    @Values = @{$Param{SearchItem}->{Value}} if $Param{SearchItem}->{Operator} eq 'IN';

    foreach my $Value ( @Values ) {
        $Value =~ s/\*/%/g;

        # we can use the preferences search result directly because we only need the userid key
        my %SearchResultPreferences = $Kernel::OM->Get('User')->SearchPreferences(
            Key   => $1,
            Value => $Value,
            Limit => !$Param{NoLimit} ? $Param{SearchLimit} : undef
        );
        %PrefSearchResult = (
            %PrefSearchResult,
            %SearchResultPreferences
        );
    }

    return %PrefSearchResult;
}

sub _PrepareSearchValue {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{SearchItem}->{Value};

    if ( $Param{SearchItem}->{Operator} eq 'CONTAINS' ) {
        $Value = '*' . $Value . '*';
    } elsif ( $Param{SearchItem}->{Operator} eq 'STARTSWITH' ) {
        $Value = $Value . '*';
    } elsif ( $Param{SearchItem}->{Operator} eq 'ENDSWITH' ) {
        $Value = '*' . $Value;
    }

    return $Value;
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
