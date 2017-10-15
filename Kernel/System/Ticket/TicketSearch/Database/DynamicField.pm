# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::DynamicField;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::DynamicField - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Filter => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Filter => [ 'DynamicField_\w+' ],
        Sort   => []
    };
}


=item Filter()

run this module and return the SQL extensions

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    if ( !$Self->{DynamicFields} ) {

        # get dynamic field object
        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

        # get all configured dynamic fields
        $Self->{DynamicFields} = $DynamicFieldObject->DynamicFieldListGet();
    }

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    #         my $Counter   = 0;
    #         TEXT:
    #         for my $Text (@SearchParams) {
    #             next TEXT if ( !defined $Text || $Text eq '' );

    #             $Text =~ s/\*/%/gi;

    #             # check search attribute, we do not need to search for *
    #             next TEXT if $Text =~ /^\%{1,3}$/;

    #             # validate data type
    #             my $ValidateSuccess = $DynamicFieldBackendObject->ValueValidate(
    #                 DynamicFieldConfig => $DynamicField,
    #                 Value              => $Text,
    #                 UserID             => $Param{UserID} || 1,
    #             );
    #             if ( !$ValidateSuccess ) {
    #                 $Kernel::OM->Get('Kernel::System::Log')->Log(
    #                     Priority => 'error',
    #                     Message =>
    #                         "Search not executed due to invalid value '"
    #                         . $Text
    #                         . "' on field '"
    #                         . $DynamicField->{Name}
    #                         . "'!",
    #                 );
    #                 return;
    #             }

    #             if ($Counter) {
    #                 $SQLExtSub .= ' OR ';
    #             }
    #             $SQLExtSub .= $DynamicFieldBackendObject->SearchSQLGet(
    #                 DynamicFieldConfig => $DynamicField,
    #                 TableAlias         => "dfv$DynamicFieldJoinCounter",
    #                 Operator           => $Operator,
    #                 SearchTerm         => $Text,
    #             );

    #             $Counter++;
    #         }
    #         $SQLExtSub .= ')';
    #         if ($Counter) {
    #             $SQLExt .= $SQLExtSub;
    #             $NeedJoin = 1;
    #         }
    #     }

    #     if ($NeedJoin) {

    #         if ( $DynamicField->{ObjectType} eq 'Ticket' ) {

    #             # Join the table for this dynamic field
    #             $SQLFrom .= "INNER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
    #                 ON (st.id = dfv$DynamicFieldJoinCounter.object_id
    #                     AND dfv$DynamicFieldJoinCounter.field_id = " .
    #                 $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";
    #         }
    #         elsif ( $DynamicField->{ObjectType} eq 'Article' ) {
    #             if ( !$ArticleJoinSQL ) {
    #                 $ArticleJoinSQL = ' INNER JOIN article art ON st.id = art.ticket_id ';
    #                 $SQLFrom .= $ArticleJoinSQL;
    #             }

    #             $SQLFrom .= "INNER JOIN dynamic_field_value dfv$DynamicFieldJoinCounter
    #                 ON (art.id = dfv$DynamicFieldJoinCounter.object_id
    #                     AND dfv$DynamicFieldJoinCounter.field_id = " .
    #                 $DBObject->Quote( $DynamicField->{ID}, 'Integer' ) . ") ";

    #         }

    #         $DynamicFieldJoinTables{ $DynamicField->{Name} } = "dfv$DynamicFieldJoinCounter";

    #         $DynamicFieldJoinCounter++;
    #     }
    # }

    if ( $Param{Filter}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, "st.title='".$Param{Filter}->{Value}."'" );
    }
    elsif ( $Param{Filter}->{Operator} eq 'STARTSWITH' ) {
        push( @SQLWhere, "st.title LIKE '".$Param{Filter}->{Value}."%'" );
    }
    elsif ( $Param{Filter}->{Operator} eq 'ENDSWITH' ) {
        push( @SQLWhere, "st.title LIKE '%".$Param{Filter}->{Value}."'" );
    }
    elsif ( $Param{Filter}->{Operator} eq 'CONTAINS' ) {
        push( @SQLWhere, "st.title LIKE '%".$Param{Filter}->{Value}."%'" );
    }
    elsif ( $Param{Filter}->{Operator} eq 'LIKE' ) {
        my $Value = $Param{Filter}->{Value};
        $Value =~ s/\*/%/g;
        push( @SQLWhere, "st.title LIKE '".$Value."'" );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Filter}->{Operator}!",
        );
        return;
    }

    return {
        SQLWhere => \@SQLWhere,
    };        
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
