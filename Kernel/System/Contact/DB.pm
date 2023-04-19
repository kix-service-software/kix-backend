# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Contact::DB;

use strict;
use warnings;

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'CheckItem',
    'DB',
    'Encode',
    'Log',
    'Main',
    'Time',
    'Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed data
    for my $Needed (qw( PreferencesObject ContactMap )) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    # get database object
    $Self->{DBObject} = $Kernel::OM->Get('DB');
    # KIX4OTRS-capeIT
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    # EO KIX4OTRS-capeIT

    # max shown user per search list
    $Self->{UserSearchListLimit} = $Self->{ContactMap}->{ContactSearchListLimit} || 0;

    # config options
    $Self->{CustomerTable} = $Self->{ContactMap}->{Params}->{Table}
        || die "Need Contact->Params->Table in Kernel/Config.pm!";
    $Self->{CustomerKey} = $Self->{ContactMap}->{CustomerKey}
        || $Self->{ContactMap}->{Key}
        || die "Need Contact->CustomerKey in Kernel/Config.pm!";
    $Self->{CustomerID} = $Self->{ContactMap}->{CustomerID}
        || die "Need Contact->CustomerID in Kernel/Config.pm!";
    $Self->{ReadOnly}                 = $Self->{ContactMap}->{ReadOnly};
    $Self->{ExcludePrimaryCustomerID} = $Self->{ContactMap}->{ContactExcludePrimaryCustomerID} || 0;
    $Self->{SearchPrefix}             = $Self->{ContactMap}->{ContactSearchPrefix};

    if ( !defined $Self->{SearchPrefix} ) {
        $Self->{SearchPrefix} = '';
    }
    $Self->{SearchSuffix} = $Self->{ContactMap}->{ContactSearchSuffix};
    if ( !defined $Self->{SearchSuffix} ) {
        $Self->{SearchSuffix} = '*';
    }

    # check if CustomerKey is var or int
    ENTRY:
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        if ( $Entry->{Attribute} eq 'UserLogin' && $Entry->{Type} =~ /^int$/i ) {
            $Self->{CustomerKeyInteger} = 1;
            last ENTRY;
        }
    }

    # set cache type
    $Self->{CacheType} = 'Contact' . $Param{Count};

    # create cache object, but only if CacheTTL is set in customer config
    if ( $Self->{ContactMap}->{CacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Cache');
    }

    # create new db connect if DSN is given
    if ( $Self->{ContactMap}->{Params}->{DSN} ) {
        $Self->{DBObject} = Kernel::System::DB->new(
            DatabaseDSN  => $Self->{ContactMap}->{Params}->{DSN},
            DatabaseUser => $Self->{ContactMap}->{Params}->{User},
            DatabasePw   => $Self->{ContactMap}->{Params}->{Password},
            %{ $Self->{ContactMap}->{Params} },
        ) || die('Can\'t connect to database!');

        # remember that we have the DBObject not from parent call
        $Self->{NotParentDBObject} = 1;
    }

    # this setting specifies if the table has the create_time,
    # create_by, change_time and change_by fields of KIX
    $Self->{ForeignDB} = $Self->{ContactMap}->{Params}->{ForeignDB} ? 1 : 0;

    # defines if the database search will be performend case sensitive (1) or not (0)
    $Self->{CaseSensitive} = $Self->{ContactMap}->{Params}->{SearchCaseSensitive}
        // $Self->{ContactMap}->{Params}->{CaseSensitive} || 0;

    return $Self;
}

sub CustomerName {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!',
        );
        return;
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Name = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "CustomerName::$Param{UserLogin}",
        );
        return $Name if defined $Name;
    }

    # build SQL string 1/2
    my $SQL = "SELECT ";
    if ( $Self->{ContactMap}->{ContactNameFields} ) {
        $SQL .= join( ", ", @{ $Self->{ContactMap}->{ContactNameFields} } );
    }
    else {
        $SQL .= "first_name, last_name ";
    }
    $SQL .= " FROM $Self->{CustomerTable} WHERE ";

    # check CustomerKey type
    my $UserLogin = $Param{UserLogin};
    if ( $Self->{CaseSensitive} ) {
        $SQL .= "$Self->{CustomerKey} = ?";
    }
    else {
        $SQL .= "LOWER($Self->{CustomerKey}) = LOWER(?)";
    }

    # get data
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{UserLogin} ],
        Limit => 1,
    );
    my @NameParts;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        FIELD:
        for my $Field (@Row) {
            next FIELD if !$Field;
            push @NameParts, $Field;
        }
    }
    my $Name = join( ' ', @NameParts );

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "CustomerName::$Param{UserLogin}",
            Value => $Name,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }
    return $Name;
}

