# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::OwnerResponsible - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        OwnerID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Owner => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OwnerName => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        OwnerOutOfOffice => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ'],
            ValueType      => 'NUMERIC'
        },
        ResponsibleID => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','GT','GTE','LT','LTE'],
            ValueType      => 'NUMERIC'
        },
        Responsible => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 1,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleName => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        },
        ResponsibleOutOfOffice => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['EQ'],
            ValueType      => 'NUMERIC'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeDefinition = (
        OwnerID       => {
            Column       => 'st.user_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Owner         => {
            Column       => 'tou.login',
            SortColumn   => ['LOWER(touc.lastname)','LOWER(touc.firstname)','LOWER(tou.login)'],
            ConditionDef => {}
        },
        OwnerName     => {
            Column       => ['touc.lastname','touc.firstname'],
            SortColumn   => ['LOWER(touc.lastname)','LOWER(touc.firstname)'],
            ConditionDef => {
                CaseInsensitive => 1
            }
        },
        ResponsibleID => {
            Column       => 'st.responsible_user_id',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        Responsible   => {
            Column       => 'tru.login',
            SortColumn   => ['LOWER(truc.lastname)','LOWER(truc.firstname)','LOWER(tru.login)'],
            ConditionDef => {}
        },
        ResponsibleName => {
            Column       => ['truc.lastname','truc.firstname'],
            SortColumn   => ['LOWER(truc.lastname)','LOWER(truc.firstname)'],
            ConditionDef => {
                CaseInsensitive => 1
            }
        }
    );

    # check for needed joins
    my @SQLJoin = ();
    if (
        $Param{Attribute} eq 'Owner'
        || $Param{Attribute} eq 'OwnerName'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketOwner} ) {
            push( @SQLJoin, 'INNER JOIN users tou ON tou.id = st.user_id' );

            $Param{Flags}->{JoinMap}->{TicketOwner} = 1;
        }
        if (
            !$Param{Flags}->{JoinMap}->{TicketOwnerContact}
            && (
                $Param{Attribute} eq 'OwnerName'
                || $Param{PrepareType} eq 'Sort'
            )
        ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact touc ON touc.user_id = tou.id' );

            $Param{Flags}->{JoinMap}->{TicketOwnerContact} = 1;
        }
    }
    if (
        $Param{Attribute} eq 'Responsible'
        || $Param{Attribute} eq 'ResponsibleName'
    ) {
        if ( !$Param{Flags}->{JoinMap}->{TicketResponsible} ) {
            push( @SQLJoin, 'INNER JOIN users tru ON tru.id = st.responsible_user_id' );

            $Param{Flags}->{JoinMap}->{TicketResponsible} = 1;
        }
        if (
            !$Param{Flags}->{JoinMap}->{TicketResponsibleContact}
            && (
                $Param{Attribute} eq 'ResponsibleName'
                || $Param{PrepareType} eq 'Sort'
            )
        ) {
            push( @SQLJoin, 'LEFT OUTER JOIN contact truc ON truc.user_id = tru.id' );

            $Param{Flags}->{JoinMap}->{TicketResponsibleContact} = 1;
        }
    }

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{ $Param{PrepareType} . 'Column' }
            || $AttributeDefinition{ $Param{Attribute} }->{Column},
        SQLDef => {
            Join => \@SQLJoin,
        }
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }

    return \%Attribute;
}

