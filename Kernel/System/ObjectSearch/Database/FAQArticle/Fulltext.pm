# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Fulltext;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Fulltext - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

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

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # fixed search in the  following columns:
    # Number, Subject, Keyword and Field1-6
    my $Condition = $Self->_FulltextCondition(
        Operator     => $Param{Search}->{Operator},
        Value        => $Param{Search}->{Value},
        Columns      => [
            'f.f_number', 'f.f_subject', 'f.f_keywords',
            'f.f_field1','f.f_field2','f.f_field3','f.f_field4','f.f_field5','f.f_field6',
        ],
        Silent        => $Param{Silent}
    );

    return if ( !$Condition );

    return {
        Where => [$Condition]
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