sub CustomerSearch {
    my ( $Self, %Param ) = @_;

    my %Users;
    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # check cache
    my $CacheKey = "CustomerSearch::".(join '::', map { $_ . '=' . $Param{$_} } sort keys %Param);

    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType} . '_CustomerSearch',
            Key  => $CacheKey,
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    # build SQL string 1/2
    my $SQL = "SELECT $Self->{CustomerKey} ";
    my @Bind;

    # KIX4OTRS-capeIT
    # if ( $Self->{ContactMap}->{ContactListFields} ) {
    if ( $Param{ListFields} && $Param{ListFields} ne '' ) {
        $SQL .= $Param{ListFields};
    }
    elsif ( $Self->{ContactMap}->{ContactListFields} ) {

        # EO KIX4OTRS-capeIT
        for my $Entry ( @{ $Self->{ContactMap}->{ContactListFields} } ) {
            $SQL .= ", $Entry";
        }
    }
    else {
        $SQL .= " , first_name, last_name, email ";
    }

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $Self->{DBObject}->GetDatabaseFunction('LikeEscapeString');

    # build SQL string 2/2
    $SQL .= " FROM $Self->{CustomerTable} ";
    if ( $Param{Search} ) {
        if ( !$Self->{ContactMap}->{ContactSearchFields} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Need ContactSearchFields in Contact config, unable to search for '$Param{Search}'!",
            );
            return;
        }

        my $Search = $Self->{DBObject}->QueryStringEscape( QueryString => $Param{Search} );

        my %QueryCondition = $Self->{DBObject}->QueryCondition(
            Key           => $Self->{ContactMap}->{ContactSearchFields},
            Value         => $Search,
            SearchPrefix  => $Self->{SearchPrefix},
            SearchSuffix  => $Self->{SearchSuffix},
            CaseSensitive => $Self->{CaseSensitive},
            BindMode      => 1,
        );

        $SQL .= "WHERE ".$QueryCondition{SQL};
        push @Bind, @{ $QueryCondition{Values} };

        $SQL .= ' ';
    }
    elsif ( $Param{PostMasterSearch} ) {
        if ( $Self->{ContactMap}->{ContactPostMasterSearchFields} ) {
            my $SQLExt = '';
            for my $Field ( @{ $Self->{ContactMap}->{ContactPostMasterSearchFields} } ) {
                if ($SQLExt) {
                    $SQLExt .= ' OR ';
                }
                my $PostMasterSearch = $Self->{DBObject}->Quote( $Param{PostMasterSearch} );
                push @Bind, \$PostMasterSearch;

                if ( $Self->{CaseSensitive} ) {
                    $SQLExt .= " $Field = ? ";
                }
                else {
                    $SQLExt .= " LOWER($Field) = LOWER(?) ";
                }
            }
            $SQL .= "WHERE ".$SQLExt;
        }
    }
    elsif ( $Param{UserLogin} ) {

        my $UserLogin = $Param{UserLogin};

        # check CustomerKey type
        if ( $Self->{CustomerKeyInteger} ) {

            # return if login is no integer
            return if $Param{UserLogin} !~ /^(\+|\-|)\d{1,16}$/;

            $SQL .= "WHERE $Self->{CustomerKey} = ?";
            push @Bind, \$UserLogin;
        }
        else {
            $UserLogin = '%' . $Self->{DBObject}->Quote( $UserLogin, 'Like' ) . '%';
            $UserLogin =~ s/\*/%/g;
            push @Bind, \$UserLogin;
            if ( $Self->{CaseSensitive} ) {
                $SQL .= "WHERE $Self->{CustomerKey} LIKE ? $LikeEscapeString";
            }
            else {
                $SQL .= "WHERE LOWER($Self->{CustomerKey}) LIKE LOWER(?) $LikeEscapeString";
            }
        }
    }
    elsif ( $Param{CustomerID} ) {

        my $CustomerID = $Self->{DBObject}->Quote( $Param{CustomerID}, 'Like' );
        $CustomerID =~ s/\*/%/g;
        push @Bind, \$CustomerID;

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "WHERE $Self->{CustomerID} LIKE ? $LikeEscapeString";
        }
        else {
            $SQL .= "WHERE LOWER($Self->{CustomerID}) LIKE LOWER(?) $LikeEscapeString";
        }

        # KIX4OTRS-capeIT
        # if multiple customer ids used
        if ( $Param{MultipleCustomerIDs} ) {

            my $CustomerIDsMap;
            for my $Field ( @{ $Self->{ContactMap}->{Map} } ) {
                next if $Field->{Attribute} !~ m/UserCustomerIDs$/;
                $CustomerIDsMap = $Field;
            }

            # if mapping exists
            if ( $CustomerIDsMap && $CustomerIDsMap->{Type} )
            {
                my $MultipleCustomerID = '%'.$CustomerID.'%';
                push @Bind, \$MultipleCustomerID;
                if ( $Self->{CaseSensitive} ) {
                    $SQL .= " OR $CustomerIDsMap->{MappedTo} LIKE ? $LikeEscapeString";
                }
                else {
                    $SQL .= " OR LOWER($CustomerIDsMap->{MappedTo}) LIKE LOWER(?) $LikeEscapeString"
                }
            }
        }

        # EO KIX4OTRS-capeIT
    }
    elsif ( $Param{CustomerIDRaw} ) {

        push @Bind, \$Param{CustomerIDRaw};

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "WHERE $Self->{CustomerID} = ? ";
        }
        else {
            $SQL .= "WHERE LOWER($Self->{CustomerID}) = LOWER(?) ";
        }
    }

    # KIX4OTRS-capeIT
    # add fields based search input
    if ( $Param{SearchFields} ) {
        my $SearchFurtherFields;

        # backend mapping
        if ( $Self->{ContactMap}->{ContactFurtherSearchFields} ) {
            $SearchFurtherFields = $Self->{ContactMap}->{ContactFurtherSearchFields};
        }

        # fallback, if no individual mapping
        else {
            $SearchFurtherFields = $Self->{ConfigObject}->Get("FurtherSearchFields::Mapping");
        }

        my $SQLExt = '';
        for my $Field ( keys %{ $Param{SearchFields} } ) {
            next if !$SearchFurtherFields || !$SearchFurtherFields->{$Field};

            $SQLExt .= ' AND ' if $SQLExt;

            my $Value =
                $Self->{SearchPrefix} . $Param{SearchFields}->{$Field} . $Self->{SearchSuffix};
            $Value =~ s/\*/%/g;

            if ( $SearchFurtherFields->{$Field} =~ /,/ ) {
                my @SearchFields = split( /,/, $SearchFurtherFields->{$Field} );
                my $SQLExt2 = '';
                for my $CurrentSearchField (@SearchFields) {
                    $SQLExt2 .= ' OR ' if $SQLExt2;
                    $SQLExt2 .= "( LOWER("
                        . $CurrentSearchField
                        . ") LIKE LOWER(?) $LikeEscapeString ";
                }
                $SQLExt .= $SQLExt2;
            }
            else {
                $SQLExt .= "( LOWER("
                    . $SearchFurtherFields->{$Field}
                    . ") LIKE LOWER(?) $LikeEscapeString ";
            }
        }
        $SQL .= ' AND ' if ( $SQL =~ /LIKE/ );
        $SQL .= $SQLExt;
    }

    # EO KIX4OTRS-capeIT

    # add valid option
    if ( $Self->{ContactMap}->{CustomerValid} && $Valid ) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Valid');

        if ($SQL !~ / WHERE /g) {
            $SQL .= " WHERE ";
        }
        else {
            $SQL .= " AND ";
        }
        $SQL .= $Self->{ContactMap}->{CustomerValid}
             . ' IN (' . join( ', ', $ValidObject->ValidIDsGet() ) . ') ';
    }

    # get data
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Param{Limit} || $Self->{UserSearchListLimit},
    );
    ROW:
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        next ROW if $Users{ $Row[0] };
        POSITION:
        for my $Position ( 1 .. 8 ) {
            next POSITION if !$Row[$Position];
            $Users{ $Row[0] } .= $Row[$Position] . ' ';
        }
        $Users{ $Row[0] } =~ s/^(.*)\s(.+?\@.+?\..+?)(\s|)$/"$1" <$2>/;
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType} . '_CustomerSearch',
            Key   => $CacheKey,
            Value => \%Users,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }
    return %Users;
}

