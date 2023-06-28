# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Contact::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'Encode',
    'Log',
    'Time',
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

    # max shown user a search list
    $Self->{UserSearchListLimit} = $Self->{ContactMap}->{ContactSearchListLimit} || 0;

    # get ldap preferences
    $Self->{Die} = 0;
    if ( defined $Self->{ContactMap}->{Params}->{Die} ) {
        $Self->{Die} = $Self->{ContactMap}->{Params}->{Die};
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # params
    if ( $Self->{ContactMap}->{Params}->{Params} ) {
        $Self->{Params} = $Self->{ContactMap}->{Params}->{Params};
    }

    # Net::LDAP new params
    elsif ( $ConfigObject->Get( 'AuthModule::LDAP::Params' . $Param{Count} ) ) {
        $Self->{Params} = $ConfigObject->Get( 'AuthModule::LDAP::Params' . $Param{Count} );
    }
    else {
        $Self->{Params} = {};
    }

    # host
    if ( $Self->{ContactMap}->{Params}->{Host} ) {
        $Self->{Host} = $Self->{ContactMap}->{Params}->{Host};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Contact->Params->Host in Kernel/Config.pm',
        );
        return;
    }

    # base dn
    if ( defined $Self->{ContactMap}->{Params}->{BaseDN} ) {
        $Self->{BaseDN} = $Self->{ContactMap}->{Params}->{BaseDN};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Contact->Params->BaseDN in Kernel/Config.pm',
        );
        return;
    }

    # scope
    if ( $Self->{ContactMap}->{Params}->{SSCOPE} ) {
        $Self->{SScope} = $Self->{ContactMap}->{Params}->{SSCOPE};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Contact->Params->SSCOPE in Kernel/Config.pm',
        );
        return;
    }

    # search user
    $Self->{SearchUserDN} = $Self->{ContactMap}->{Params}->{UserDN} || '';
    $Self->{SearchUserPw} = $Self->{ContactMap}->{Params}->{UserPw} || '';

    # group dn
    $Self->{GroupDN} = $Self->{ContactMap}->{Params}->{GroupDN} || '';

    # customer key
    if ( $Self->{ContactMap}->{CustomerKey} ) {
        $Self->{CustomerKey} = $Self->{ContactMap}->{CustomerKey};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Contact->CustomerKey in Kernel/Config.pm',
        );
        return;
    }

    # customer id
    if ( $Self->{ContactMap}->{CustomerID} ) {
        $Self->{CustomerID} = $Self->{ContactMap}->{CustomerID};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Contact->CustomerID in Kernel/Config.pm',
        );
        return;
    }

    # ldap filter always used
    $Self->{AlwaysFilter} = $Self->{ContactMap}->{Params}->{AlwaysFilter} || '';

    $Self->{ExcludePrimaryCustomerID} = $Self->{ContactMap}->{ContactExcludePrimaryCustomerID} || 0;
    $Self->{SearchPrefix} = $Self->{ContactMap}->{ContactSearchPrefix};
    if ( !defined $Self->{SearchPrefix} ) {
        $Self->{SearchPrefix} = '';
    }
    $Self->{SearchSuffix} = $Self->{ContactMap}->{ContactSearchSuffix};
    if ( !defined $Self->{SearchSuffix} ) {
        $Self->{SearchSuffix} = '*';
    }

    # charset settings
    $Self->{SourceCharset} = $Self->{ContactMap}->{Params}->{SourceCharset} || '';

    # set cache type
    $Self->{CacheType} = 'Contact' . $Param{Count};

    # create cache object, but only if CacheTTL is set in customer config
    if ( $Self->{ContactMap}->{CacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Cache');
    }

    # get valid filter if used
    $Self->{ValidFilter} = $Self->{ContactMap}->{ContactValidFilter} || '';

    # connect first if Die is enabled, make sure that connection is possible, else die
    if ( $Self->{Die} ) {
        return if !$Self->_Connect();
    }

    return $Self;
}

