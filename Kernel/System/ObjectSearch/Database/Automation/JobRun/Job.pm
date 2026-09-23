# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Automation::JobRun::Job;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Automation::JobRun::Job - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        JobID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType      => 'NUMERIC'
        },
        Job   => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        JobID => {
            Column       => 'ajr.job_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Job   => {
            Column       => 'ajrj.name',
            ConditionDef => {}
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if ( $Param{Attribute} eq 'Job' ) {
        if ( !$Param{Flags}->{JoinMap}->{JobRunJob} ) {
            push( @SQLJoin, 'INNER JOIN job ajrj ON ajrj.id = ajr.job_id' );

            $Param{Flags}->{JoinMap}->{JobRunJob} = 1;
        }
    }

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if ( $Param{Attribute} eq 'Job' ) {
            $Attribute{Column} = 'LOWER(ajrj.name)';
        }
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