sub ContactList {
    my ( $Self, %Param ) = @_;

    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "ContactList::$Valid",
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    # do not use valid option if no valid option is used
    if ( !$Self->{ContactMap}->{CustomerValid} ) {
        $Valid = 0;
    }

    # get data
    my %Users = $Self->{DBObject}->GetTableData(
        What  => "$Self->{CustomerKey}, $Self->{CustomerKey}, $Self->{CustomerID}",
        Table => $Self->{CustomerTable},
        Clamp => 1,
        Valid => $Valid,
    );

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "ContactList::$Valid",
            Value => \%Users,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }
    return %Users;
}

sub CustomerIDList {
    my ( $Self, %Param ) = @_;

    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;
    my $SearchTerm = $Param{SearchTerm} || '';

    my $CacheType = $Self->{CacheType} . '_CustomerIDList';
    my $CacheKey  = "CustomerIDList::${Valid}::$SearchTerm";

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Result = $Self->{CacheObject}->Get(
            Type => $CacheType,
            Key  => $CacheKey,
        );
        return @{$Result} if ref $Result eq 'ARRAY';
    }

    my $SQL = "
        SELECT DISTINCT($Self->{CustomerID})
        FROM $Self->{CustomerTable}
        WHERE 1 = 1 ";
    my @Bind;

    # add valid option
    if ( $Self->{ContactMap}->{CustomerValid} && $Valid ) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Valid');

        my $ValidIDs = join( ', ', $ValidObject->ValidIDsGet() );
        $SQL .= "
            AND $Self->{ContactMap}->{CustomerValid} IN ($ValidIDs) ";
    }

    # add search term
    if ($SearchTerm) {
        my $SearchTermEscaped = $Self->{DBObject}->QueryStringEscape( QueryString => $SearchTerm );

        $SQL .= ' AND ';
        my %QueryCondition = $Self->{DBObject}->QueryCondition(
            Key           => $Self->{CustomerID},
            Value         => $SearchTermEscaped,
            SearchPrefix  => $Self->{SearchPrefix},
            SearchSuffix  => $Self->{SearchSuffix},
            CaseSensitive => $Self->{CaseSensitive},
            BindMode      => 1,
        );
        $SQL .= $QueryCondition{SQL};
        push @Bind, @{ $QueryCondition{Values} };

        $SQL .= ' ';
    }

    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my @Result;

    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push @Result, $Row[0];
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $CacheType,
            Key   => $CacheKey,
            Value => \@Result,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }
    return @Result;
}

