# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::ArticleAttachment;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::ArticleAttachment - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        AttachmentName => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # check for needed joins
    my @SQLJoin = ();
    if ( !$Param{Flags}->{JoinMap}->{Article} ) {
        my $JoinString = 'LEFT OUTER JOIN article ta ON ta.ticket_id = st.id';

        # restrict search from customers to customer visible articles
        if ( $Param{UserType} eq 'Customer' ) {
            $JoinString .= ' AND ta.customer_visible = 1';
        }
        push( @SQLJoin, $JoinString );

        $Param{Flags}->{JoinMap}->{Article} = 1;
    }
    if ( !$Param{Flags}->{JoinMap}->{ArticleAttachment} ) {
        push( @SQLJoin, 'LEFT OUTER JOIN article_attachment att ON att.article_id = ta.id' );

        $Param{Flags}->{JoinMap}->{ArticleAttachment} = 1;
    }

    return {
        Column       => 'att.filename',
        ConditionDef => {
            CaseInsensitive => 1,
            NULLValue       => 1,
        },
        SQLDef => {
            Join => \@SQLJoin
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
