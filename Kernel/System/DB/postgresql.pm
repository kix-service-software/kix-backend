# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DB::postgresql;

use strict;
use warnings;

use Encode ();

our @ObjectDependencies = (
    'Config',
    'Log',
    'Main',
    'Time',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub LoadPreferences {
    my ( $Self, %Param ) = @_;

    # db settings
    $Self->{'DB::Limit'}       = 'limit';
    $Self->{'DB::DirectBlob'}  = 0;
    $Self->{'DB::QuoteSingle'} = '\'';

    #$Self->{'DB::QuoteBack'}            = '\\';
    $Self->{'DB::QuoteBack'} = '';

    #$Self->{'DB::QuoteSemicolon'}       = '\\';
    $Self->{'DB::QuoteSemicolon'} = '';

    #$Self->{'DB::QuoteUnderscoreStart'} = '\\\\';
    $Self->{'DB::QuoteUnderscoreStart'} = '\\';
    $Self->{'DB::QuoteUnderscoreEnd'}   = '';
    $Self->{'DB::CaseSensitive'}        = 1;
    $Self->{'DB::LikeEscapeString'}     = '';

    # needs to proprocess the data to fix UTF-16 surrogate pairs issues
    $Self->{'DB::PreProcessSQL'}      = 1;
    $Self->{'DB::PreProcessBindData'} = 1;

    # how to determine server version
    # version string can contain a suffix, we only need what's on the left of it
    # example of full string: "PostgreSQL 9.2.4, compiled by Visual C++ build 1600, 64-bit"
    # another example: "PostgreSQL 9.1.9 on i686-pc-linux-gnu"
    # our results: "PostgreSQL 9.2.4", "PostgreSQL 9.1.9".
    $Self->{'DB::Version'} = "SELECT SUBSTRING(VERSION(), 'PostgreSQL [0-9\.]*')";

    # dbi attributes
    $Self->{'DB::Attribute'} = {};

    # set current time stamp if different to "current_timestamp"
    $Self->{'DB::CurrentTimestamp'} = '';

    # set encoding of selected data to utf8
    $Self->{'DB::Encode'} = 0;

    # shell setting
    $Self->{'DB::Comment'}      = '-- ';
    $Self->{'DB::ShellCommit'}  = ';';
    $Self->{'DB::ShellConnect'} = 'SET standard_conforming_strings TO ON';

    # init sql setting on db connect
    $Self->{'DB::Connect'} = "SET standard_conforming_strings TO ON;\n SET NAMES 'utf8';";

    # set handling of null values for ascending order
    $Self->{'DB::OrderByNull'} = 'LAST';

    return 1;
}

sub PreProcessSQL {
    my ( $Self, $SQLRef ) = @_;
    $Self->_FixedSurrogatePairs($SQLRef);
    return;
}

sub PreProcessBindData {
    my ( $Self, $BindRef ) = @_;

    my $Size = scalar @{ $BindRef // [] };

    for ( my $I = 0; $I < $Size; $I++ ) {
        $Self->_FixedSurrogatePairs( \$BindRef->[$I] );
    }
    return;
}

sub _FixedSurrogatePairs {
    my ( $Self, $StringRef ) = @_;

    return if !$$StringRef;
    return if !Encode::is_utf8($$StringRef);

    $$StringRef =~ s/[\x{D800}-\x{DBFF}][\x{DC00}-\x{DFFF}]/"\x{FFFD}"/eg;

    return 1;
}

sub Quote {
    my ( $Self, $Text, $Type ) = @_;

    if ( defined ${$Text} ) {
        if ( $Self->{'DB::QuoteBack'} ) {
            ${$Text} =~ s/\\/$Self->{'DB::QuoteBack'}\\/g;
        }
        if ( $Self->{'DB::QuoteSingle'} ) {
            ${$Text} =~ s/'/$Self->{'DB::QuoteSingle'}'/g;
        }
        if ( $Self->{'DB::QuoteSemicolon'} ) {
            ${$Text} =~ s/;/$Self->{'DB::QuoteSemicolon'};/g;
        }
        if ( $Type && $Type eq 'Like' ) {

            # if $Text contains only backslashes, add a % at the end.
            # newer versions of postgres do not allow an escape character (backslash)
            # at the end of a pattern: "LIKE pattern must not end with escape character"
            ${$Text} =~ s{ \A ( \\+ ) \z }{$1%}xms;

            if ( $Self->{'DB::QuoteUnderscoreStart'} || $Self->{'DB::QuoteUnderscoreEnd'} ) {
                ${$Text}
                    =~ s/_/$Self->{'DB::QuoteUnderscoreStart'}_$Self->{'DB::QuoteUnderscoreEnd'}/g;
            }
        }
    }
    return $Text;
}

sub DatabaseCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!'
        );
        return;
    }

    # return SQL
    return ("CREATE DATABASE $Param{Name}");
}

