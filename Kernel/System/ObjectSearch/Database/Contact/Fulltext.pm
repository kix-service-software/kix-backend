# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Fulltext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
    };

    return $Self->{Supported};
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    return if !$Self->_CheckOperators(
        Operator  => $Param{Search}->{Operator},
        Supported => $Self->{Supported}->{Fulltext}->{Operators}
    );

    # prepare value for query condition
    my $Value;
    my @ORGroups = split(/[|]/smx,$Param{Search}->{Value});
    for my $Group ( @ORGroups ) {
        next if !defined $Group;
        next if $Group eq q{};

        if ( $Value ) {
            $Value .= q{||};
        }
        $Value .= q{(}
            . $Group
            . q{)};
    }

    if ( $Value ) {
        $Value = q{(}
            . $Value
            . q{)};
    }

    my $Prefix = q{};
    my $Suffix = q{};

    if ( $Param{Search}->{Operator} eq 'CONTAINS' ) {
        $Prefix = q{*};
        $Suffix = q{*};
    } elsif ( $Param{Search}->{Operator} eq 'STARTSWITH' ) {
        $Suffix = q{*};
    } elsif ( $Param{Search}->{Operator} eq 'ENDSWITH' ) {
        $Prefix = q{*};
    } elsif ( $Param{Search}->{Operator} eq 'LIKE' ) {
        $Suffix = q{*};
        # just prefix needed as config, because some DB do not use indices with leading wildcard - performance!
        if( $Kernel::OM->Get('Config')->Get('ContactSearch::UseWildcardPrefix') ) {
            $Prefix = q{*};
        }
    }

    my @SQLJoin;
    my $Count     = $Param{Flags}->{FulltextJoin} ? $Param{Flags}->{OrganisationJoinCounter}++ : q{};
    my $UserTable = $Param{Flags}->{UserJoin}->{$Param{BoolOperator}} // 'u';
    if ( !$Param{Flags}->{FulltextJoin} ) {
        $Count = $Param{Flags}->{OrganisationJoinCounter}++;

        if ( !$Param{Flags}->{UserJoin}->{$Param{BoolOperator}} ) {
            my $UserCount = $Param{Flags}->{UserCounter}++;
            $UserTable .= $UserCount;
            push(
                @SQLJoin,
                "LEFT JOIN users $UserTable ON c.user_id = $UserTable.id",
            );
            $Param{Flags}->{UserJoin}->{$Param{BoolOperator}} = $UserTable;
        }

        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation cor$Count ON c.id = cor$Count.contact_id",
            "LEFT JOIN organisation o$Count ON o$Count.id = cor$Count.org_id"
        );
        $Param{Flags}->{FulltextJoin} = 1;
    }

    my $Query = $Kernel::OM->Get('DB')->QueryCondition(
        Key => [
            'c.firstname', 'c.lastname',
            'c.email','c.email1','c.email2','c.email3','c.email4','c.email5',
            'c.title','c.phone','c.fax','c.mobile',
            'c.street','c.city','c.zip','c.country',
            "$UserTable.login","o$Count.number","o$Count.name"
        ],
        SearchPrefix => $Prefix,
        SearchSuffix => $Suffix,
        Value        => $Value
    );

    return {
        Where => [$Query],
        Join  => \@SQLJoin
    };
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
