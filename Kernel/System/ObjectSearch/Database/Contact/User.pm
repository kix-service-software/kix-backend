# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::User;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::User - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        UserID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EMPTY','EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        AssignedUserID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EMPTY','EQ','NE','IN','!IN'],
            ValueType      => 'NUMERIC'
        },
        Login => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UserLogin => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    my $TableAlias = $Param{Flags}->{FlagMap}->{UserJoin} // 'u';
    my @SQLJoin;
    if ( $Param{Attribute} =~ m/Login$/sm ){
        if ( !$Param{Flags}->{FlagMap}->{UserJoin} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin} = $TableAlias;
        }
    }

    # init Definition
    my %AttributeDefinition = (
        UserID         => {
            Column       => 'c.user_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        AssignedUserID => {
            Column       => 'c.user_id',
            ConditionDef => {
                ValueType => 'NUMERIC',
                NULLValue => 1
            }
        },
        Login          => {
            Column       => $TableAlias . '.login',
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        UserLogin      => {
            Column       => $TableAlias . '.login',
            ConditionDef => {
                ValueType       => 'STRING',
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        }
    );
    
    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
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