sub CustomerIDs {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need User!',
        );
        return;
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $CustomerIDs = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "CustomerIDs::$Param{User}",
        );
        return @{$CustomerIDs} if ref $CustomerIDs eq 'ARRAY';
    }

    # get customer data
    my %Data = $Self->ContactGet( User => $Param{User} );

    # there are multi customer ids
    my @CustomerIDs;
    if ( $Data{UserCustomerIDs} ) {

        # used separators
        SPLIT:
        for my $Split ( ';', ',', '|' ) {

            next SPLIT if $Data{UserCustomerIDs} !~ /\Q$Split\E/;

            # split it
            my @IDs = split /\Q$Split\E/, $Data{UserCustomerIDs};

            # KIX4OTRS-capeIT
            #for my $ID ( @IDs ) {
            for my $ID ( sort @IDs ) {

                # EO KIX4OTRS-capeIT

                $ID =~ s/^\s+//g;
                $ID =~ s/\s+$//g;

                # KIX4OTRS-capeIT
                next if !$ID;

                # EO KIX4OTRS-capeIT

                push @CustomerIDs, $ID;
            }
            last SPLIT;
        }

        # fallback if no separator got found
        if ( !@CustomerIDs ) {
            $Data{UserCustomerIDs} =~ s/^\s+//g;
            $Data{UserCustomerIDs} =~ s/\s+$//g;
            push @CustomerIDs, $Data{UserCustomerIDs};
        }
    }

    # use also the primary customer id if not already included
    if ( $Data{UserCustomerID} && !$Self->{ExcludePrimaryCustomerID} && !grep(/^$Data{UserCustomerID}$/g, @CustomerIDs) ) {
        push @CustomerIDs, $Data{UserCustomerID};
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "CustomerIDs::$Param{User}",
            Value => \@CustomerIDs,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }

    return @CustomerIDs;
}