sub Search {
    my ( $Self, %Param ) = @_;

    if (
        ref( $Param{Search} ) eq 'HASH'
        && $Param{Search}->{Field}
        && (
            $Param{Search}->{Field} eq 'OwnerOutOfOffice'
            || $Param{Search}->{Field} eq 'ResponsibleOutOfOffice'
        )
    ) {
        # check params
        return if ( !$Self->_CheckSearchParams( %Param ) );

        # check for needed joins
        my @SQLJoin = ();
        my %AttributeMapping;
        if ( $Param{Search}->{Field} eq 'OwnerOutOfOffice' ) {
            # get user preferences config
            my $GeneratorModule = $Kernel::OM->Get('Config')->Get('User::PreferencesModule')
                || 'Kernel::System::User::Preferences::DB';

            # get generator preferences module
            my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

            %AttributeMapping = (
                AliasStart => 'toupooos',
                AliasEnd   => 'toupoooe',
                ColumnName => $PreferencesObject->{PreferencesTableValue}
            );

            if ( !$Param{Flags}->{JoinMap}->{TicketOwnerOutOfOffice} ) {
                push( @SQLJoin, "LEFT OUTER JOIN $PreferencesObject->{PreferencesTable} $AttributeMapping{AliasStart} ON $AttributeMapping{AliasStart}.$PreferencesObject->{PreferencesTableUserID} = st.user_id AND $AttributeMapping{AliasStart}.$PreferencesObject->{PreferencesTableKey} = 'OutOfOfficeStart'" );
                push( @SQLJoin, "LEFT OUTER JOIN $PreferencesObject->{PreferencesTable} $AttributeMapping{AliasEnd} ON $AttributeMapping{AliasEnd}.$PreferencesObject->{PreferencesTableUserID} = st.user_id AND $AttributeMapping{AliasEnd}.$PreferencesObject->{PreferencesTableKey} = 'OutOfOfficeEnd'" );

                $Param{Flags}->{JoinMap}->{TicketOwnerOutOfOffice} = 1;
            }
        }
        elsif ( $Param{Search}->{Field} eq 'ResponsibleOutOfOffice' ) {
            # get user preferences config
            my $GeneratorModule = $Kernel::OM->Get('Config')->Get('User::PreferencesModule')
                || 'Kernel::System::User::Preferences::DB';

            # get generator preferences module
            my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

            %AttributeMapping = (
                AliasStart => 'trupooos',
                AliasEnd   => 'trupoooe',
                ColumnName => $PreferencesObject->{PreferencesTableValue}
            );

            if ( !$Param{Flags}->{JoinMap}->{TicketResponsibleOutOfOffice} ) {
                push( @SQLJoin, "LEFT OUTER JOIN $PreferencesObject->{PreferencesTable} $AttributeMapping{AliasStart} ON $AttributeMapping{AliasStart}.$PreferencesObject->{PreferencesTableUserID} = st.user_id AND $AttributeMapping{AliasStart}.$PreferencesObject->{PreferencesTableKey} = 'OutOfOfficeStart'" );
                push( @SQLJoin, "LEFT OUTER JOIN $PreferencesObject->{PreferencesTable} $AttributeMapping{AliasEnd} ON $AttributeMapping{AliasEnd}.$PreferencesObject->{PreferencesTableUserID} = st.user_id AND $AttributeMapping{AliasEnd}.$PreferencesObject->{PreferencesTableKey} = 'OutOfOfficeEnd'" );

                $Param{Flags}->{JoinMap}->{TicketResponsibleOutOfOffice} = $PreferencesObject->{PreferencesTableUserID};
            }
        }

        # prepare condition
        my $Condition;
        my $IsRelative;

        # prepare column for start and end date
        my $StartColumn = $AttributeMapping{AliasStart} . '.' . $AttributeMapping{ColumnName};
        my $EndColumn   = $AttributeMapping{AliasEnd} . '.' . $AttributeMapping{ColumnName};

        # get current date
        my $CurrDate = $Kernel::OM->Get('Time')->CurrentTimestamp();
        $CurrDate =~ s/^(\d{4}-\d{2}-\d{2}).+$/$1/;

        my $Values = [];
        if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
            push( @{ $Values },  $Param{Search}->{Value}  );
        }
        else {
            $Values =  $Param{Search}->{Value} ;
        }

        my @Conditions;
        for my $Value ( @{ $Values } ) {
            # prepare condition for true value
            if ( $Value ) {
                my $StartCondition = $Self->_GetCondition(
                    Operator => 'LTE',
                    Column   => $StartColumn,
                    Value    => $CurrDate,
                    Silent   => $Param{Silent}
                );
                return if ( !$StartCondition );

                my $EndCondition = $Self->_GetCondition(
                    Operator => 'GTE',
                    Column   => $EndColumn,
                    Value    => $CurrDate,
                    Silent   => $Param{Silent}
                );
                return if ( !$EndCondition );

                my $InternalCondition = '(' . $StartCondition . ' AND ' . $EndCondition . ')';

                # add special condition
                push( @Conditions, $InternalCondition );
            }
            # prepare condition for false value
            else {
                my $StartCondition = $Self->_GetCondition(
                    Operator => 'GT',
                    Column   => $StartColumn,
                    Value    => $CurrDate,
                    Silent   => $Param{Silent}
                );
                return if ( !$StartCondition );

                my $EndCondition = $Self->_GetCondition(
                    Operator => 'LT',
                    Column   => $EndColumn,
                    Value    => $CurrDate,
                    Silent   => $Param{Silent}
                );
                return if ( !$EndCondition );

                my $InternalCondition = '(' . $StartCondition . ' OR ' . $EndCondition . ' OR ' . $StartColumn . ' IS NULL OR ' . $EndColumn . ' IS NULL)';

                # add special condition
                push( @Conditions, $InternalCondition );
            }
        }

        if ( scalar( @Conditions ) > 1 ) {
            $Condition = '(' . join( ' OR ', @Conditions ) . ')';
        }
        else {
            $Condition = $Conditions[0];
        }

        # this kind of search is always relative
        $IsRelative = 1;

        return if ( !$Condition );

        # return search def
        return {
            Join       => \@SQLJoin,
            Where      => [ $Condition ],
            IsRelative => $IsRelative
        };
    }
    else {
        return $Self->SUPER::Search(%Param);
    }
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
