# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SearchProfile;

use strict;
use warnings;

use Kernel::System::VariableCheck (qw(:all));

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::SearchProfile - module to manage search profiles

=head1 SYNOPSIS

module with all functions to manage search profiles

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');

    $Self->{CacheType} = 'SearchProfile';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # KIX4OTRS-capeIT
    $Self->{LanguageObject} = $Kernel::OM->Get('Kernel::Language');

    # EO KIX4OTRS-capeIT

    return $Self;
}

=item SearchProfileAdd()

to add a search profile item

    $ID = $SearchProfileObject->SearchProfileAdd(
        Object    => 'Ticket',
        Name      => 'last-search',
        UserType  => 'Agent'|'Customer'
        UserLogin => '...',
        SubscribedProfileID => 123,     # optional, ID of the subscribed (referenced) search profile
        Data      => {                  # necessary if no subscription
            Key => Value
        },
        Categories => [                 # optional
            '...'
        ]
    );

=cut

sub SearchProfileAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Object Name UserLogin UserType)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{SubscribedProfileID} && !IsHashRefWithData($Param{Data}) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Data if search profile is no subscription!"
        );
        return;        
    }

    if ( $Param{UserType} !~ /^(Agent|Customer)$/g ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "UserType must be 'Agent' or 'Customer'!"
        );
        return;        
    }

    # find existing profile
    $Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM search_profile WHERE user_login = ? AND user_type = ? AND name = ? AND object = ?',
        Bind  => [ \$Param{UserLogin}, \$Param{UserType}, \$Param{Name}, \$Param{Object} ],
        Limit => 1,
    );
    my $Exists;
    while ( $Self->{DBObject}->FetchrowArray() ) {
        $Exists = 1;
    }

    # add profile to database
    if ($Exists) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t add search profile! A profile with same name already exists for this object.'
        );
        return;
    }

    return if !$Self->{DBObject}->Do(
        SQL => "
            INSERT INTO search_profile (user_login, user_type, name, object, subscribed_profile_id) VALUES (?, ?, ?, ?)",
        Bind => [
            \$Param{UserLogin}, \$Param{UserType}, \$Param{Name}, \$Param{Object}, \$Param{SubscribedProfileID}
        ],
    );

    # get profile id
    $Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM search_profile WHERE user_login = ? AND user_type = ? AND name = ? AND object = ?',
        Bind  => [ 
            \$Param{UserLogin}, \$Param{UserType}, \$Param{Name}, \$Param{Object}
        ],
        Limit => 1,
    );
    my $SearchProfileID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SearchProfileID = $Row[0];
    }

    if ( IsHashRefWithData($Param{Data}) ) {
        # store data into preferences table
        foreach my $Key (sort keys %{$Param{Data}}) {

            my @Data;
            my $Type;
            if ( ref $Param{Data}->{$Key} eq 'ARRAY' ) {
                @Data = @{ $Param{Data}->{$Key} };
                $Type = 'ARRAY';
            }
            else {
                @Data = ( $Param{Data}->{$Key} );
                $Type = 'SCALAR';
            }

            foreach my $Value (@Data) {
                return if !$Self->{DBObject}->Do(
                    SQL => "
                        INSERT INTO search_profile_preferences
                        (search_profile_id, preferences_type, preferences_key, preferences_value)
                        VALUES (?, ?, ?, ?)
                        ",
                    Bind => [
                        \$SearchProfileID, \$Type, \$Key, \$Value,
                    ],
                );
            }
        }
    }

    if ( IsArrayRefWithData($Param{Categories}) ) {
        # store into categories table
        foreach my $Category ( @{$Param{Categories}} ) {

            return if !$Self->{DBObject}->Do(
                SQL => "
                    INSERT INTO search_profile_categories
                    (search_profile_id, category)
                    VALUES (?, ?)
                    ",
                Bind => [
                    \$SearchProfileID, \$Category
                ],
            );
        }
    }    

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $SearchProfileID;
}