sub ContactGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need User!',
        );
        return;
    }

    # build select
    my $SQL = 'SELECT ';
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        $SQL .= " $Entry->{MappedTo}, ";
    }

    if ( !$Self->{ForeignDB} ) {
        $SQL .= "create_time, create_by, change_time, change_by, ";
    }

    $SQL .= $Self->{CustomerKey} . " FROM $Self->{CustomerTable} WHERE ";

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Data = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "ContactGet::$Param{User}",
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    # check customer key type
    my $User = $Param{User};

    if ( $Self->{CaseSensitive} ) {
        $SQL .= "$Self->{CustomerKey} = ?";
    }
    else {
        $SQL .= "LOWER($Self->{CustomerKey}) = LOWER(?)";
    }

    # ask the database
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$User ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    ROW:
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

        my $MapCounter = 0;

        for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {

            # KIX4OTRS-capeIT
            # $Data{ $Entry->[0] } = $Row[$MapCounter];
            $Data{ $Entry->{Attribute} } = $Row[$MapCounter] || $Entry->{DefaultValue} || '';

            # EO KIX4OTRS-capeIT

            $MapCounter++;
        }

        next ROW if $Self->{ForeignDB};

        for my $Key (qw(CreateTime CreateBy ChangeTime ChangeBy)) {
            $Data{$Key} = $Row[$MapCounter];
            $MapCounter++;
        }
    }

    # check data
    if ( !$Data{UserLogin} ) {

        # cache request
        if ( $Self->{CacheObject} ) {
            $Self->{CacheObject}->Set(
                Type  => $Self->{CacheType},
                Key   => "ContactGet::$Param{User}",
                Value => {},
                TTL   => $Self->{ContactMap}->{CacheTTL},
            );
        }
        return;
    }

    # compat!
    $Data{UserID} = $Data{UserLogin};

    # get preferences
    my %Preferences = $Self->GetPreferences( UserID => $Data{UserID} );

    # add last login timestamp
    if ( $Preferences{UserLastLogin} ) {
        $Preferences{UserLastLoginTimestamp} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Preferences{UserLastLogin},
        );
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "ContactGet::$Param{User}",
            Value => { %Data, %Preferences },
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }

    return ( %Data, %Preferences );
}

