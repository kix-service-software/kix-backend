# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{RequiredPermission} = {
        TicketRead => {
            Target => '/tickets',
            Permission => 'READ'
        },
        TicketCreate => {
            Target => '/tickets',
            Permission => 'CREATE'
        }
    };

    return $Self;
}

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

    # TODO: filter search - currently only UserLogin and Search are possible search parameter
    my %UserSearch;
    if ( IsHashRefWithData( $Self->{Search}->{User} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{User} } ) {
            foreach my $SearchItem ( @{ $Self->{Search}->{User}->{$SearchType} } ) {
                if ($SearchItem->{Field} eq 'UserLogin' || $SearchItem->{Field} eq 'Search') {
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
        foreach my $SearchType ( keys %UserSearch ) {
            my %SearchTypeResult;
            foreach my $SearchItem ( @{ $UserSearch{$SearchType} } ) {

                my %SearchResult;
                my $Value = $SearchItem->{Value};
                my %SearchParam;

                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                    $Value = '*' . $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                    $Value = $Value . '*';
                } elsif ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                    $Value = '*' . $Value;
                }

                if ( $SearchItem->{Operator} eq 'EQ' && $SearchItem->{Field} eq 'UserLogin' ) {
                    $SearchParam{UserLoginEquals} = $Value;
                }
                elsif ( $SearchItem->{Field} eq 'UserLogin' ) {
                    $SearchParam{UserLogin} = $Value;
                } else {
                    $SearchParam{Search} = $Value;

                    # execute contact search to honor contact attributes
                    my %ContactSearchResult = $Kernel::OM->Get('Contact')->ContactSearch(
                        Search => $Value,
                        Limit => $Self->{Limit}->{User} || $Self->{Limit}->{'__COMMON'},
                        Valid  => 0
                    );

                    my %ContactLoginResult = $Kernel::OM->Get('Contact')->ContactSearch(
                        Login => $Value,
                        Limit => $Self->{Limit}->{User} || $Self->{Limit}->{'__COMMON'},
                        Valid  => 0
                    );

                    my %ContactsResult = (
                        %ContactSearchResult,
                        %ContactLoginResult
                    );

                    # add AssignedUserIds to SearchResult
                    foreach my $Key ( keys %ContactsResult ) {
                        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                            ID      => $Key,
                            Silent  => 1
                        );

                        if ( $Contact{AssignedUserID} ) {
                            %SearchResult = (
                                %SearchResult,
                                $Contact{AssignedUserID} => $Contact{Email}
                            );
                        }
                    }
                }

                if ( !%SearchResult ) {
                    # perform User search
                    %SearchResult = $Kernel::OM->Get('User')->UserSearch(
                        %SearchParam,
                        Limit => $Self->{Limit}->{User} || $Self->{Limit}->{'__COMMON'},
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
            Limit => $Self->{Limit}->{User} || $Self->{Limit}->{'__COMMON'},
            Valid => 0
        ) };
    }

    if (IsHashRefWithData($UserList)) {

        # check requested permissions (AND combined)
        my @GetUserIDs = sort keys %{$UserList};
        if( $Param{Data} && $Param{Data}->{requiredPermission} ) {
            my @Permissions = split(/, ?/, $Param{Data}->{requiredPermission});

            for my $Permission (@Permissions) {
                next if (!$Self->{RequiredPermission} || !$Self->{RequiredPermission}->{$Permission});

                my @AllowedUserIDs;
                for my $UserID (@GetUserIDs) {

                    my ($Granted) = $Kernel::OM->Get('User')->CheckResourcePermission(
                        UserID              => $UserID,
                        Target              => $Self->{RequiredPermission}->{$Permission}->{Target},
                        RequestedPermission => $Self->{RequiredPermission}->{$Permission}->{Permission},
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
