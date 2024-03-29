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

    my %Additional = (
        'CONTAINS' =>  {
            SearchPrefix => q{*},
            SearchSuffix => q{*}
        },
        'STARTSWITH' =>  {
            SearchSuffix => q{*}
        },
        'ENDSWITH' =>  {
            SearchPrefix => q{*}
        },
        'LIKE' => {}
    );

    my $Condition = $Kernel::OM->Get('DB')->QueryCondition(
        %{$Additional{$Param{Search}->{Operator}}},
        Value => $Value,
        Key   => [
            'f.f_number', 'f.f_subject', 'f.f_keywords',
            'f.f_field1','f.f_field2','f.f_field3','f.f_field4','f.f_field5','f.f_field6',
        ]
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
