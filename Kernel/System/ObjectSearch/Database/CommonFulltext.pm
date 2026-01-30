# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::CommonFulltext;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::CommonFulltext - base fulltext module for object search

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

    return $Self;
}

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        'Property' => {
            IsSearchable   => 0|1,
            IsSortable     => 0|1,
            IsFulltextable => 0|1,
            Operators      => [...],
            ValueType      => 'NUMERIC|TEXTUAL|DATE|DATETIME'
        }
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Fulltext => {
            IsSelectable   => 0,
            IsSearchable   => 1,
            IsSortable     => 0,
            IsFulltextable => 0,
            Operators      => ['LIKE']
        }
    };
}

=item FulltextSearch()

provides required sql search definition

    my $Result = $Object->FulltextSearch(
        Search => {                   # required
            Field    => '...',        # required
            Operator => '...',        # required
            Value    => '...'         # required
        },
        Columns      => [],           # required
        UserID       => '...',        # required
        UserType     => '...',
        Join         => [],
        Silent       => 0|1,
    );

    $Result = {
        Join    => [],
        Where   => []
    };

=cut

sub FulltextSearch {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my $Condition = $Self->_FulltextCondition(
        Columns       => $Param{Columns},
        StaticColumns => $Param{StaticColumns},
        Value         => $Param{Search}->{Value},
        Silent        => $Param{Silent}
    );

    return if !$Condition;

    return {
        Join  => $Param{Join},
        Where => [$Condition]
    };
}

sub _CheckSearchParams {
    my ($Self, %Param) = @_;

    # check required columns parameter
    if (
        !defined( $Param{Columns} )
        || ref( $Param{Columns} ) ne 'ARRAY'
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid Columns!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check static columns parameter
    if (
        defined( $Param{StaticColumns} )
        && ref( $Param{StaticColumns} ) ne 'ARRAY'
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid StaticColumns!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check required search parameter
    if (
        ref( $Param{Search} ) ne 'HASH'
        || !defined( $Param{Search}->{Field} )
        || !defined( $Param{Search}->{Operator} )
        || !defined( $Param{Search}->{Value} )
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid Search!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check required parameter
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid UserID!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # get supported attributes of backend
    my $AttributeList = $Self->GetSupportedAttributes();

    # check for supported attribute
    if (
        !defined( $AttributeList->{ $Param{Search}->{Field} } )
        || !$AttributeList->{ $Param{Search}->{Field} }->{IsSearchable}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid search field "' . $Param{Search}->{Field} . '"!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check supported operator
    my %Operators = map { $_ => 1 } @{ $AttributeList->{ $Param{Search}->{Field} }->{Operators} };
    if ( !$Operators{ $Param{Search}->{Operator} } ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid operator "' . $Param{Search}->{Operator}
                        . '" for search field "' . $Param{Search}->{Field} . '"!',
            Silent   => $Param{Silent}
        );
        return;
    }

    # check value type
    my $IsRelative;
    if ( IsArrayRef( $Param{Search}->{Value} ) ) {
        for my $Value ( @{ $Param{Search}->{Value} } ) {
            ( $Value, $IsRelative ) = $Self->_ValidateValueType(
                Field         => $Param{Search}->{Field},
                Value         => $Value,
                AttributeList => $AttributeList,
                Silent        => $Param{Silent}
            );
            return if ( !defined( $Value ) );

            if ( $IsRelative ) {
                $Param{Search}->{IsRelative} = 1;
            }
        }
    }
    else {
        ( $Param{Search}->{Value}, $IsRelative ) = $Self->_ValidateValueType(
            Field         => $Param{Search}->{Field},
            Value         => $Param{Search}->{Value},
            AttributeList => $AttributeList,
            Silent        => $Param{Silent}
        );
        return if ( !defined( $Param{Search}->{Value} ) );

        if ( $IsRelative ) {
            $Param{Search}->{IsRelative} = 1;
        }
    }

    # check for required attributes
    if ( defined( $AttributeList->{ $Param{Search}->{Field} }->{Requires} ) ) {
        $Param{Search}->{Requires} = $AttributeList->{ $Param{Search}->{Field} }->{Requires};
    }

    return 1;
}

sub _ValidateValueType {
    my ($Self, %Param) = @_;

    my $IsRelative = 0;

    if ( !defined( $Param{Value} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Undefined value for search field "' . $Param{Field} . '"!',
            Silent   => $Param{Silent}
        );
        return;
    }
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'NUMERIC'
        && $Param{Value} !~ m/^-?\d+$/
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid value "' . $Param{Value}
                        . '" for valuetype "' . $Param{AttributeList}->{ $Param{Field} }->{ValueType}
                        . '" for search field "' . $Param{Field} . '"!',
            Silent   => $Param{Silent}
        );
        return;
    }
    # special handling for date without time. append begin of day
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATE'
        && $Param{Value} =~ m/^\d{4}-\d{2}-\d{2}$/
    ) {
        $Param{Value} = $Param{Value} . ' 00:00:00';
    }
    elsif (
        $Param{AttributeList}->{ $Param{Field} }->{ValueType}
        && (
            $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATE'
            || $Param{AttributeList}->{ $Param{Field} }->{ValueType} eq 'DATETIME'
        )
    ) {
        # remember initial value
        my $InitialValue = $Param{Value};

        # convert to unix time and check
        my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{Value},
            Silent => 1,
        );
        if ( !$SystemTime ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid value "' . $Param{Value}
                            . '" for valuetype "' . $Param{AttributeList}->{ $Param{Field} }->{ValueType}
                            . '" for search field "' . $Param{Field} . '"!',
                Silent   => $Param{Silent}
            );
            return;
        }

        # convert back to timestamp (relative calculations have been done above)
        $Param{Value} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime
        );

        # check for changed value
        if ( $InitialValue ne $Param{Value} ) {
            $IsRelative = 1;
        }
    }

    return ( $Param{Value}, $IsRelative );
}