=item SearchProfileGet()

returns hash with search profile.

    my %SearchProfile = $SearchProfileObject->SearchProfileGet(
        ID             => 123,
        WithData       => 1,
        WithCategories => 1,
    );

=cut

sub SearchProfileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check the cache
    my $CacheKey = 'SearchProfileGet::' . $Param{ID} . '::' . $Param{WithData};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get search profile
    $Self->{DBObject}->Prepare(
        SQL => "SELECT object, name, user_login, user_type, subscribed_profile_id FROM search_profile WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %SearchProfile;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SearchProfile{ID}        = $Row[0];
        $SearchProfile{Object}    = $Row[1];
        $SearchProfile{Name}      = $Row[2];
        $SearchProfile{UserLogin} = $Row[3];
        $SearchProfile{UserType}  = $Row[4];
        $SearchProfile{SubscribedProfileID} = $Row[5];
    }

    # check service
    if ( !$SearchProfile{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such search profile ($Param{ID})!",
        );
        return;
    }

    if ( $Param{WithData} ) {
        # get search profile data
        return if !$Self->{DBObject}->Prepare(
            SQL => "
                SELECT preferences_type, preferences_key, preferences_value
                FROM search_profile_preferences
                WHERE search_profile_id = ?",
            Bind => [ \$Param{ID} ],
        );

        my %Data;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            if ( $Row[0] eq 'ARRAY' ) {
                push @{ $Data{ $Row[1] } }, $Row[2];
            }
            else {
                $Data{ $Row[1] } = $Row[2];
            }
        }
        %SearchProfile{Data} = \%Data;
    }

    if ( $Param{WithCategories} ) {
        # get search profile categories
        return if !$Self->{DBObject}->Prepare(
            SQL  => "SELECT category FROM search_profile_category WHERE search_profile_id = ?",
            Bind => [ \$Param{ID} ],
        );

        my @Categories;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            push(@Categories, $Row[0])
        }
        %SearchProfile{Categories} = \%Data;
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%SearchProfile
    );

    return %SearchProfile;
}

=item SearchProfileUpdate()

update a search profile

    $Success = $SearchProfileObject->SearchProfileUpdate(
        ID        => 123,
        Name      => 'last-search',     # optional
        SubscribedProfileID => 123,     # optional, ID of the subscribed (referenced) search profile
        Data      => {                  # necessary if no subscription
            Key => Value
        },
        Categories => [                 # optional
            '...'
        ]
    );

=cut

