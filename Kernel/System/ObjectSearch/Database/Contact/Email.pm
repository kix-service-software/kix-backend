# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Email;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Email - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    my %Supported = (
        Emails => {
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        Email => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    );

    for ( 1..5 ) {
        $Supported{"Email$_"} = {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        };
    }

    return \%Supported;
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    if ( $Param{Search}->{Field} eq 'Emails' ) {
        my @Search;
        push(
            @Search,
            {
                Field    => 'Email',
                Operator => $Param{Search}->{Operator},
                Value    => $Param{Search}->{Value}
            }
        );

        for ( 1..5 ) {
            push(
                @Search,
                {
                    Field    => "Email$_",
                    Operator => $Param{Search}->{Operator},
                    Value    => $Param{Search}->{Value}
                }
            );
        }

        return {
            Search => {
                OR => \@Search
            }
        };
    }

    my $Definition = $Self->AttributePrepare(%Param);

    return if !IsHashRefWithData($Definition);

    my $Condition = $Self->_GetCondition(
        %{$Definition->{ConditionDef}},
        Operator => $Param{Search}->{Operator},
        Value    => $Param{Search}->{Value},
        Silent   => $Param{Silent}
    );

    return {
        %{$Definition->{SQLDef} || {}},
        Where => [ $Condition ]
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    # map search attributes to table attributes
    my %AttributeDefinition = (
        Email  => 'c.email',
        Email1 => 'c.email1',
        Email2 => 'c.email2',
        Email3 => 'c.email3',
        Email4 => 'c.email4',
        Email5 => 'c.email5',
    );

    # c.email is set by GetBaseDef and does not have to be specified again in the select
    return {
        Select  => $Param{Attribute} ne 'Email' ? [ $AttributeDefinition{$Param{Attribute}} ] : [],
        OrderBy => [$AttributeDefinition{$Param{Attribute}}]
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeDefinition = (
        Email  => 'c.email',
        Email1 => 'c.email1',
        Email2 => 'c.email2',
        Email3 => 'c.email3',
        Email4 => 'c.email4',
        Email5 => 'c.email5',
    );

    return {
        ConditionDef => {
            Column          => $AttributeDefinition{ $Param{Search}->{Field} },
            CaseInsensitive => 1,
            NULLValue       => 1
        }
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