sub ContactAdd {
    my ( $Self, %Param ) = @_;

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Customer backend is read only!',
        );
        return;
    }

    # check needed stuff
    ENTRY:
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        if ( !$Param{ $Entry->{Attribute} } && $Entry->{Required} ) {

            # skip UserLogin, will be checked later
            next ENTRY if ( $Entry->{Attribute} eq 'UserLogin' );

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Entry->{Attribute}!",
            );
            return;
        }
    }
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    # if no UserLogin is given
    if ( !$Param{UserLogin} && $Self->{ContactMap}->{AutoLoginCreation} ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime(),
        );
        my $Prefix = $Self->{ContactMap}->{AutoLoginCreationPrefix} || 'auto';
        $Param{UserLogin} = "$Prefix-$Year$Month$Day$Hour$Min" . int( rand(99) );
    }

    # check if user login exists
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!',
        );
        return;
    }

    # check email address if already exists
    if ( $Param{UserEmail} && $Self->{ContactMap}->{ContactEmailUniqCheck} ) {
        my %Result = $Self->CustomerSearch(
            Valid            => 0,
            PostMasterSearch => $Param{UserEmail},
        );
        if (%Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Email already exists!',
            );
            return;
        }
    }

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

    # check email address mx
    if (
        $Param{UserEmail}
        && !$CheckItemObject->CheckEmail( Address => $Param{UserEmail} )
        )
    {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $CheckItemObject->CheckError() . ")!",
        );
        return;
    }

    # quote values
    my %Value;
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        if ( $Entry->{Type} && $Entry->{Type} =~ /^int$/i ) {
            if ( $Param{ $Entry->{Attribute} } ) {
                $Value{ $Entry->{Attribute} } = $Param{ $Entry->{Attribute} };
            }
            else {
                $Value{ $Entry->{Attribute} } = 0;
            }
        }
        else {
            if ( $Param{ $Entry->{Attribute} } ) {
                $Value{ $Entry->{Attribute} } = $Param{ $Entry->{Attribute} };
            }
            else {
                $Value{ $Entry->{Attribute} } = '';
            }
        }
    }

    # build insert
    my $SQL = "INSERT INTO $Self->{CustomerTable} (";
    my @Bind;
    my %SeenKey;    # If the map contains duplicated field names, insert only once.
    my @ColumnNames;

    MAPENTRY:
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        next MAPENTRY if ( lc( $Entry->{Attribute} ) eq "userpassword" );
        next MAPENTRY if $SeenKey{ $Entry->{MappedTo} }++;
        push @ColumnNames, $Entry->{MappedTo};
    }

    $SQL .= join ', ', @ColumnNames;

    if ( !$Self->{ForeignDB} ) {
        $SQL .= ', create_time, create_by, change_time, change_by';
    }

    $SQL .= ') VALUES (';

    my %SeenValue;
    my $BindColumns = 0;

    ENTRY:
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        next ENTRY if ( lc( $Entry->{Attribute} ) eq "userpassword" );
        next ENTRY if $SeenValue{ $Entry->{MappedTo} }++;
        $BindColumns++;
        push @Bind, \$Value{ $Entry->{Attribute} };
    }

    $SQL .= join ', ', ('?') x $BindColumns;

    if ( !$Self->{ForeignDB} ) {
        $SQL .= ', current_timestamp, ?, current_timestamp, ?';
        push @Bind, \$Param{UserID};
        push @Bind, \$Param{UserID};
    }

    $SQL .= ')';

    return if !$Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => \@Bind
    );

    # log notice
    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "Contact: '$Param{UserLogin}' created successfully ($Param{UserID})!",
    );

    # set password
    if ( $Param{UserPassword} ) {
        $Self->SetPassword(
            UserLogin => $Param{UserLogin},
            PW        => $Param{UserPassword}
        );
    }

    $Self->_ContactCacheClear( UserLogin => $Param{UserLogin} );

    return $Param{UserLogin};
}