sub _Connect {
    my ( $Self, %Param ) = @_;

    # return if connection is already open
    return 1 if $Self->{LDAP};

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    $Self->{LDAP} = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );

    if ( !$Self->{LDAP} ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{Host}: $@";
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't connect to $Self->{Host}: $@",
            );
            return;
        }
    }

    my $Result;
    if ( $Self->{SearchUserDN} && $Self->{SearchUserPw} ) {
        $Result = $Self->{LDAP}->bind(
            dn       => $Self->{SearchUserDN},
            password => $Self->{SearchUserPw},
        );
    }
    else {
        $Result = $Self->{LDAP}->bind();
    }

    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $Result->error(),
        );
        $Self->{LDAP}->disconnect();
        return;
    }

    return 1;
}

sub CustomerName {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!'
        );
        return;
    }

    # build filter
    my $Filter = "($Self->{CustomerKey}=" . escape_filter_value( $Param{UserLogin} ) . ')';

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # check cache
    my $Name = '';
    if ( $Self->{CacheObject} ) {
        my $Name = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'CustomerName::' . $Param{UserLogin},
        );
        return $Name if defined $Name;
    }

    # create ldap connect
    return if !$Self->_Connect();

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Self->{UserSearchListLimit},
        attrs     => $Self->{ContactMap}->{ContactNameFields},
    );

    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Search failed! ' . $Result->error(),
        );
        return;
    }

    for my $Entry ( $Result->all_entries() ) {

        for my $Field ( @{ $Self->{ContactMap}->{ContactNameFields} } ) {

            if ( defined $Entry->get_value($Field) ) {

                if ( !$Name ) {
                    $Name = $Self->_ConvertFrom( $Entry->get_value($Field) );
                }
                else {
                    $Name .= ' ' . $Self->_ConvertFrom( $Entry->get_value($Field) );
                }
            }
        }
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'CustomerName::' . $Param{UserLogin},
            Value => $Name,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }

    return $Name;
}