sub SearchProfileUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return 1 if !$Param{Name} && !IsHashRefWithData($Param{Data});

    my %SearchProfile = $Self->SearchProfileGet(
        ID       => $Param{ID},
    );
    return if !%SearchProfile;

    # update name if necessary
    if ( $Param{Name} && $Param{Name} ne $SearchProfile{Name} ) {

        # find existing profile
        $Self->{DBObject}->Prepare(
            SQL   => 'SELECT id FROM search_profile WHERE user_login = ? AND user_type = ? AND name = ? AND object = ? AND id <> ?',
            Bind  => [ \$SearchProfile{UserLogin}, \$SearchProfile{UserType}, \$Param{Name}, \$SearchProfile{Object}, $Param{ID} ],
            Limit => 1,
        );
        my $Exists;
        while ( $Self->{DBObject}->FetchrowArray() ) {
            $Exists = 1;
        }

        # add profile to database
        if ($Exists) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Can\'t add search profile! A profile with same name already exists for this object.'
            );
            return;
        }
        
        return if !$Self->{DBObject}->Do(
            SQL  => "UPDATE search_profile SET name = ?",
            Bind => [
                \$Param{Name}
            ],
        );
    }

    if ( IsHashRefWithData($Param{Data}) ) {    
        # delete all data
        $Self->{DBObject}->Do(
            SQL   => 'DELETE FROM search_profile_preferences WHERE search_profile_id = ?',
            Bind  => [ 
                \$Param{ID}
            ],
        );

        # store data into preferences table
        foreach my $Key (sort keys %{$Param{Data}}) {

            my @Data;
            my $Type;
            if ( ref $Param{Data}->{$Key} eq 'ARRAY' ) {
                @Data = @{ $Param{Data}->{$Key} };
                $Type = 'ARRAY';
            }
            else {
                @Data = ( $Param{Data}->{$Key} );
                $Type = 'SCALAR';
            }

            foreach my $Value (@Data) {
                return if !$Self->{DBObject}->Do(
                    SQL => "
                        INSERT INTO search_profile_preferences
                        (search_profile_id, preferences_type, preferences_key, preferences_value)
                        VALUES (?, ?, ?, ?)
                        ",
                    Bind => [
                        \$Param{ID}, \$Type, \$Key, \$Value,
                    ],
                );
            }
        }
    }

    if ( IsArrayRefWithData($Param{Categories}) ) {    
        # delete all categories
        $Self->{DBObject}->Do(
            SQL   => 'DELETE FROM search_profile_categories WHERE search_profile_id = ?',
            Bind  => [ 
                \$Param{ID}
            ],
        );

        # store into categories table
        foreach my $Category ( @{$Param{Categories}} ) {

            return if !$Self->{DBObject}->Do(
                SQL => "
                    INSERT INTO search_profile_categories
                    (search_profile_id, category)
                    VALUES (?, ?)
                    ",
                Bind => [
                    \$Param{ID}, \$Category
                ],
            );
        }
    }

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item SearchProfileDelete()

deletes a search profile.

    $SearchProfileObject->SearchProfileDelete(
        ID => 123
    );

=cut