sub DatabaseDrop {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!'
        );
        return;
    }

    # return SQL
    return ("DROP DATABASE $Param{Name}");
}

sub TableCreate {
    my ( $Self, @Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $SQLStart     = '';
    my $SQLEnd       = '';
    my $SQL          = '';
    my @Column       = ();
    my $TableName    = '';
    my $ForeignKey   = ();
    my %Foreign      = ();
    my $IndexCurrent = ();
    my %Index        = ();
    my $UniqCurrent  = ();
    my %Uniq         = ();
    my $PrimaryKey   = '';
    my @Return       = ();
    for my $Tag (@Param) {

        if (
            ( $Tag->{Tag} eq 'Table' || $Tag->{Tag} eq 'TableCreate' )
            && $Tag->{TagType} eq 'Start'
            )
        {
            if ( $ConfigObject->Get('Database::ShellOutput') ) {
                $SQLStart .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
                $SQLStart .= $Self->{'DB::Comment'} . " create table $Tag->{Name}\n";
                $SQLStart .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
            }
        }
        if (
            ( $Tag->{Tag} eq 'Table' || $Tag->{Tag} eq 'TableCreate' )
            && $Tag->{TagType} eq 'Start'
            )
        {
            $SQLStart .= "CREATE TABLE $Tag->{Name} (\n";
            $TableName = $Tag->{Name};
        }
        if (
            ( $Tag->{Tag} eq 'Table' || $Tag->{Tag} eq 'TableCreate' )
            && $Tag->{TagType} eq 'End'
            )
        {
            $SQLEnd .= ")";
        }
        elsif ( $Tag->{Tag} eq 'Column' && $Tag->{TagType} eq 'Start' ) {
            push @Column, $Tag;
        }
        elsif ( $Tag->{Tag} eq 'Index' && $Tag->{TagType} eq 'Start' ) {
            $IndexCurrent = $Tag->{Name};
        }
        elsif ( $Tag->{Tag} eq 'IndexColumn' && $Tag->{TagType} eq 'Start' ) {
            push @{ $Index{$IndexCurrent} }, $Tag;
        }
        elsif ( $Tag->{Tag} eq 'Unique' && $Tag->{TagType} eq 'Start' ) {
            $UniqCurrent = $Tag->{Name} || $TableName . '_U_' . int( rand(999) );
        }
        elsif ( $Tag->{Tag} eq 'UniqueColumn' && $Tag->{TagType} eq 'Start' ) {
            push @{ $Uniq{$UniqCurrent} }, $Tag;
        }
        elsif ( $Tag->{Tag} eq 'ForeignKey' && $Tag->{TagType} eq 'Start' ) {
            $ForeignKey = $Tag->{ForeignTable};
        }
        elsif ( $Tag->{Tag} eq 'Reference' && $Tag->{TagType} eq 'Start' ) {
            push @{ $Foreign{$ForeignKey} }, $Tag;
        }
    }
    for my $Tag (@Column) {

        # type translation
        $Tag = $Self->_TypeTranslation($Tag);

        # add new line
        if ($SQL) {
            $SQL .= ",\n";
        }

        # auto increment
        if ( $Tag->{AutoIncrement} && $Tag->{AutoIncrement} =~ /^true$/i ) {
            $SQL = "    $Tag->{Name} serial";
            if ( $Tag->{Type} =~ /^bigint$/i ) {
                $SQL = "    $Tag->{Name} bigserial";
            }
        }

        # normal data type
        else {
            $SQL .= "    $Tag->{Name} $Tag->{Type}";
        }

        # handle default
        if ( defined $Tag->{Default} ) {
            if ( $Tag->{Type} =~ /int/i ) {
                $SQL .= " DEFAULT " . $Tag->{Default};
            }
            else {
                $SQL .= " DEFAULT '" . $Tag->{Default} . "'";
            }
        }

        # handle require
        if ( $Tag->{Required} && lc $Tag->{Required} eq 'true' ) {
            $SQL .= ' NOT NULL';
        }
        else {
            $SQL .= ' NULL';
        }

        # add primary key
        if ( $Tag->{PrimaryKey} && $Tag->{PrimaryKey} =~ /true/i ) {
            $PrimaryKey = "    PRIMARY KEY($Tag->{Name})";
        }
    }

    # add primary key
    if ($PrimaryKey) {
        if ($SQL) {
            $SQL .= ",\n";
        }
        $SQL .= $PrimaryKey;
    }

    # add uniq
    for my $Name ( sort keys %Uniq ) {
        if ($SQL) {
            $SQL .= ",\n";
        }
        $SQL .= "    CONSTRAINT $Name UNIQUE (";
        my @Array = @{ $Uniq{$Name} };
        for ( 0 .. $#Array ) {
            if ( $_ > 0 ) {
                $SQL .= ", ";
            }
            $SQL .= $Array[$_]->{Name};
        }
        $SQL .= ")";
    }
    $SQL .= "\n";
    push @Return, $SQLStart . $SQL . $SQLEnd;

    # add indexs
    for my $Name ( sort keys %Index ) {
        push(
            @Return,
            $Self->IndexCreate(
                TableName => $TableName,
                Name      => $Name,
                Data      => $Index{$Name},
            ),
        );
    }

    # add foreign keys
    for my $ForeignKey ( sort keys %Foreign ) {
        my @Array = @{ $Foreign{$ForeignKey} };
        for ( 0 .. $#Array ) {
            push(
                @{ $Self->{Post} },
                $Self->ForeignKeyCreate(
                    LocalTableName   => $TableName,
                    Local            => $Array[$_]->{Local},
                    ForeignTableName => $ForeignKey,
                    Foreign          => $Array[$_]->{Foreign},
                ),
            );
        }
    }
    return @Return;
}

sub TableDrop {
    my ( $Self, @Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $SQL = '';
    for my $Tag (@Param) {
        if ( $Tag->{Tag} eq 'Table' && $Tag->{TagType} eq 'Start' ) {
            if ( $ConfigObject->Get('Database::ShellOutput') ) {
                $SQL .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
                $SQL .= $Self->{'DB::Comment'} . " drop table $Tag->{Name}\n";
                $SQL .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
            }
        }
        $SQL .= "DROP TABLE $Tag->{Name}";
        return ($SQL);
    }
    return ();
}

sub TableAlter {
    my ( $Self, @Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $SQLStart      = '';
    my @SQL           = ();
    my @Index         = ();
    my $IndexName     = ();
    my $ForeignTable  = '';
    my $ReferenceName = '';
    my @Reference     = ();
    my $Table         = '';
    my @Primary       = ();

    TAG:
    for my $Tag (@Param) {

        if ( $Tag->{Tag} eq 'TableAlter' && $Tag->{TagType} eq 'Start' ) {
            $Table = $Tag->{Name} || $Tag->{NameNew};
            if ( $ConfigObject->Get('Database::ShellOutput') ) {
                $SQLStart .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
                $SQLStart .= $Self->{'DB::Comment'} . " alter table $Table\n";
                $SQLStart .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
            }

            # rename table
            if ( $Tag->{NameOld} && $Tag->{NameNew} ) {
                push @SQL, $SQLStart . "ALTER TABLE $Tag->{NameOld} RENAME TO $Tag->{NameNew}";
            }
            $SQLStart .= "ALTER TABLE $Table";
        }
        elsif ( $Tag->{Tag} eq 'ColumnAdd' && $Tag->{TagType} eq 'Start' ) {

            # Type translation
            $Tag = $Self->_TypeTranslation($Tag);

            # auto increment
            if ( $Tag->{AutoIncrement} && $Tag->{AutoIncrement} =~ /^true$/i ) {

                my $PseudoType = 'serial';
                if ( $Tag->{Type} =~ /^bigint$/i ) {
                    $PseudoType = 'bigserial';
                }
                push @SQL, $SQLStart . " ADD $Tag->{Name} $PseudoType NOT NULL";
            } else {

                # normal data type
                push @SQL, $SQLStart . " ADD $Tag->{Name} $Tag->{Type} NULL";
            }

            # investigate the default value
            my $Default = '';
            if ( $Tag->{Type} =~ /int/i ) {
                $Default = defined $Tag->{Default} ? $Tag->{Default} : 0;
            }
            else {
                $Default = defined $Tag->{Default} ? "'$Tag->{Default}'" : "''";
            }

            # investigate the require
            my $Required = ( $Tag->{Required} && lc $Tag->{Required} eq 'true' ) ? 1 : 0;

            # handle default and require
            if ( $Required || defined $Tag->{Default} ) {

                # fill up empty rows
                push @SQL, "UPDATE $Table SET $Tag->{Name} = $Default WHERE $Tag->{Name} IS NULL";

                # add default
                if ( defined $Tag->{Default} ) {
                    push @SQL, "ALTER TABLE $Table ALTER $Tag->{Name} SET DEFAULT $Default";
                }

                # add require
                if ($Required) {
                    push @SQL, "ALTER TABLE $Table ALTER $Tag->{Name} SET NOT NULL";
                }
            }

            # primary
            if ( $Tag->{PrimaryKey} && $Tag->{PrimaryKey} =~ /true/i ) {
                push(@SQL, $SQLStart . " ADD CONSTRAINT $Table\_pkey PRIMARY KEY($Tag->{Name})");
            }
        }
        elsif ( $Tag->{Tag} eq 'ColumnChange' && $Tag->{TagType} eq 'Start' ) {

            # Type translation
            $Tag = $Self->_TypeTranslation($Tag);

            # normal data type
            if ( $Tag->{NameOld} ne $Tag->{NameNew} ) {
                push @SQL, $SQLStart . " RENAME $Tag->{NameOld} TO $Tag->{NameNew}";
            }

            # adds USING when the type category changes (e.g. from String to Numeric)
            my %TypeCat = (
                'VARCHAR' => 'STRING',
                'BIGINT'  => 'NUMERIC',
                'INTEGER' => 'NUMERIC'
            );
            my $Using = q{};
            if (
                $Tag->{TypeOld}
                && $Tag->{Type}
                && $TypeCat{$Tag->{TypeOld}}
                && $TypeCat{$Tag->{Type}}
                && $TypeCat{$Tag->{TypeOld}} ne $TypeCat{$Tag->{Type}}
            ) {
                $Using = "USING $Tag->{NameNew}::$Tag->{Type}"
            }

            push @SQL, $SQLStart . " ALTER $Tag->{NameNew} TYPE $Tag->{Type} $Using";

            # if there is an AutoIncrement column no other changes are needed
            next TAG if $Tag->{AutoIncrement} && $Tag->{AutoIncrement} =~ /^true$/i;

            # remove possible default
            push @SQL, "ALTER TABLE $Table ALTER $Tag->{NameNew} DROP DEFAULT";

            # remove required
            push @SQL, "ALTER TABLE $Table ALTER $Tag->{NameNew} DROP NOT NULL";

            # investigate the default value
            my $Default = '';
            if ( $Tag->{Type} =~ /int/i ) {
                $Default = defined $Tag->{Default} ? $Tag->{Default} : 0;
            }
            else {
                $Default = defined $Tag->{Default} ? "'$Tag->{Default}'" : "''";
            }

            # investigate the require
            my $Required = ( $Tag->{Required} && lc $Tag->{Required} eq 'true' ) ? 1 : 0;

            # handle default and require
            if ( $Required || defined $Tag->{Default} ) {

                # fill up empty rows
                push @SQL,
                    "UPDATE $Table SET $Tag->{NameNew} = $Default WHERE $Tag->{NameNew} IS NULL";

                # add default
                if ( defined $Tag->{Default} ) {
                    push @SQL, "ALTER TABLE $Table ALTER $Tag->{NameNew} SET DEFAULT $Default";
                }

                # add require
                if ($Required) {
                    push @SQL, "ALTER TABLE $Table ALTER $Tag->{NameNew} SET NOT NULL";
                }
            }
        }
        elsif ( $Tag->{Tag} eq 'ColumnDrop' && $Tag->{TagType} eq 'Start' ) {
            my $SQLEnd = $SQLStart . " DROP $Tag->{Name}";
            push @SQL, $SQLEnd;
        }
        elsif ( $Tag->{Tag} =~ /^((Index|Unique)(Create|Drop))/ ) {
            my $Method = $Tag->{Tag};
            if ( $Tag->{Name} ) {
                $IndexName = $Tag->{Name};
            }
            if ( $Tag->{TagType} eq 'End' ) {
                push @SQL, $Self->$Method(
                    TableName => $Table,
                    Name      => $IndexName,
                    Data      => \@Index,
                );
                $IndexName = '';
                @Index     = ();
            }
        }
        elsif ( $Tag->{Tag} =~ /^(IndexColumn|UniqueColumn)/ && $Tag->{TagType} eq 'Start' ) {
            push @Index, $Tag;
        }
        elsif ( $Tag->{Tag} =~ /^((ForeignKey)(Create|Drop))/ ) {
            my $Method = $Tag->{Tag};
            if ( $Tag->{ForeignTable} ) {
                $ForeignTable = $Tag->{ForeignTable};
            }
            if ( $Tag->{TagType} eq 'End' ) {
                for my $Reference (@Reference) {
                    push @SQL, $Self->$Method(
                        LocalTableName   => $Table,
                        Local            => $Reference->{Local},
                        ForeignTableName => $ForeignTable,
                        Foreign          => $Reference->{Foreign},
                    );
                }
                $ReferenceName = '';
                @Reference     = ();
            }
        }
        elsif ( $Tag->{Tag} =~ /^(Reference)/ && $Tag->{TagType} eq 'Start' ) {
            push @Reference, $Tag;
        }

        # primary key
        elsif ( $Tag->{Tag} =~ 'PrimaryCreate' && $Tag->{TagType} ) {
            my $Method = $Tag->{Tag};
            if ( $Tag->{TagType} eq 'End' ) {
                push @SQL, $Self->$Method(
                    TableName => $Table,
                    Data      => \@Primary,
                    SQLStart  => $SQLStart
                );
                @Primary = ();
            }
        }
        elsif ( $Tag->{Tag} =~ /^(PrimaryColumn)/ && $Tag->{TagType} eq 'Start' ) {
            push @Primary, $Tag;
        }
        elsif ( $Tag->{Tag} =~ 'PrimaryDrop' && $Tag->{TagType} eq 'Start' ) {
            push(@SQL, $SQLStart . " DROP CONSTRAINT $Table\_pkey");
        }
    }
    return @SQL;
}

sub PrimaryCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TableName SQLStart Data)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $SQL   = "$Param{SQLStart} ADD CONSTRAINT $Param{TableName}_pkey PRIMARY KEY(";
    my @Array = @{ $Param{Data} };
    for ( 0 .. $#Array ) {
        if ( $_ > 0 ) {
            $SQL .= ', ';
        }
        $SQL .= $Array[$_]->{Name};
    }
    $SQL .= ')';

    # return SQL
    return ($SQL);

}

sub IndexCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TableName Name Data)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my $SQL   = "CREATE INDEX $Param{Name} ON $Param{TableName} (";
    my @Array = @{ $Param{Data} };
    for ( 0 .. $#Array ) {
        if ( $_ > 0 ) {
            $SQL .= ', ';
        }
        $SQL .= $Array[$_]->{Name};
        if ( $Array[$_]->{Size} ) {

            #           $SQL .= "($Array[$_]->{Size})";
        }
    }
    $SQL .= ')';

    # return SQL
    return ($SQL);

}

