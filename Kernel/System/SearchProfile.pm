# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SearchProfile;

use strict;
use warnings;

use Kernel::System::VariableCheck (qw(:all));

our @ObjectDependencies = (
    'Cache',
    'DB',
    'Log',
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
    my $SearchProfileObject = $Kernel::OM->Get('SearchProfile');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('DB');

    $Self->{CacheType} = 'SearchProfile';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # KIX4OTRS-capeIT
    $Self->{LanguageObject} = $Kernel::OM->Get('Language');

    # EO KIX4OTRS-capeIT

    return $Self;
}

=item SearchProfileAdd()

to add a search profile item

    $ID = $SearchProfileObject->SearchProfileAdd(
        Type                => 'Ticket',
        Name                => 'last-search',
        UserType            => 'Agent'|'Customer'
        UserLogin           => '...',
        SubscribedProfileID => 123,                 # optional, ID of the subscribed (referenced) search profile
        Data                => {                    # necessary if no subscription
            Key => Value
        },
        Categories          => [                    # optional
            '...'
        ]
    );

=cut

sub SearchProfileAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Name UserLogin UserType)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{SubscribedProfileID} && !IsHashRefWithData($Param{Data}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Data if search profile is no subscription!"
        );
        return;        
    }

    if ( $Param{UserType} !~ /^(Agent|Customer)$/g ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "UserType must be 'Agent' or 'Customer'!"
        );
        return;        
    }

    if ( $Param{SubscribedProfileID} ) {    
        my @SubscribableProfileIDs = $Self->SearchProfileList(
            OnlySubscribable => 1,
        );
        my %SubscribableProfiles = map { $_ => 1 } @SubscribableProfileIDs;

        if ( !$SubscribableProfiles{$Param{SubscribedProfileID}} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't subscribe to the given SubscribableProfileID."
            );
            return;        
        }
    }

    my @ExistingProfiles = $Self->SearchProfileList(
        Type        => $Param{Type},
        Name        => $Param{Name},
        UserType    => $Param{UserType},
        UserLogin   => $Param{UserLogin},
    );

    # add profile to database
    if (@ExistingProfiles) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t add search profile! A profile with same name already exists for this type and user.'
        );
        return;
    }

    return if !$Self->{DBObject}->Do(
        SQL => "
            INSERT INTO search_profile (user_login, user_type, name, type, subscribed_profile_id) VALUES (?, ?, ?, ?, ?)",
        Bind => [
            \$Param{UserLogin}, \$Param{UserType}, \$Param{Name}, \$Param{Type}, \$Param{SubscribedProfileID}
        ],
    );

    # get profile id
    $Self->{DBObject}->Prepare(
        SQL   => 'SELECT id FROM search_profile WHERE user_login = ? AND user_type = ? AND name = ? AND type = ?',
        Bind  => [ 
            \$Param{UserLogin}, \$Param{UserType}, \$Param{Name}, \$Param{Type}
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
        # store into category table
        foreach my $Category ( @{$Param{Categories}} ) {

            return if !$Self->{DBObject}->Do(
                SQL => "
                    INSERT INTO search_profile_category
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
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $SearchProfileID;
}

=item SearchProfileGet()

returns hash with search profile.

    my %SearchProfile = $SearchProfileObject->SearchProfileGet(
        ID                => 123,
        WithData          => 1,         # optional
        WithCategories    => 1,         # optional
        WithSubscriptions => 1,         # optional
    );

=cut

sub SearchProfileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check the cache
    my $CacheKey = 'SearchProfileGet::' 
                 . $Param{ID} . '::' 
                 . ($Param{WithData}||'') . '::' 
                 . ($Param{WithCategories}||'') . '::' 
                 . ($Param{WithSubscriptions}||''); 
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get search profile
    $Self->{DBObject}->Prepare(
        SQL => "SELECT id, type, name, user_login, user_type, subscribed_profile_id FROM search_profile WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %SearchProfile;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $SearchProfile{ID}        = $Row[0];
        $SearchProfile{Type}      = $Row[1];
        $SearchProfile{Name}      = $Row[2];
        $SearchProfile{UserLogin} = $Row[3];
        $SearchProfile{UserType}  = $Row[4];
        $SearchProfile{SubscribedProfileID} = $Row[5];
    }

    # check service
    if ( !$SearchProfile{ID} ) {
        $Kernel::OM->Get('Log')->Log(
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
        $SearchProfile{Data} = \%Data;
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
        $SearchProfile{Categories} = \@Categories;
    }

    if ( $Param{WithSubscriptions} ) {
        # get search profile subscriptions
        return if !$Self->{DBObject}->Prepare(
            SQL  => "SELECT id FROM search_profile WHERE subscribed_profile_id = ?",
            Bind => [ \$Param{ID} ],
        );

        my @Subscriptions;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            push(@Subscriptions, $Row[0])
        }
        $SearchProfile{Subscriptions} = \@Subscriptions;
    }

    $Kernel::OM->Get('Cache')->Set(
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
        Data      => {                  # optional, only allowed if profile is no subscription
            Key => Value
        },
        Categories => [                 # optional, only allowed if profile is no subscription
            '...'
        ]
    );

=cut

sub SearchProfileUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # return if no updateable parameters are given
    return 1 if !$Param{Name} && !IsHashRefWithData($Param{Data}) && !IsArrayRefWithData($Param{Categories});

    my %SearchProfile = $Self->SearchProfileGet(
        ID       => $Param{ID},
    );
    return if !%SearchProfile;

    # update name if necessary
    if ( $SearchProfile{SubscribableProfileID} && ( $Param{Data} || IsArrayRefWithData($Param{Categories}) ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No data or categories allowed, since profile is subscribed.'
        );
        return;
    }

    # update name if necessary
    if ( $Param{Name} && $Param{Name} ne $SearchProfile{Name} ) {

        my @ExistingProfiles = $Self->SearchProfileList(
            Type      => $SearchProfile{Type},
            Name        => $Param{Name},
            UserType    => $SearchProfile{UserType},
            UserLogin   => $SearchProfile{UserLogin},
        );

        # add profile to database
        if (@ExistingProfiles && $ExistingProfiles[0] != $Param{ID}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Can\'t add search profile! Another profile with same name already exists for this type and user.'
            );
            return;
        }
        
        return if !$Self->{DBObject}->Do(
            SQL  => "UPDATE search_profile SET name = ? WHERE id = ?",
            Bind => [
                \$Param{Name}, \$Param{ID}
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
            SQL   => 'DELETE FROM search_profile_category WHERE search_profile_id = ?',
            Bind  => [ 
                \$Param{ID}
            ],
        );

        # store into categories table
        foreach my $Category ( @{$Param{Categories}} ) {

            return if !$Self->{DBObject}->Do(
                SQL => "
                    INSERT INTO search_profile_category
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
    $Kernel::OM->Get('Cache')->CleanUp(
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
            $Kernel::OM->Get('Log')->Log(
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
        SQL  => "DELETE FROM search_profile_category WHERE search_profile_id = ?",
        Bind => [ \$Param{ID} ],
    );

    # delete search profile
    return if !$Self->{DBObject}->Do(
        SQL  => "DELETE FROM search_profile WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item SearchProfileList()

returns a list of search profile IDs depending on the given parameters

    my $ProfileList = $SearchProfileObject->SearchProfileList(
        Type                => 'TicketSearch',      # optional
        Name                => '...',               # optional
        UserLogin           => 'me',                # optional
        UserType            => 'Agent'|'Customer',  # optional
        SubscribedProfileID => 123                  # optional
        Category            => 'CategoryName',      # optional
        OnlySubscribable    => 0|1                  # optional
    );

=cut

sub SearchProfileList {
    my ( $Self, %Param ) = @_;
    my @BindVars;
    my @SQLWhere;

    my $CacheKey = 'SearchProfileList::' 
                 . ($Param{Type}||'') . '::' 
                 . ($Param{Name}||'') . '::' 
                 . ($Param{UserLogin}||'') . '::' 
                 . ($Param{UserType}||'') . '::' 
                 . ($Param{SubscribedProfileID}||'') . '::' 
                 . ($Param{Category}||'') . '::' 
                 . ($Param{OnlySubscribable}||'');
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    if ( $Param{Type} ) {
        push(@SQLWhere, 'type = ?');
        push(@BindVars, \$Param{Type});
    }

    if ( $Param{Name} ) {
        push(@SQLWhere, 'name = ?');
        push(@BindVars, \$Param{Name});
    }

    if ( $Param{UserLogin} ) {
        push(@SQLWhere, 'user_login = ?');
        push(@BindVars, \$Param{UserLogin});
    }

    if ( $Param{UserType} ) {
        push(@SQLWhere, 'user_type = ?');
        push(@BindVars, \$Param{UserType});
    }

    if ( $Param{SubscribedProfileID} ) {
        push(@SQLWhere, 'subscribed_profile_id = ?');
        push(@BindVars, \$Param{SubscribedProfileID});
    }

    if ( $Param{Category} ) {
        push(@SQLWhere, 'id in (SELECT search_profile_id FROM search_profile_category WHERE category = ?)');
        push(@BindVars, \$Param{Category});
    }

    if ( $Param{OnlySubscribable} ) {
        push(@SQLWhere, 'id in (SELECT search_profile_id FROM search_profile_category)');
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $SQL = 'SELECT id FROM search_profile';
    if ( @SQLWhere ) {
        $SQL .= ' WHERE '.join(' AND ', @SQLWhere);
    };

    # get search profiles
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@BindVars
    );

    # fetch results
    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item SearchProfileUpdateUserLogin()

changes the UserLogin of all relevant SearchProfiles

    my $Result = $SearchProfileObject->SearchProfileUpdateUserLogin(
        UserType     => 'Agent'|'Customer',
        OldUserLogin => 'me',
        NewUserLogin => 'newme',
    );

=cut

sub SearchProfileUpdateUserLogin {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserType OldUserLogin NewUserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get existing profiles
    my @SearchProfileIDs = $Self->SearchProfileList(
        UserType  => $Param{UserType},
        UserLogin => $Param{OldUserLogin},
    );

    # iterate over profiles; create them for new login name and delete old ones
    foreach my $SearchProfileID ( @SearchProfileIDs ) {
        return if !$Self->{DBObject}->Do(
            SQL  => "UPDATE search_profile SET user_login = ? WHERE id = ?",
            Bind => [
                \$Param{NewUserLogin}, \$SearchProfileID
            ],
        );
    }

    return 1;
}

=item SearchProfileCategoryList()

returns a hash of all profiles

    my %SearchProfileCategoryList = $SearchProfileObject->SearchProfileCategoryList();

=cut

sub SearchProfileCategoryList {
    my ( $Self, %Param ) = @_;

    # get search profile categorylist
    return if !$Self->{DBObject}->Prepare(
        SQL  => "SELECT DISTINCT category FROM search_profile_category",
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
            $Kernel::OM->Get('Log')
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

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