sub SearchProfileDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete search profile data
    return if !$Self->{DBObject}->Do(
        SQL  => "DELETE FROM search_profile_preferences WHERE search_profile_id = ?",
        Bind => [ \$Param{ID} ],
    );

    # delete search profile categories
    return if !$Self->{DBObject}->Do(
        SQL  => "DELETE FROM search_profile_categories WHERE search_profile_id = ?",
        Bind => [ \$Param{ID} ],
    );

    # delete search profile
    return if !$Self->{DBObject}->Do(
        SQL  => "DELETE FROM search_profile WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item SearchProfileList()

returns a hash of all profiles for the given user.

    my %SearchProfiles = $SearchProfileObject->SearchProfileList(
        Base      => 'TicketSearch',
        UserLogin => 'me',
        # KIX4OTRS-capeIT
        Category            => 'CategoryName', # get list depending on category
        WithSubscription    => 1 # get also profiles from other agents
        # EO KIX4OTRS-capeIT
    );

=cut

sub SearchProfileList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create login string
    my $Login = $Param{Base} . '::' . $Param{UserLogin};

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $Login,
    );
    return %{$Cache} if $Cache;

    my %Result;

    # KIX4OTRS-capeIT
    # use category
    if ( defined $Param{Category} && $Param{Category} ) {

        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT name,login,state FROM kix_search_profile WHERE category = ?",
            Bind => [ \$Param{Category} ],
            );

        my @SelectedData;
        my %DataHash;

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {

            if ( $Data[0] =~ m/^(.*?)::(.*?)::(.*?)$/ ) {

                # do not subscribe to own search profiles
                next
                    if (
                    $Param{SubscriptedOnly}
                    && $Data[2] eq 'owner'
                    && $Param{UserLogin} eq $Data[1]
                    );
                next
                    if (
                    $Data[2] eq 'subscriber'
                    && $Param{UserLogin} ne $Data[1]
                    );

                $DataHash{ $Data[0] } = $3;

                next if $Param{UserLogin} ne $Data[1];
                push @SelectedData, $Data[0];
            }
        }

        $Result{Data}         = \%DataHash;
        $Result{SelectedData} = \@SelectedData;

    }
    elsif ( defined $Param{WithSubscription} && $Param{WithSubscription} ) {

        # get search profiles
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT profile_name FROM search_profile WHERE $Self->{Lower}(login) = $Self->{Lower}(?)",
            Bind => [ \$Login ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            $Result{ $Data[0] . '::' . $Param{UserLogin} } = $Data[0];
        }

        # get subscripted search profiles from other agents
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT name FROM kix_search_profile WHERE login = ? AND state = 'subscriber' AND name LIKE '%"
                . $Param{Base} . "%'",
            Bind => [ \$Param{UserLogin} ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            my $Key;
            if ( $Data[0] =~ m/^TicketSearch::(.*?)::(.*?)$/ ) {
                $Key = $2 . '::' . $1;
            }
            my $Subscription = $Self->{LanguageObject}->Translate('Subscribe');
            if ( !defined $Result{$Key} ) {
                $Result{$Key} = "[" . substr( $Subscription, 0, 1 ) . "] " . $2;
            }
        }

    }

    # EO KIX4OTRS-capeIT

    # get search profile list
    # KIX4OTRS-capeIT
    else {

        # get old search profiles
        # EO KIX4OTRS-capeIT
        return if !$Self->{DBObject}->Prepare(
            SQL => "
            SELECT profile_name
            FROM search_profile
            WHERE $Self->{Lower}(login) = $Self->{Lower}(?)
            ",
            Bind => [ \$Login ],
        );

        # KIX4OTRS-capeIT
        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            $Result{ $Data[0] } = $Data[0];
        }

        # get search profiles with category
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT name FROM kix_search_profile WHERE login = ? AND state = 'subscriber' AND name LIKE '%"
                . $Param{Base} . "%'",
            Bind => [ \$Param{UserLogin} ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            my $Key;
            if ( $Data[0] =~ m/^TicketSearch::(.*?)::(.*?)$/ ) {
                $Key = $2 . '::' . $1;
            }
            my $Subscription = $Self->{LanguageObject}->Translate('Subscribe');
            if ( !defined $Result{$Key} ) {
                $Result{$Key} = "[" . substr( $Subscription, 0, 1 ) . "] " . $2;
            }
        }

        # EO KIX4OTRS-capeIT

    }

    return %Result;
}

=item SearchProfileUpdateUserLogin()

changes the UserLogin of SearchProfiles

    my $Result = $SearchProfileObject->SearchProfileUpdateUserLogin(
        UserType     => 'Agent'|'Customer',
        OldUserLogin => 'me',
        NewUserLogin => 'newme',
    );

=cut

sub SearchProfileUpdateUserLogin {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base UserLogin NewUserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get existing profiles
    my %SearchProfiles = $Self->SearchProfileList(
        Base      => $Param{Base},
        UserLogin => $Param{UserLogin},
    );

    # iterate over profiles; create them for new login name and delete old ones
    for my $SearchProfile ( sort keys %SearchProfiles ) {
        my %Search = $Self->SearchProfileGet(
            Base      => $Param{Base},
            Name      => $SearchProfile,
            UserLogin => $Param{UserLogin},
        );

        # add profile for new login (needs to be done per attribute)
        for my $Attribute ( sort keys %Search ) {
            $Self->SearchProfileAdd(
                Base      => $Param{Base},
                Name      => $SearchProfile,
                Key       => $Attribute,
                Value     => $Search{$Attribute},
                UserLogin => $Param{NewUserLogin},
            );
        }

        # delete the old profile
        $Self->SearchProfileDelete(
            Base      => $Param{Base},
            Name      => $SearchProfile,
            UserLogin => $Param{UserLogin},
        );
    }
}


# KIX4OTRS-capeIT

=item SearchProfileCopy()