sub IndexDrop {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TableName Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my $SQL = 'DROP INDEX ' . $Param{Name};
    return ($SQL);
}

sub ForeignKeyCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(LocalTableName Local ForeignTableName Foreign)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create foreign key name
    my $ForeignKey = "FK_$Param{LocalTableName}_$Param{Local}_$Param{Foreign}";
    if ( length($ForeignKey) > 60 ) {
        my $MD5 = $Kernel::OM->Get('Main')->MD5sum(
            String => $ForeignKey,
        );
        $ForeignKey = substr $ForeignKey, 0, 58;
        $ForeignKey .= substr $MD5, 0,  1;
        $ForeignKey .= substr $MD5, 31, 1;
    }

    # add foreign key
    my $SQL = "ALTER TABLE $Param{LocalTableName} ADD CONSTRAINT $ForeignKey FOREIGN KEY "
        . "($Param{Local}) REFERENCES $Param{ForeignTableName} ($Param{Foreign})";

    return ($SQL);
}

sub ForeignKeyDrop {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(LocalTableName Local ForeignTableName Foreign)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create foreign key name
    my $ForeignKey = "FK_$Param{LocalTableName}_$Param{Local}_$Param{Foreign}";
    if ( length($ForeignKey) > 60 ) {
        my $MD5 = $Kernel::OM->Get('Main')->MD5sum(
            String => $ForeignKey,
        );
        $ForeignKey = substr $ForeignKey, 0, 58;
        $ForeignKey .= substr $MD5, 0,  1;
        $ForeignKey .= substr $MD5, 31, 1;
    }

    # drop foreign key
    my $SQL = "ALTER TABLE $Param{LocalTableName} DROP CONSTRAINT $ForeignKey";

    return ($SQL);
}

