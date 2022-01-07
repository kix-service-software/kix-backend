# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemSearch - API CMDB Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ConfigItemSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get customer relevant ids if necessary
    my $CustomerCIIDList;
    if ($Self->{Authorization}->{UserType} eq 'Customer') {
        $CustomerCIIDList = $Self->_GetCustomerUserVisibleObjectIds(
            ObjectType => 'ConfigItem',
            UserID     => $Self->{Authorization}->{UserID}
        );

        # return empty result if there are no assigned config items for customer
        return $Self->_Success(
            ConfigItem => [],
        ) if (!IsArrayRefWithData($CustomerCIIDList));
    }

    my $ConfigItemList;

    # prepare search if given
    my %SearchParam;
    if ( IsHashRefWithData($Self->{Search}->{ConfigItem}) ) {

        # do first OR to prevent replacement of prior AND search with empty result
        foreach my $SearchType ( qw(OR AND) ) {
            next if ( !IsArrayRefWithData($Self->{Search}->{ConfigItem}->{$SearchType}) );

            my @SearchTypeResult;
            foreach my $SearchItem ( @{$Self->{Search}->{ConfigItem}->{$SearchType}} ) {
                my $Value = $SearchItem->{Value};
                my $Field = $SearchItem->{Field};

                # prepare field in case of sub-structure search
                if ( $Field =~ /\./ ) {
                    $Field = ( split(/\./, $Field) )[-1];
                }

                # prepare value
                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                   $Value = '*' . $Value . '*';
                }
                elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                   $Value = $Value . '*';
                }
                if ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                   $Value = '*' . $Value;
                }

                # do some special handling if field is an XML attribute
                if ( $SearchItem->{Field} =~ /Data\./ ) {
                    my %OperatorMapping = (
                        'EQ'  => '=',
                        'LT'  => '<',
                        'LTE' => '<=',
                        'GT'  => '>',
                        'GTE' => '>=',
                    );

                    # build search key of given field
                    my $SearchKey = "[1]{'Version'}[1]";
                    my @Parts = split(/\./, $SearchItem->{Field});
                    foreach my $Part ( @Parts[2..$#Parts] ) {
                        $SearchKey .= "{'" . $Part . "\'}[%]";
                    }

                    $Value =~ s/\*/%/g;

                    my @What = IsArrayRefWithData($SearchParam{What}) ? @{$SearchParam{What}} : ();
                    if ( $OperatorMapping{$SearchItem->{Operator}} ) {
                        push(@What, { $SearchKey."{'Content'}" => { $OperatorMapping{$SearchItem->{Operator}}, $Value } });
                    }
                    else {
                        push(@What, { $SearchKey."{'Content'}" => $Value });
                    }
                    $SearchParam{What} = \@What;
                }
                else {
                    $SearchParam{$Field} = $Value;
                }

                if ( $SearchType eq 'OR' ) {
                    my $SearchResult;

                    # special search attribute AssignedContact handling
                    if ($Field eq 'AssignedContact') {
                        # result are only for NOT customer context else it is always empty
                        # --> do not include ids for other contacts
                        if ($Self->{Authorization}->{UserType} ne 'Customer') {
                            $SearchResult = $Self->_GetContactAssignedConfigItems(
                                ContactID => $SearchParam{AssignedContact}
                            );
                        }
                    } else {

                        # only consider limit if no AND is given
                        my $Limit;
                        if ( !IsArrayRefWithData($Self->{Search}->{ConfigItem}->{AND}) ) {
                            $Limit = $Self->{SearchLimit}->{ConfigItem} || $Self->{SearchLimit}->{'__COMMON'};
                        }

                        # perform search for every attribute
                        $SearchResult = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemSearchExtended(
                            %SearchParam,
                            UserID  => $Self->{Authorization}->{UserID},
                            Limit   => $Limit,

                            # use ids of customer if given
                            ConfigItemIDs => $CustomerCIIDList
                        );
                    }

                    # merge results
                    my @MergeResult = keys %{{map {($_ => 1)} (@SearchTypeResult, @{$SearchResult})}};
                    @SearchTypeResult = @MergeResult;

                    # clear SearchParam
                    %SearchParam = ();
                }
            }

            if ( $SearchType eq 'AND' ) {

                # special search attribute AssignedContact handling
                my $SkipAndSearch = 0;
                if (exists $SearchParam{AssignedContact} && $Self->{Authorization}->{UserType} ne 'Customer') {
                    $CustomerCIIDList = $Self->_GetContactAssignedConfigItems(
                        ContactID => $SearchParam{AssignedContact}
                    );

                    # skip and search if no id are found (AND can not be fulfilled)
                    if (!IsArrayRefWithData($CustomerCIIDList)) {
                        $SkipAndSearch = 1;
                    }
                }

                if (!$SkipAndSearch) {

                    # perform ConfigItem search
                    my $SearchResult = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemSearchExtended(
                        %SearchParam,
                        UserID  => $Self->{Authorization}->{UserID},
                        Limit   => $Self->{SearchLimit}->{ConfigItem} || $Self->{SearchLimit}->{'__COMMON'},

                        # use ids of customer and result from OR search if given
                        # check for undef "refs" to prevent implicit undef to array-ref conversion (see below "!defiend")
                        ConfigItemIDs => \(
                            @{ $ConfigItemList || [] },
                            @{ $CustomerCIIDList || [] }
                        )
                    );
                    @SearchTypeResult = @{$SearchResult};
                }
            }

            # if no search already done, use first result (also empty list for AND combination!)
            if ( !defined $ConfigItemList ) {
                $ConfigItemList = \@SearchTypeResult;
            } else {

                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                my %SearchTypeResultHash = map { $_ => 1 } @SearchTypeResult;
                my @Result;
                foreach my $ConfigItemID ( @{$ConfigItemList} ) {
                    push(@Result, $ConfigItemID) if $SearchTypeResultHash{$ConfigItemID};
                }
                $ConfigItemList = \@Result;
            }
        }
    }
    else {
        # perform ConfigItem search
        my $SearchResult = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemSearchExtended(
            UserID  => $Self->{Authorization}->{UserID},
            Limit   => $Self->{SearchLimit}->{ConfigItem} || $Self->{SearchLimit}->{'__COMMON'},

            # use ids of customer if given
            ConfigItemIDs => $CustomerCIIDList
        );
        $ConfigItemList = $SearchResult;
    }

    # get already prepared CI data from ConfigItemGet operation
    if ( IsArrayRefWithData($ConfigItemList) ) {

        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemGet',
            Data      => {
                ConfigItemID => join(',', sort @{$ConfigItemList}),
            }
        );

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConfigItem} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConfigItem}) ? @{$GetResult->{Data}->{ConfigItem}} : ( $GetResult->{Data}->{ConfigItem} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConfigItem => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItem => [],
    );
}

sub _GetContactAssignedConfigItems {
    my ( $Self, %Param ) = @_;

    my $IDList;
    if ($Param{ContactID}) {

        # get contact and user data
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID            => $Param{ContactID},
            DynamicFields => 1
        );
        if (!$ContactData{User} && $ContactData{AssignedUserID}) {
            my %User = $Kernel::OM->Get('User')->GetUserData(
                UserID => $ContactData{AssignedUserID},
            );
            $ContactData{User} = IsHashRefWithData(\%User) ? \%User : undef;
        }

        # get object relevant ids
        if ( IsHashRefWithData(\%ContactData) ) {
            $IDList = $Kernel::OM->Get('ITSMConfigItem')->GetAssignedConfigItemsForObject(
                ObjectType => 'Contact',
                Object     => \%ContactData,
                UserID     => $Self->{Authorization}->{UserID}
            );
        }
    }

    return $IDList;
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