=item _FulltextCondition()

generate SQL condition query based on a search expression

    my $SQL = $Self->_FulltextCondition(
        Columns       => ['some_col'],
        StaticColumns => ['some_static_col'],
        Value         => 'ABC+DEF',
    );

    example of a more complex search condition

    my $SQL = $Self->_FulltextCondition(
        Key   => [ 'some_col_a', 'some_col_b' ],
        Value => 'ABC&DEF&!GHI',
    );
=cut

sub _FulltextCondition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{Value} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Value!",
            Silent   => $Param{Silent}
        );
        return;
    }

    my @Columns;
    if ( defined $Param{Columns} ) {
        if ( !IsArrayRefWithData($Param{Columns}) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Columns is not an array ref or is empty!",
                Silent   => $Param{Silent}
            );
            return;
        }
        push (@Columns, @{$Param{Columns}});
    }

    if ( !scalar( @Columns ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Columns!",
            Silent   => $Param{Silent}
        );
        return;
    }

    my %StaticColumns;
    if ( IsArrayRefWithData($Param{StaticColumns}) ) {
        %StaticColumns = map { $_ => 1 } @{$Param{StaticColumns}};
    }

    # set case sensitive
    my $CaseSensitive = $Param{CaseSensitive} || 0;

    # escape backslash characters from $Word
    $Param{Value} =~ s{\\}{\\\\}smxg;

    # escape slq wildcard
    $Param{Value} =~ s{%}{\\%}smxg;

    # quote '([^"]?)"([^"]*?)(?:"|$)([^"]?)' expressions
    # for example ("some and me" AND !some), so "some and me" is used for search 1:1
    my $Count = 0;
    my %Expression;
    $Param{Value} =~ s{
        ([^"]?)"([^"]*?)(?:"|$)([^"]?)
    }
    {
        $Count++;
        my $Prefix = $1;
        my $Item   = $2;
        my $Suffix = $3;
        my $Result;
        do {
            $Count++;
            $Result = "###$Count###";
        } while ( $Param{Value} =~ m/$Result/ );

        $Expression{$Result} = $Item;
        if (
            $Prefix !~ /[&|+\s]/
            && $Prefix ne q{}
        ){
            $Prefix = "$Prefix&";
        }
        if (
            $Suffix !~ /[&|+\s]/
            && $Suffix ne q{}
        ){
            $Suffix = "&$Suffix";
        }
        "$Prefix$Result$Suffix";
    }egx;+

    my $Value = $Self->_FulltextValueCleanUp(
        Value  => $Param{Value},
        Silent => $Param{Silent}
    );

    # for processing
    my @Array     = split( // , $Value );
    my $SQL       = q{};
    my $Word      = q{};
    my $Not       = 0;

    # Quoting ESCAPE character backslash
    my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
    my $Escape = " ESCAPE '\\'";
    if ( $QuoteBack ) {
        $Escape =~ s/\\/$QuoteBack\\/g;
    }

    POSITION:
    for my $Position ( 0 .. $#Array ) {
        if (
            $Word eq q{}
            && $Array[$Position] eq q{!}
        ) {
            $Not = 1;
            next POSITION;
        }
        elsif ( $Array[$Position] eq q{&} ) {
            if (
                $Position == 0
                || $Position == $#Array
            ) {
                next POSITION;
            }
        }
        elsif ( $Array[$Position] eq q{|} ) {
            if (
                $Position == 0
                || $Position == $#Array
            ) {
                next POSITION;
            }
        }
        else {
            $Word .= $Array[$Position];
            next POSITION if $Position != $#Array;
        }

        # if word exists, do something with it
        if ( $Word ne q{} ) {

            # replace word if it's an "some expression" expression
            if ( defined $Expression{$Word} ) {
                $Word = $Expression{$Word};
            }

            $Word = $Kernel::OM->Get('DB')->Quote( $Word, 'Like' );

            # database quote
            $Word = q{%} . $Word . q{%};

            # if it's a NOT LIKE condition
            if ($Not) {
                $Not = 0;

                my $SQLA;
                for my $Column (@Columns) {
                    if ($SQLA) {
                        $SQLA .= ' AND ';
                    }

                    # check if like is used
                    my $Type = 'NOT LIKE';
                    if ( $Word !~ m/%/ ) {
                        $Type = q{!=};
                    }

                    $SQLA .= $Self->_FulltextColumnSQL(
                        Type           => $Type,
                        Word           => $Word,
                        Column         => $Column,
                        Silent         => $Param{Silent},
                        CaseSensitive  => $CaseSensitive,
                        IsStaticSearch => $StaticColumns{$Column} || 0
                    );

                    if ( $Type eq 'NOT LIKE' ) {

                        $SQLA .= $Escape;
                    }
                }
                $SQL .= '(' . $SQLA . ') ';
            }

            # if it's a LIKE condition
            else {
                my $SQLA;
                for my $Column (@Columns) {
                    if ($SQLA) {
                        $SQLA .= ' OR ';
                    }

                    # check if like is used
                    my $Type = 'LIKE';
                    if ( $Word !~ m/%/ ) {
                        $Type = q{=};
                    }

                    $SQLA .= $Self->_FulltextColumnSQL(
                        Type           => $Type,
                        Word           => $Word,
                        Column         => $Column,
                        Silent         => $Param{Silent},
                        CaseSensitive  => $CaseSensitive,
                        IsStaticSearch => $StaticColumns{$Column} || 0
                    );

                    if ( $Type eq 'LIKE' ) {
                        $SQLA .= $Escape;
                    }
                }
                $SQL .= '(' . $SQLA . ') ';
            }

            # reset word
            $Word = q{};
        }

        # if it's an AND condition
        if ( $Array[$Position] eq q{&} ) {
            if ( $SQL =~ m/ OR $/ ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message =>
                        "Invalid condition '$Value', simultaneous usage both AND and OR conditions!",
                );
                return "1=0";
            }
            elsif ( $SQL !~ m/ AND $/ ) {
                $SQL .= ' AND ';
            }
        }

        # if it's an OR condition
        elsif (
            $Array[$Position] eq q{|}
        ) {
            if ( $SQL =~ m/ AND $/ ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message =>
                        "Invalid condition '$Param{Value}', simultaneous usage both AND and OR conditions!",
                );
                return "1=0";
            }
            elsif ( $SQL !~ m/ OR $/ ) {
                $SQL .= ' OR ';
            }
        }
    }

    return $SQL;
}

sub _FulltextValueCleanUp {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};
    # remove leading/trailing spaces
    $Value =~ s/^\s+//g;
    $Value =~ s/\s+$//g;

    # replace multiple spaces by &&
    $Value =~ s/\s+/&/g;

    # replace + by &
    $Value =~ s/\+/&/g;

    # replace * with % (for SQL)
    $Value =~ s/\*/%/g;

    # remove double %% (also if there is only whitespace in between)
    $Value =~ s/%\s*%/%/g;

    # replace '%!%' by '!%' (done if * is added by search frontend)
    $Value =~ s/\%!\%/!%/g;

    # replace '%!' by '!%' (done if * is added by search frontend)
    $Value =~ s/\%!/!%/g;

    # remove leading/trailing conditions
    $Value =~ s/(&|\|)(?<!\\)\)$/)/g;
    $Value =~ s/^(?<!\\)\((&|\|)/(/g;

    # clean up not needed spaces in condistions
    # removed spaces examples
    # [SPACE](, [SPACE]), [SPACE]|, [SPACE]&
    # example not removed spaces
    # [SPACE]\\(, [SPACE]\\), [SPACE]\\&
    $Value =~ s{(
        \s
        (
              (?<!\\) \(
            | (?<!\\) \)
            |         \|
            | (?<!\\) &
        )
    )}{$2}xg;

    # removed spaces examples
    # )[SPACE], )[SPACE], |[SPACE], &[SPACE]
    # example not removed spaces
    # \\([SPACE], \\)[SPACE], \\&[SPACE]
    $Value =~ s{(
        (
              (?<!\\) \(
            | (?<!\\) \)
            |         \|
            | (?<!\\) &
        )
        \s
    )}{$2}xg;

    return $Value;
}

sub _FulltextColumnSQL {
    my ( $Self, %Param ) = @_;

    for my $Needed (
        qw(
            Column Type
        )
    ) {
        # check needed stuff
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    my $Column        = $Param{Column};
    my $Type          = $Param{Type};
    my $Word          = $Param{Word} || q{};
    my $SQL           = q{};
    my $CaseSensitive = $Param{CaseSensitive} || 0;

    $Word = lc( q{'} . $Word . q{'} );

    # check if database supports LIKE in large text types
    # the first condition is a little bit opaque
    # CaseSensitive of the database defines, if the database handles case sensitivity or not
    # and the parameter $CaseSensitive defines, if the customer database should do case sensitive statements or not.
    # so if the database dont support case sensitivity or the configuration of the customer database want to do this
    # then we prevent the LOWER() statements.
    if (
        !$Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive')
        || $CaseSensitive
    ) {
        $SQL .= "$Column $Type $Word";
    }
    elsif ( $Kernel::OM->Get('DB')->GetDatabaseFunction('LcaseLikeInLargeText') ) {

        if ( $Param{IsStaticSearch} ) {
            $SQL .= "$Column $Type $Word";
        }
        else {
            $SQL .= "LCASE($Column) $Type $Word";
        }
    }
    else {
        if ( $Param{IsStaticSearch} ) {
            $SQL .= "$Column $Type $Word";
        }
        else {
            $SQL .= "LOWER($Column) $Type $Word";
        }
    }

    return $SQL;
}

=end Internal:

=cut

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