sub CustomerSearch {
    my ( $Self, %Param ) = @_;

    if ( $Param{CustomerIDRaw} ) {
        $Param{CustomerID} = $Param{CustomerIDRaw};
    }

    # check needed stuff
    # KIX4OTRS-capeIT
    #if ( !$Param{Search} && !$Param{UserLogin} && !$Param{PostMasterSearch} ) {
    #    $Kernel::OM->Get('Log')->Log(
    #        Priority => 'error',
    #        Message  => 'Need Search, UserLogin or PostMasterSearch!'
    #    );
    #    return;
    #}
    if (
        !$Param{Search}
        && !$Param{UserLogin}
        && !$Param{PostMasterSearch}
        && !$Param{SearchFields}
        && !$Param{CustomerID}
        )
    {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Search, UserLogin, PostMasterSearch, CustomerID or SearchFields!'
        );
        return;
    }

    # EO KIX4OTRS-capeIT

    # build filter
    my $Filter = '';
    if ( $Param{Search} ) {

        my $Count = 0;
        my @Parts = split( /\+/, $Param{Search}, 6 );
        for my $Part (@Parts) {

            $Part = $Self->{SearchPrefix} . $Part . $Self->{SearchSuffix};
            $Part =~ s/(\%+)/\%/g;
            $Part =~ s/(\*+)\*/*/g;
            $Count++;

            if ( $Self->{ContactMap}->{ContactSearchFields} ) {

                # quote LDAP filter value but keep asterisks unescaped (wildcard)
                $Part =~ s/\*/encodedasterisk20160930/g;
                $Part = escape_filter_value( $Self->_ConvertTo($Part) );
                $Part =~ s/encodedasterisk20160930/*/g;

                $Filter .= '(|';
                for my $Field ( @{ $Self->{ContactMap}->{ContactSearchFields} } ) {
                    $Filter .= "($Field=" . $Part . ')';
                }
                $Filter .= ')';
            }
            else {

                # quote LDAP filter value but keep asterisks unescaped (wildcard)
                $Part =~ s/\*/encodedasterisk20160930/g;
                $Part = escape_filter_value($Part);
                $Part =~ s/encodedasterisk20160930/*/g;

                $Filter .= "($Self->{CustomerKey}=" . $Part . ')';
            }
        }

        if ( $Count > 1 ) {
            $Filter = "(&$Filter)";
        }
    }
    elsif ( $Param{PostMasterSearch} ) {

        if ( $Self->{ContactMap}->{ContactPostMasterSearchFields} ) {

            # quote LDAP filter value but keep asterisks unescaped (wildcard)
            $Param{PostMasterSearch} =~ s/\*/encodedasterisk20160930/g;
            $Param{PostMasterSearch} = escape_filter_value( $Param{PostMasterSearch} );
            $Param{PostMasterSearch} =~ s/encodedasterisk20160930/*/g;

            $Filter = '(|';
            for my $Field ( @{ $Self->{ContactMap}->{ContactPostMasterSearchFields} } ) {
                $Filter .= "($Field=$Param{PostMasterSearch})";
            }
            $Filter .= ')';
        }
    }
    elsif ( $Param{UserLogin} ) {
        $Filter = "($Self->{CustomerKey}=" . escape_filter_value( $Param{UserLogin} ) . ')';
    }
    elsif ( $Param{CustomerID} ) {
        $Filter = "($Self->{CustomerID}=" . escape_filter_value( $Param{CustomerID} ) . ')';

        # KIX4OTRS-capeIT
        # if multiple customer ids used
        if ( $Param{MultipleCustomerIDs} ) {
            my $CustomerIDsMap;
            for my $Field ( @{ $Self->{ContactMap}->{Map} } ) {
                next if $Field->{Attribute}} !~ m/UserCustomerIDs$/;
                $CustomerIDsMap = $Field;
            }

            if ( $CustomerIDsMap && $CustomerIDsMap->{Type} eq 'array' ) {
                $Filter .= " || ( $Self->{CustomerIDs} =~ m/$Param{CustomerID}/ )";
            }
        }

        # EO KIX4OTRS-capeIT
    }

    # KIX4OTRS-capeIT
    # add field based filter input
    if ( $Param{SearchFields} ) {
        my $SearchFurtherFields;

        # backend mapping
        if ( $Self->{ContactMap}->{ContactFurtherSearchFields} ) {
            $SearchFurtherFields = $Self->{ContactMap}->{ContactFurtherSearchFields};
        }

        # fallback, if no individual mapping
        else {
            $SearchFurtherFields = $Kernel::OM->Get('Config')->Get('FurtherSearchFields::Mapping');
        }

        $Filter = "(&$Filter";
        for my $Field ( keys %{ $Param{SearchFields} } ) {
            next if !$SearchFurtherFields || !$SearchFurtherFields->{$Field};

            my $Value =
                $Self->{SearchPrefix} . $Param{SearchFields}->{$Field} . $Self->{SearchSuffix};
            $Value =~ s/(\%+)/\%/g;
            $Value =~ s/(\*+)\*/*/g;

            if ( $SearchFurtherFields->{$Field} =~ /,/ ) {
                my @SearchFields = split( /,/, $SearchFurtherFields->{$Field} );
                $Filter .= '(|';
                for my $CurrentSearchField (@SearchFields) {
                    $Filter .= '(' . $CurrentSearchField . "=$Value)";
                }
                $Filter .= ')';
            }
            else {
                $Filter .= '(' . $SearchFurtherFields->{$Field} . "=$Value)";
            }
        }
        $Filter .= ')';
    }

    # EO KIX4OTRS-capeIT

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # add valid filter
    if ( $Self->{ValidFilter} ) {
        $Filter = "(&$Filter$Self->{ValidFilter})";
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'CustomerSearch::' . $Filter,
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    # create ldap connect
    return if !$Self->_Connect();

    my @Attributes;

    # combine needed attrs
    if ( $Self->{ContactMap}->{ContactListFields} ) {
        @Attributes = ( @{ $Self->{ContactMap}->{ContactListFields} }, $Self->{CustomerKey} );
    }
    else{
        @Attributes = ( $Self->{CustomerKey} );
    }

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Param{Limit} || $Self->{UserSearchListLimit},
        attrs     => \@Attributes,
    );

    # log ldap errors
    if ( $Result->code() ) {

        if ( $Result->code() == 4 ) {

            # Result code 4 (LDAP_SIZELIMIT_EXCEEDED) is normal if there
            # are more items in LDAP than search limit defined in KIX or
            # in LDAP server. Avoid spamming logs with such errors.
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'LDAP size limit exceeded (' . $Result->error() . ').',
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Search failed! ' . $Result->error(),
            );
        }
    }

    my %Users;
    for my $Entry ( $Result->all_entries() ) {

        my $CustomerString = '';

        for my $Field ( @{ $Self->{ContactMap}->{ContactListFields} } ) {

            my $Value = $Self->_ConvertFrom( $Entry->get_value($Field) );

            if ($Value) {
                if ( $Field =~ /^targetaddress$/i ) {
                    $Value =~ s/SMTP:(.*)/$1/;
                }
                $CustomerString .= $Value . ' ';
            }
        }

        $CustomerString =~ s/^(.*)\s(.+?\@.+?\..+?)(\s|)$/"$1" <$2>/;

        if ( defined $Entry->get_value( $Self->{CustomerKey} ) ) {
            $Users{ $Self->_ConvertFrom( $Entry->get_value( $Self->{CustomerKey} ) ) } = $CustomerString;
        }
    }

    # check if user need to be in a group!
    if ( $Self->{GroupDN} ) {

        for my $Filter2 ( sort keys %Users ) {

            my $Result2 = $Self->{LDAP}->search(
                base      => $Self->{GroupDN},
                scope     => $Self->{SScope},
                filter    => 'memberUid=' . escape_filter_value($Filter2),
                sizelimit => $Param{Limit} || $Self->{UserSearchListLimit},
                attrs     => ['1.1'],
            );

            if ( !$Result2->all_entries() ) {
                delete $Users{$Filter2};
            }
        }
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'CustomerSearch::' . $Filter,
            Value => \%Users,
            TTL   => $Self->{ContactMap}->{CacheTTL},
        );
    }

    return %Users;
}

