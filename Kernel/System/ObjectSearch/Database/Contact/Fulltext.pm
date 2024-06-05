# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
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

    return {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
    };
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

    my @SQLJoin;
    my $UserTable        = $Param{Flags}->{JoinMap}->{UserJoin} // 'u';
    my $OrgaTable        = $Param{Flags}->{JoinMap}->{OrganisationJoin} // 'o';
    my $OrgaContactTable = $Param{Flags}->{JoinMap}->{OrganisationContactJoin} // 'co';
    if ( !$Param{Flags}->{JoinMap}->{UserJoin} ) {
        my $Count = $Param{Flags}->{UserJoinCounter}++;
        $UserTable .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN users $UserTable ON c.user_id = $UserTable.id",
        );
        $Param{Flags}->{JoinMap}->{UserJoin} = $UserTable;
    }

    if ( !$Param{Flags}->{JoinMap}->{OrganisationContactJoin} ) {
        my $Count = $Param{Flags}->{OrganisationContactJoinCounter}++;
        $OrgaContactTable .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN contact_organisation $OrgaContactTable ON c.id = $OrgaContactTable.contact_id"
        );

        $Param{Flags}->{JoinMap}->{OrganisationContactJoin} = $OrgaContactTable;
    }

    if ( !$Param{Flags}->{JoinMap}->{OrganisationJoin} ) {
        my $Count = $Param{Flags}->{OrganisationJoinCounter}++;
        $OrgaTable .= $Count;

        push(
            @SQLJoin,
            "LEFT JOIN organisation $OrgaTable ON $OrgaTable.id = $OrgaContactTable.org_id"
        );
        $Param{Flags}->{JoinMap}->{OrganisationJoin} = $OrgaTable;
    }

    # fixed search in the  following columns:
    # Firstname, Lastname, E-Mail, E-Mail1-5 Title, Phone, Fax, Mobile,
    # Street, City, Zip and Country
    # inlcudes related columns of other tables:
    # table users: Login
    # table organisation: Number and Name
    my $Condition = $Self->_FulltextCondition(
        Columns       => [
            'c.firstname', 'c.lastname',
            'c.email','c.email1','c.email2','c.email3','c.email4','c.email5',
            'c.title','c.phone','c.fax','c.mobile',
            'c.street','c.city','c.zip','c.country',
            "$UserTable.login","$OrgaTable.number","$OrgaTable.name"
        ],
        Operator      => $Param{Search}->{Operator},
        Value         => $Param{Search}->{Value}
    );

    return {
        Where => [$Condition],
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
