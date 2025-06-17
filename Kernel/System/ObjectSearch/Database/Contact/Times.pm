# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::Times;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Contact::Times - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        CreateTime => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        ChangeTime => {
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        }
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if !$Self->_CheckSortParams(%Param);

    # map search attributes to table attributes
    my %AttributeDefinition = (
        CreateTime => 'c.create_time',
        ChangeTime => 'c.change_time',
    );

    return {
        Select  => [$AttributeDefinition{$Param{Attribute}}],
        OrderBy => [$AttributeDefinition{$Param{Attribute}}],
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %Attributes = (
        CreateTime => 'c.create_time',
        ChangeTime => 'c.change_time',
    );

    return {
        ConditionDef => {
            Column    => $Attributes{$Param{Search}->{Field}},
            ValueType => 'DATETIME'
        },
        SQLDef => {
            IsRelative => $Param{Search}->{IsRelative}
        }
    };
}

sub ValuePrepare {
    my ($Self, %Param) = @_;

    return if !$Param{Search}->{Value};

    # calculate relative times
    my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Search}->{Value}
    );

    if ( !$SystemTime ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid date format found in parameter $Param{Search}->{Field}!",
        );
        return;
    }

    my $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $SystemTime
    );

    return $Kernel::OM->Get('DB')->Quote( $Value );
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