sub ContactList {
    my ( $Self, %Param ) = @_;

    my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;

    # prepare filter
    my $Filter = "($Self->{CustomerKey}=*)";
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # add valid filter
    if ( $Self->{ValidFilter} && $Valid ) {
        $Filter = "(&$Filter$Self->{ValidFilter})";
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Users = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "ContactList::$Filter",
        );
        return %{$Users} if ref $Users eq 'HASH';
    }

    # create ldap connect
    return if !$Self->_Connect();

    # combine needed attrs
    my @Attributes = ( $Self->{CustomerKey}, $Self->{CustomerID} );

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Self->{UserSearchListLimit},
        attrs     => \@Attributes,
    );

    # log ldap errors
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $Result->error(),
        );
    }

    my %Users;
    for my $Entry ( $Result->all_entries() ) {

        my $CustomerString = '';
        for my $Field (@Attributes) {

            my $FieldValue = $Entry->get_value($Field);
            $FieldValue = defined $FieldValue ? $FieldValue : '';

            $CustomerString .= $Self->_ConvertFrom($FieldValue) . ' ';
        }

        my $KeyValue = $Entry->get_value( $Self->{CustomerKey} );
        $KeyValue = defined $KeyValue ? $KeyValue : '';

        $Users{ $Self->_ConvertFrom($KeyValue) } = $CustomerString;
    }

    # check if user need to be in a group!
    if ( $Self->{GroupDN} ) {

        for my $Filter2 ( sort keys %Users ) {

            my $Result2 = $Self->{LDAP}->search(
                base      => $Self->{GroupDN},
                scope     => $Self->{SScope},
                filter    => 'memberUid=' . $Filter2,
                sizelimit => $Self->{UserSearchListLimit},
                attrs     => ['1.1'],
            );

            if ( !$Result2->all_entries() ) {
                delete $Users{$Filter2};
            }
        }
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "ContactList::$Filter",
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

    my $CacheKey = "CustomerIDList::${Valid}::$SearchTerm";

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Result = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return @{$Result} if ref $Result eq 'ARRAY';
    }

    # prepare filter
    my $Filter = "($Self->{CustomerID}=*)";
    if ($SearchTerm) {

        my $SearchFilter = $Self->{SearchPrefix} . $SearchTerm . $Self->{SearchSuffix};
        $SearchFilter =~ s/(\%+)/\%/g;
        $SearchFilter =~ s/(\*+)\*/*/g;

        # quote LDAP filter value but keep asterisks unescaped (wildcard)
        $SearchFilter =~ s/\*/encodedasterisk20160930/g;
        $SearchFilter = escape_filter_value($SearchFilter);
        $SearchFilter =~ s/encodedasterisk20160930/*/g;

        $Filter = "($Self->{CustomerID}=$SearchFilter)";

    }

    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # add valid filter
    if ( $Self->{ValidFilter} && $Valid ) {
        $Filter = "(&$Filter$Self->{ValidFilter})";
    }

    # create ldap connect
    return if !$Self->_Connect();

    # combine needed attrs
    my @Attributes = ( $Self->{CustomerKey}, $Self->{CustomerID} );

    # perform user search
    my $Result = $Self->{LDAP}->search(
        base      => $Self->{BaseDN},
        scope     => $Self->{SScope},
        filter    => $Filter,
        sizelimit => $Self->{UserSearchListLimit},
        attrs     => \@Attributes,
    );

    # log ldap errors
    if ( $Result->code() ) {

        if ( $Result->code() == 4 ) {

            # Result code 4 (LDAP_SIZELIMIT_EXCEEDED) is normal if there
            # are more items in LDAP than search limit defined in KIX or
            # in LDAP server. Avoid spamming logs with such errors.
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'LDAP size limit exceeded (' . $Result->error() . ').',
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Search failed! ' . $Result->error(),
            );
        }
    }

    my %Users;
    for my $Entry ( $Result->all_entries() ) {

        my $FieldValue = $Entry->get_value( $Self->{CustomerID} );
        $FieldValue = defined $FieldValue ? $FieldValue : '';

        my $KeyValue = $Entry->get_value( $Self->{CustomerKey} );
        $KeyValue = defined $KeyValue ? $KeyValue : '';
        $Users{ $Self->_ConvertFrom($KeyValue) } = $Self->_ConvertFrom($FieldValue);
    }

    # check if user need to be in a group!
    if ( $Self->{GroupDN} ) {
        for my $Filter2 ( sort keys %Users ) {
            my $Result2 = $Self->{LDAP}->search(
                base      => $Self->{GroupDN},
                scope     => $Self->{SScope},
                filter    => 'memberUid=' . escape_filter_value($Filter2),
                sizelimit => $Self->{UserSearchListLimit},
                attrs     => ['1.1'],
            );
            if ( !$Result2->all_entries() ) {
                delete $Users{$Filter2};
            }
        }
    }

    # make CustomerIDs unique
    my %Tmp;
    @Tmp{ values %Users } = undef;
    my @Result = keys %Tmp;

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
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
            Message  => 'Need User!'
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
    my %Data = $Self->ContactGet(
        User => $Param{User},
    );

    # there are multi customer ids
    my @CustomerIDs;
    if ( $Data{UserCustomerIDs} ) {

        # used separators
        SEPARATOR:
        for my $Separator ( ';', ',', '|' ) {

            next SEPARATOR if $Data{UserCustomerIDs} !~ /\Q$Separator\E/;

            # split it
            my @IDs = split /\Q$Separator\E/, $Data{UserCustomerIDs};

            # KIX4OTRS-capeIT
            # for my $ID (@IDs) {
            for my $ID ( sort @IDs ) {

                # EO KIX4OTRS-capeIT

                $ID =~ s/^\s+//g;
                $ID =~ s/\s+$//g;

                # KIX4OTRS-capeIT
                next if !$ID;

                # EO KIX4OTRS-capeIT

                push @CustomerIDs, $ID;
            }

            last SEPARATOR;
        }

        # fallback if no separator got found
        if ( !@CustomerIDs ) {
            $Data{UserCustomerIDs} =~ s/^\s+//g;
            $Data{UserCustomerIDs} =~ s/\s+$//g;
            push @CustomerIDs, $Data{UserCustomerIDs};
        }
    }

    # use also the primary customer id
    if ( $Data{UserCustomerID} && !$Self->{ExcludePrimaryCustomerID} ) {
        push @CustomerIDs, $Data{UserCustomerID};
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => 'CustomerIDs::' . $Param{User},
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
            Message  => 'Need User!'
        );
        return;
    }

    # perform user search
    my @Attributes;
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {
        push( @Attributes, $Entry->{MappedTo} );
    }
    my $Filter = "($Self->{CustomerKey}=" . escape_filter_value( $Param{User} ) . ')';

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Data = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => 'ContactGet::' . $Param{User},
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    # create ldap connect
    return if !$Self->_Connect();

    # perform search
    my $Result = $Self->{LDAP}->search(
        base   => $Self->{BaseDN},
        scope  => $Self->{SScope},
        filter => $Filter,
        attrs  => \@Attributes,
    );

    # log ldap errors
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $Result->error(),
        );
        return;
    }

    # get first entry
    my $Result2 = $Result->entry(0);
    if ( !$Result2 ) {
        return;
    }

    # get customer user info
    my %Data;
    for my $Entry ( @{ $Self->{ContactMap}->{Map} } ) {

        # KIX4OTRS-capeIT
        # my $Value = $Self->_ConvertFrom( $Result2->get_value( $Entry->[2] ) ) || '';
        my $Value = "";
        if ( $Entry->{Type} && $Entry->{Type} =~ /^ArrayIndex\[(\d+)\]$/ ) {
            my $Index       = $1;
            my @ResultArray = $Result2->get_value( $Entry->{MappedTo} );
            $Value = $Self->_ConvertFrom( $ResultArray[$Index] ) || '';
        }
        elsif ( $Entry->{Type} && $Entry->{Type} =~ /^ArrayJoin\[(.+)\]$/ ) {
            my $JoinStrg    = $1;
            my @ResultArray = $Result2->get_value( $Entry->{MappedTo} );
            $Value = $Self->_ConvertFrom( join( $JoinStrg, @ResultArray ) ) || '';
        }
        else {
            $Value = $Self->_ConvertFrom( $Result2->get_value( $Entry->{MappedTo} ) ) || '';
        }

        # EO KIX4OTRS-capeIT

        if ( $Value && $Entry->{MappedTo} =~ /^targetaddress$/i ) {
            $Value =~ s/SMTP:(.*)/$1/;
        }

        # KIX4OTRS-capeIT
        if ( !$Value && $Entry->{DefaultValue} ) {
            $Value = $Entry->{DefaultValue};
        }

        # EO KIX4OTRS-capeIT

        $Data{ $Entry->{Attribute} } = $Value;
    }

    # KIX4OTRS-capeIT
    # set certain user attributes depending on group membership...
    my $GroupMemberSyncAttributesDefinition = $Self->{ContactMap}->{GroupMemberSyncAttributes};
    my $ContactDN                      = $Result2->dn();
    my $ContactDNQuote                 = $ContactDN;
    $ContactDNQuote =~ s/\\/\\\\/g;
    $ContactDNQuote =~ s/\(/\\(/g;
    $ContactDNQuote =~ s/\)/\\)/g;

    if ($GroupMemberSyncAttributesDefinition) {

        for my $GroupDN ( sort keys %{$GroupMemberSyncAttributesDefinition} ) {
            my $Filter = '';
            if ( $Self->{ContactMap}->{GroupMemberSyncUserAttr} eq 'DN' ) {
                $Filter =
                    "($Self->{ContactMap}->{GroupMemberSyncAccessAttr}=$ContactDNQuote)";
            }
            else {
                $Filter = "($Self->{ContactMap}->{GroupMemberSyncAccessAttr}=$Param{User})";
            }

            my $Result = $Self->{LDAP}->search(
                base   => $GroupDN,
                filter => $Filter,
            );
            if ( $Result->code ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Search failed! ($GroupDN) filter='$Filter' " . $Result->error,
                );
            }

            my $Valid = '';
            for my $Entry ( $Result->all_entries ) {
                $Valid = $Entry->dn();
            }

            if ($Valid) {
                for my $AttributeKey (
                    keys( %{ $GroupMemberSyncAttributesDefinition->{$GroupDN} } )
                    )
                {
                    $Data{$AttributeKey} =
                        $GroupMemberSyncAttributesDefinition->{$GroupDN}->{$AttributeKey};
                }
            }
        }

    }

    # EO KIX4OTRS-capeIT

    return if !$Data{UserLogin};

    # compat!
    $Data{UserID} = $Data{UserLogin};

    # get preferences
    my %Preferences = $Self->GetPreferences( UserID => $Data{UserLogin} );

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
            Key   => 'ContactGet::' . $Param{User},
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
            Message  => 'Customer backend is read only!'
        );
        return;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => 'Not supported for this module!'
    );

    return;
}

sub ContactUpdate {
    my ( $Self, %Param ) = @_;

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Customer backend is read only!'
        );
        return;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => 'Not supported for this module!'
    );

    return;
}

sub SetPassword {
    my ( $Self, %Param ) = @_;

    my $Pw = $Param{PW} || '';

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Customer backend is read only!'
        );
        return;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => 'Not supported for this module!'
    );

    return;
}

sub GenerateRandomPassword {
    my ( $Self, %Param ) = @_;

    # generated passwords are eight characters long by default.
    my $Size = $Param{Size} || 8;

    # The list of characters that can appear in a randomly generated password.
    # Note that users can put any character into a password they choose themselves.
    my @PwChars = ( 0 .. 9, 'A' .. 'Z', 'a' .. 'z', '-', '_', '!', '@', '#', '$', '%', '^', '&', '*' );

    # number of characters in the list.
    my $PwCharsLen = scalar(@PwChars);

    # generate the password.
    my $Password = '';
    for ( my $i = 0; $i < $Size; $i++ ) {
        $Password .= $PwChars[ rand $PwCharsLen ];
    }

    return $Password;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # cache reset
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Delete(
            Type => $Self->{CacheType},
            Key  => "ContactGet::$Param{UserID}",
        );
    }
    return $Self->{PreferencesObject}->SetPreferences(%Param);
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    return $Self->{PreferencesObject}->SearchPreferences(%Param);
}

sub _ConvertFrom {
    my ( $Self, $Text ) = @_;

    return if !defined $Text;

    if ( !$Self->{SourceCharset} ) {
        return $Text;
    }

    return $Kernel::OM->Get('Encode')->Convert(
        Text => $Text,
        From => $Self->{SourceCharset},
        To   => 'utf-8',
    );
}

sub _ConvertTo {
    my ( $Self, $Text ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Self->{SourceCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    return $EncodeObject->Convert(
        Text => $Text,
        To   => $Self->{SourceCharset},
        From => 'utf-8',
    );
}

sub DESTROY {
    my ( $Self, %Param ) = @_;

    # take down session
    if ( $Self->{LDAP} ) {
        $Self->{LDAP}->unbind();
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