to copy a search profile item

    $SearchProfileObject->SearchProfileCopy(
        Base      => 'TicketSearch',
        Name      => 'last-search',
        NewName   => 'last-search-123',
        OldLogin  => 123,
        UserLogin => 123,
    );

=cut

sub SearchProfileCopy {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base Name UserLogin)) {
        if ( !defined $Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get source data
    my %SearchProfileData = $Self->SearchProfileGet(
        Base      => $Param{Base},
        Name      => $Param{Name},
        UserLogin => $Param{OldLogin},
    );

    if ( !defined $Param{NewName} || $Param{NewName} eq '' ) {

        # delete search profile with same name if exists
        $Self->SearchProfileDelete(
            Base      => $Param{Base},
            Name      => $Param{Name},
            UserLogin => $Param{UserLogin},
        );
    }
    else {
        $Param{Name} = $Param{NewName};
    }

    # write target
    for my $Item ( keys %SearchProfileData ) {

        $Self->SearchProfileAdd(
            Base      => $Param{Base},
            Name      => $Param{Name},
            Key       => $Item,
            Value     => $SearchProfileData{$Item},
            UserLogin => $Param{UserLogin},
        );
    }

    return 1;
}

=item SearchProfileCategoryAdd()

to add a search profile item

    $SearchProfileObject->SearchProfileCategoryAdd(
        Name      => 'TicketSearch::UserLogin::SearchTemplate',
        Category  => 'CategoryName',
        State     => 'owner', # or subscriber
        UserLogin => 'UserLogin',
    );

=cut

sub SearchProfileCategoryAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name Category UserLogin State)) {
        if ( !defined $Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return
        if !$Self->{DBObject}->Do(
        SQL => 'INSERT INTO kix_search_profile'
            . ' (name,  category, state , login)'
            . ' VALUES (?, ?, ?, ?) ',
        Bind => [
            \$Param{Name},  \$Param{Category},
            \$Param{State}, \$Param{UserLogin},
        ],
        );

    return 1;
}

=item SearchProfileCategoryGet()

returns a hash with information about the shared search profile

    my %SearchProfileData = $SearchProfileObject->SearchProfileCategoryGet(
        Name      => 'last-search',
        UserLogin => 'me',
    );

=cut

sub SearchProfileCategoryGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get searech profile
    return
        if !$Self->{DBObject}->Prepare(
        SQL =>
            "SELECT * FROM kix_search_profile WHERE name = ? AND $Self->{Lower}(login) = $Self->{Lower}(?)",
        Bind => [ \$Param{Name}, \$Param{UserLogin} ],
        );

    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {

        $Result{Category}  = $Data[0];
        $Result{Name}      = $Data[1];
        $Result{State}     = $Data[2];
        $Result{UserLogin} = $Data[3];
    }

    return %Result;
}

=item SearchProfileCategoryDelete()

deletes an profile

    $SearchProfileObject->SearchProfileCategoryDelete(
        Category  => 'TicketSearch',     # optional (category or name must be given)
        Name      => 'last-search',      # optional (category or name must be given)
        UserLogin => 'me',               # optional
        State      => 'owner'            # optional
    );

=cut

sub SearchProfileCategoryDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Category} && !$Param{Name} ) {
        $Self->{LogObject}
            ->Log( Priority => 'error', Message => "Need Category or Name!" );
        return;
    }

    # create SQL string
    my $SQL = "DELETE FROM kix_search_profile WHERE ";

    # create where-clause
    my @SQLExtended = ();
    my $Criterion;

    # UserLogin
    if ( $Param{UserLogin} ) {
        $Criterion =
            $Self->{Lower}
            . "(login) = "
            . $Self->{Lower} . "('"
            . $Param{UserLogin} . "')";
        push @SQLExtended, $Criterion;
    }

    # name, e.g. TicketSearch::UserLogin::SearchProfile
    if ( $Param{Name} ) {
        $Criterion = " name = '" . $Param{Name} . "'";
        push @SQLExtended, $Criterion;
    }

    # category
    if ( $Param{Category} ) {
        $Criterion = " category = '" . $Param{Category} . "'";
        push @SQLExtended, $Criterion;
    }

    # state, e.g. owner / copy
    if ( $Param{State} ) {
        $Criterion = " state = '" . $Param{State} . "'";
        push @SQLExtended, $Criterion;
    }

    my $SQLExt = join( " AND ", @SQLExtended );

    return $Self->{DBObject}->Prepare( SQL => $SQL . $SQLExt );

}