sub ContactUpdate {
    my ( $Self, %Param ) = @_;

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Customer backend is read only!',
        );
        return;
    }

    # check needed stuff
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        if ( !$Param{ $Entry->{Attribute} } && $Entry->{Required} && $Entry->{Attribute} ne 'UserPassword' ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Entry->{Attribute}!",
            );
            return;
        }
    }

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

    # check email address
    if (
        $Param{UserEmail}
        && !$CheckItemObject->CheckEmail( Address => $Param{UserEmail} )
        )
    {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $CheckItemObject->CheckError() . ")!",
        );
        return;
    }

    # get old user data (pw)
    my %UserData = $Self->ContactGet( User => $Param{ID} );

    # if we update the email address, check if it already exists
    if (
        $Param{UserEmail}
        && $Self->{ContactMap}->{ContactEmailUniqCheck}
        && lc $Param{UserEmail} ne lc $UserData{UserEmail}
        )
    {
        my %Result = $Self->CustomerSearch(
            Valid            => 0,
            PostMasterSearch => $Param{UserEmail},
        );
        if (%Result) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Email already exists!',
            );
            return;
        }
    }

    # quote values
    my %Value;
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        if ( $Entry->{Type} =~ /^int$/i ) {
            if ( $Param{ $Entry->{Attribute} } ) {
                $Value{ $Entry->{Attribute} } = $Param{ $Entry->{Attribute} };
            }
            else {
                $Value{ $Entry->{Attribute} } = 0;
            }
        }
        else {
            if ( $Param{ $Entry->{Attribute} } ) {
                $Value{ $Entry->{Attribute} } = $Param{ $Entry->{Attribute} };
            }
            else {
                $Value{ $Entry->{Attribute} } = "";
            }
        }
    }

    # update db
    my $SQL = "UPDATE $Self->{CustomerTable} SET ";
    my @Bind;

    my %SeenKey;    # If the map contains duplicated field names, insert only once.
    ENTRY:
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        next ENTRY if $Entry->{ReadOnly};                               # skip readonly fields
        next ENTRY if ( lc( $Entry->{Attribute} ) eq "userpassword" );
        next ENTRY if $SeenKey{ $Entry->{MappedTo} }++;
        $SQL .= " $Entry->{MappedTo} = ?, ";
        push @Bind, \$Value{ $Entry->{Attribute} };
    }

    if ( !$Self->{ForeignDB} ) {
        $SQL .= 'change_time = current_timestamp, change_by = ?';
        push @Bind, \$Param{UserID};
    }
    else {
        chop $SQL;
        chop $SQL;
    }

    $SQL .= ' WHERE ';

    if ( $Self->{CaseSensitive} ) {
        $SQL .= "$Self->{CustomerKey} = ?";
    }
    else {
        $SQL .= "LOWER($Self->{CustomerKey}) = LOWER(?)";
    }
    push @Bind, \$Param{ID};

    return if !$Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => \@Bind
    );

    # check if we need to update Customer Preferences
    if ( $Param{UserLogin} ne $UserData{UserLogin} ) {

        # update the preferences
        $Self->{PreferencesObject}->RenamePreferences(
            NewUserID => $Param{UserLogin},
            OldUserID => $UserData{UserLogin},
        );
    }

    # log notice
    $Kernel::OM->Get('Log')->Log(
        Priority => 'info',
        Message  => "Contact: '$Param{UserLogin}' updated successfully ($Param{UserID})!",
    );

    # check pw
    if ( $Param{UserPassword} ) {
        $Self->SetPassword(
            UserLogin => $Param{UserLogin},
            PW        => $Param{UserPassword}
        );
    }

    $Self->_ContactCacheClear( UserLogin => $Param{UserLogin} );
    if ( $Param{UserLogin} ne $UserData{UserLogin} ) {
        $Self->_ContactCacheClear( UserLogin => $UserData{UserLogin} );
    }

    return 1;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    $Self->_ContactCacheClear( UserLogin => $Param{UserID} );

    return $Self->{PreferencesObject}->SetPreferences(%Param);
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    return $Self->{PreferencesObject}->SearchPreferences(%Param);
}

sub _ContactCacheClear {
    my ( $Self, %Param ) = @_;

    return if !$Self->{CacheObject};

    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!',
        );
        return;
    }

    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => "ContactGet::$Param{UserLogin}",
    );
    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => "CustomerName::$Param{UserLogin}",
    );
    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => "CustomerIDs::$Param{UserLogin}",
    );

    # delete all search cache entries
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType} . '_CustomerIDList',
    );
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType} . '_CustomerSearch',
    );

    $Self->{CacheObject}->CleanUp(
        Type => 'CustomerGroup',
    );

    for my $Function (qw(ContactList)) {
        for my $Valid ( 0 .. 1 ) {
            $Self->{CacheObject}->Delete(
                Type => $Self->{CacheType},
                Key  => "${Function}::${Valid}",
            );
        }
    }

    return 1;
}

sub DESTROY {
    my $Self = shift;

    # disconnect if it's not a parent DBObject
    if ( $Self->{NotParentDBObject} ) {
        if ( $Self->{DBObject} ) {
            $Self->{DBObject}->Disconnect();
        }
    }

    return 1;
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