sub UniqueCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TableName Name Data)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my $SQL   = "ALTER TABLE $Param{TableName} ADD CONSTRAINT $Param{Name} UNIQUE (";
    my @Array = @{ $Param{Data} };
    for ( 0 .. $#Array ) {
        if ( $_ > 0 ) {
            $SQL .= ', ';
        }
        $SQL .= $Array[$_]->{Name};
    }
    $SQL .= ')';

    # return SQL
    return ($SQL);

}

sub UniqueDrop {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TableName Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my $SQL = "ALTER TABLE $Param{TableName} DROP CONSTRAINT $Param{Name}";
    return ($SQL);
}

sub Insert {
    my ( $Self, @Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $TimeObject   = $Kernel::OM->Get('Time');

    my $SQL    = '';
    my @Keys   = ();
    my @Values = ();
    TAG:
    for my $Tag (@Param) {
        if ( $Tag->{Tag} eq 'Insert' && $Tag->{TagType} eq 'Start' ) {
            if ( $ConfigObject->Get('Database::ShellOutput') ) {
                $SQL .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
                $SQL .= $Self->{'DB::Comment'} . " insert into table $Tag->{Table}\n";
                $SQL .= $Self->{'DB::Comment'}
                    . "----------------------------------------------------------\n";
            }
            $SQL .= "INSERT INTO $Tag->{Table} ";
        }
        if ( $Tag->{Tag} eq 'Data' && $Tag->{TagType} eq 'Start' ) {

            # do not use auto increment values, in other cases use something like
            # SELECT setval('table_id_seq', (SELECT max(id) FROM table));
            if ( $Tag->{Type} && $Tag->{Type} =~ /^AutoIncrement$/i ) {
                next TAG;
            }
            $Tag->{Key} = ${ $Self->Quote( \$Tag->{Key} ) };
            push @Keys, $Tag->{Key};
            my $Value;
            if ( defined $Tag->{Value} ) {
                $Value = $Tag->{Value};
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'The content for inserts is not longer appreciated '
                        . 'attribut Value, use Content from now on! Reason: You can\'t '
                        . 'use new lines in attributes.',
                );
            }
            elsif ( defined $Tag->{Content} ) {
                $Value = $Tag->{Content};
            }
            else {
                $Value = '';
            }
            if ( $Tag->{DecodeBase64} && $Tag->{DecodeBase64} eq 'true' ) {
                $Value = MIME::Base64::decode_base64($Value);
            }
            if ( $Tag->{Type} && $Tag->{Type} eq 'Quote' ) {
                $Value = "'" . ${ $Self->Quote( \$Value ) } . "'";
            }
            else {
                $Value = ${ $Self->Quote( \$Value ) };
            }
            push @Values, $Value;
        }
    }
    my $Key = '';
    for (@Keys) {
        if ( $Key ne '' ) {
            $Key .= ', ';
        }
        $Key .= $_;
    }
    my $Value = '';
    for my $Tmp (@Values) {
        if ( $Value ne '' ) {
            $Value .= ', ';
        }
        if ( $Tmp eq 'current_timestamp' ) {
            if ( $ConfigObject->Get('Database::ShellOutput') ) {
                $Value .= $Tmp;
            }
            else {
                my $Timestamp = $TimeObject->CurrentTimestamp();
                $Value .= '\'' . $Timestamp . '\'';
            }
        }
        else {
            $Value .= $Tmp;
        }
    }
    $SQL .= "($Key)\n    VALUES\n    ($Value)";
    return ($SQL);
}

sub _TypeTranslation {
    my ( $Self, $Tag ) = @_;

    # type translation
    if ( $Tag->{Type} =~ /^DATE$/i ) {
        $Tag->{Type} = 'timestamp(0)';
    }

    # performance option
    elsif ( $Tag->{Type} =~ /^longblob$/i ) {
        $Tag->{Type} = 'TEXT';
    }
    elsif ( $Tag->{Type} =~ /^VARCHAR$/i ) {
        $Tag->{Type} = 'VARCHAR (' . $Tag->{Size} . ')';
        if ( $Tag->{Size} >= 10000 ) {
            $Tag->{Type} = 'VARCHAR';
        }
    }
    elsif ( $Tag->{Type} =~ /^DECIMAL$/i ) {
        $Tag->{Type} = 'DECIMAL (' . $Tag->{Size} . ')';
    }
    return $Tag;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