=item SearchProfileCategoryList()

returns a hash of all profiles

    my %SearchProfiles = $SearchProfileObject->SearchProfileCategoryList();

=cut

sub SearchProfileCategoryList {
    my ( $Self, %Param ) = @_;

    # get search profile categorylist
    return
        if !$Self->{DBObject}->Prepare(
        SQL  => "SELECT DISTINCT category FROM kix_search_profile",
        Bind => [],
        );

    # fetch the result
    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[0];
    }

    return %Result;
}

=item SearchProfileAutoSubscribe()

auto-subscribe of a search profile

    my %SearchProfiles = $SearchProfileObject->SearchProfileAutoSubscribe(
        Name        => 'SearchProfileName',
        UserLogin   => 'me'
        UserObject  => $Self->{UserObject}
    );

=cut

sub SearchProfileAutoSubscribe {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserLogin UserObject)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get search profile data
    my %SearchProfileData = $Self->SearchProfileCategoryGet(
        Name      => $Param{Name},
        UserLogin => $Param{UserLogin},
    );

    # get user preference 'auto-subscribe' from all users and check if user selected chosen category
    return
        if !$Self->{DBObject}->Prepare(
        SQL =>
            "SELECT user_id,preferences_value FROM user_preferences WHERE preferences_key = 'SearchProfileAutoSubscribe'",
        Bind => [],
        );

    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my @TmpArray = split( /;/, $Data[1] );
        next if !grep { $_ eq $SearchProfileData{Category} } @TmpArray;
        $Result{ $Data[0] } = 1;
    }

    # auto-subscribe
    $Self->{UserObject} = $Param{UserObject};
    for my $User ( keys %Result ) {
        my %UserData = $Self->{UserObject}->GetUserData( UserID => $User );
        $Self->SearchProfileCategoryAdd(
            Name      => $Param{Name},
            Category  => $SearchProfileData{Category},
            State     => 'subscriber',
            UserLogin => $UserData{UserLogin},
        );
    }
}

=item SearchProfilesByCategory()

returns a hash of all subscribable profiles by category

    my %SearchProfiles = $SearchProfileObject->SearchProfilesByCategory(
        Base            => 'TicketSearch',
        Category        => 'SearchProfileCategoryName',
    );

=cut

sub SearchProfilesByCategory {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Category Base UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get all search profiles for this category
    my %SearchProfiles = $Self->SearchProfileList(
        Base            => 'TicketSearch',
        UserLogin       => $Param{UserLogin},
        Category        => $Param{Category},
        SubscriptedOnly => 1,
    );

    return %SearchProfiles;

}

=item SearchProfilesBasesGet()

returns an array of all possible search profile bases

    my %SearchProfiles = $SearchProfileObject->SearchProfilesBasesGet();

=cut

sub SearchProfilesBasesGet {
    my ( $Self, %Param ) = @_;

    # get search profile categorylist
    return
        if !$Self->{DBObject}->Prepare(
        SQL  => "SELECT DISTINCT login FROM search_profile",
        Bind => [],
        );

    # fetch the result
    my @Result;
    GETDATA:
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Data[0] =~ /(.*?)::(.*)/ ) {
            next GETDATA if grep { $_ eq $1 } @Result;
            push @Result, $1;
        }
    }
    return @Result;
}

# EO KIX4OTRS-capeIT

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
