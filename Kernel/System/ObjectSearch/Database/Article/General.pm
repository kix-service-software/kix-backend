# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::General;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::General - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CustomerVisible   => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','LT','GT','LTE','GTE'],
            ValueType      => 'NUMERIC'
        },
        From              => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        To                => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Cc                => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EMPTY','EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Subject           => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        Body              => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init mapping
    my %AttributeDefinition = (
        CustomerVisible   => {
            Column       => 'a.customer_visible',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        From              => {
            Column       => 'a.a_from',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        To                => {
            Column       => 'a.a_to',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        Cc                => {
            Column       => 'a.a_cc',
            ConditionDef => {
                CaseInsensitive => 1,
                NULLValue       => 1
            }
        },
        Subject           => {
            Column       => 'a.a_subject',
            ConditionDef => {
                CaseInsensitive => 1
            }
        },
        Body              => {
            Column       => 'a.a_body',
            ConditionDef => {
                CaseInsensitive => 1
            }
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column}
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
