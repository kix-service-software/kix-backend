# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::CommonObjectType;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::CommonObjectType - base object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return if ( !$Param{ObjectType} );

    # remember own object type
    $Self->{ObjectType} = $Param{ObjectType};

    # get registered object types
    my $RegisteredAttributeMapping = $Kernel::OM->Get('Config')->Get('ObjectSearch::Database::' . $Param{ObjectType} . '::Module') || {};

    # prepare attribute backends
    $Self->{AttributeMapping} = {};
    for my $RegisteredKey ( keys( %{ $RegisteredAttributeMapping } ) ) {
        # get module name
        my $AttributeModule = $Kernel::OM->GetModuleFor( $RegisteredAttributeMapping->{ $RegisteredKey }->{Module} )
            || $RegisteredAttributeMapping->{ $RegisteredKey }->{Module};

        # require module
        return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

        # create backend object
        my $AttributeObject = $AttributeModule->new( %{ $Self } );

        # get supported attributes of object
        my $SupportedAttributes = $AttributeObject->GetSupportedAttributes();

        for my $Attribute ( keys( %{ $SupportedAttributes } ) ) {
            $Self->{AttributeMapping}->{ $Attribute } = $SupportedAttributes->{ $Attribute };
            $Self->{AttributeMapping}->{ $Attribute }->{Object} = $AttributeObject;
        }
    }

    return $Self;
}

=item Init()

### TODO ###

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item GetBase()

### TODO ###

=cut

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {};
}

=item GetPermissionDef()

### TODO ###

=cut

sub GetPermissionDef {
    my ( $Self, %Param ) = @_;

    return {};
}

=item GetSearchDef()

### TODO ###

=cut

sub GetSearchDef {
    my ( $Self, %Param ) = @_;

    # init sql def hash
    my %SQLDef = (
        Select  => [],
        From    => [],
        Join    => [],
        Where   => [],
        OrderBy => []
    );

    # generate SQL from attribute modules
    for my $BoolOperator ( qw(AND OR) ) {
        next if ( !defined( $Param{Search}->{ $BoolOperator } ) );

        if ( !IsArrayRefWithData( $Param{Search}->{ $BoolOperator } ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid Search for $BoolOperator!",
                );
            }
            return;
        }

        my @SQLWhereOR = ();

        # process search entries
        for my $SearchEntry ( @{ $Param{Search}->{ $BoolOperator } } ) {
            # get attribute
            my $Attribute = $SearchEntry->{Field};

            # check for supported attribute
            if (
                ref( $Self->{AttributeMapping}->{ $Attribute } ) ne 'HASH'
                || !$Self->{AttributeMapping}->{ $Attribute }->{IsSearchable}
            ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to search for attribute $Attribute!",
                    );
                }
                return;
            }

            # skip attribute if not searchable
            next if ( !$Self->{AttributeMapping}->{ $Attribute }->{IsSearchable} );

            # get object for attribute
            my $AttributeModule = $Self->{AttributeMapping}->{ $Attribute }->{Object};

            # get attribute def
            my $AttributeDef = $AttributeModule->Search(
                Search       => $SearchEntry,
                WholeSearch  => $Param{Search}->{ $BoolOperator },   # forward "whole" search, e.g. if behavior depends on other attributes
                BoolOperator => $BoolOperator,
                Flags        => $Param{Flags},
                UserType     => $Param{UserType},
                UserID       => $Param{UserID},
                Silent       => $Param{Silent}
            );
            return if ( !IsHashRefWithData($AttributeDef) );

            for my $Key ( keys( %{ $AttributeDef } ) ) {
                # special handling for where statement, when boolean is 'OR'
                if (
                    $BoolOperator eq 'OR'
                    && $Key eq 'Where'
                ) {
                    push( @SQLWhereOR, @{ $AttributeDef->{ $Key } } );
                }
                else {
                    push( @{ $SQLDef{ $Key } }, @{ $AttributeDef->{ $Key } } );
                }
            }
        }

        # handle collected statements for 'OR'
        if ( @SQLWhereOR ) {
            # combine
            my $StatementOR = q{(} . join( ' OR ', @SQLWhereOR ) . q{)};

            # add to where statements
            push( @{ $SQLDef{Where} }, $StatementOR );
        }
    }

    return \%SQLDef;
}

=item GetSortDef()

### TODO ###

=cut

sub GetSortDef {
    my ( $Self, %Param ) = @_;

    # init sql def hash
    my %SQLDef = (
        Select  => [],
        From    => [],
        Join    => [],
        Where   => [],
        OrderBy => []
    );

    for my $SortEntry ( @{ $Param{Sort} } ) {
        # get attribute
        my $Attribute = $SortEntry->{Field};

        # check for supported attribute
        if (
            ref( $Self->{AttributeMapping}->{ $Attribute } ) ne 'HASH'
            || !$Self->{AttributeMapping}->{ $Attribute }->{IsSortable}
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to sort by attribute $Attribute!",
                );
            }
            return;
        }

        # get object for attribute
        my $AttributeModule = $Self->{AttributeMapping}->{ $Attribute }->{Object};

        my $Language = $Kernel::OM->Get('User')->GetUserLanguage(
            UserID => $Param{UserID}
        ) || 'en';

        # execute attribute module to prepare SQL
        my $AttributeDef = $AttributeModule->Sort(
            Attribute => $Attribute,
            Language  => $Language,
            Flags     => $Param{Flags}
        );
        return if ( !IsHashRefWithData($AttributeDef) );

        for my $Key ( keys( %{ $AttributeDef  } ) ) {
            # skip OrderBySwitch
            next if ( $Key eq 'OrderBySwitch' );

            # special handling for OrderBy
            if ( $Key eq 'OrderBy' ) {
                my $Order = 'ASC';
                if (
                    $SortEntry->{Direction}
                    && uc( $SortEntry->{Direction} ) eq 'DESCENDING'
                ) {
                    $Order = 'DESC';
                }

                if ( $AttributeDef->{OrderBySwitch} ) {
                    $Order = $Order eq 'ASC' ? 'DESC' : 'ASC';
                }

                for my $Entry ( @{ $AttributeDef->{ $Key } } ) {
                    push( @{ $SQLDef{ $Key } }, $Entry . q{ } . $Order );
                }
            }
            else {
                push( @{ $SQLDef{ $Key } }, @{ $AttributeDef->{ $Key } } );
            }
        }
    }

    return \%SQLDef;
}

=item GetSupportedAttributes()

### TODO ###

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    # init list
    my @List = ();

    # process mapped attributes
    for my $Attribute ( sort( keys( %{ $Self->{AttributeMapping} } ) ) ) {
        my $AttributeRef = $Self->{AttributeMapping}->{ $Attribute };

        push (
            @List,
            {
                ObjectType      => $Self->{ObjectType},
                Property        => $Attribute,
                ObjectSpecifics => undef,
                IsSearchable    => $AttributeRef->{IsSearchable} || 0,
                IsSortable      => $AttributeRef->{IsSortable}   || 0,
                Operators       => $AttributeRef->{Operators}    || []
            }
        );
    }

    return \@List;
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
