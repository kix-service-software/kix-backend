# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::User;

use strict;
use warnings;

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;
use Data::Dumper;

use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::CheckItem',
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::SearchProfile',
    'Kernel::System::Time',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::User - user lib

=head1 SYNOPSIS

All user functions. E. g. to add and updated user and other functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get user table
    $Self->{UserTable}       = $ConfigObject->Get('DatabaseUserTable')       || 'users';
    $Self->{UserTableUserID} = $ConfigObject->Get('DatabaseUserTableUserID') || 'id';
    $Self->{UserTableUserPW} = $ConfigObject->Get('DatabaseUserTableUserPW') || 'pw';
    $Self->{UserTableUser}   = $ConfigObject->Get('DatabaseUserTableUser')   || 'login';

    $Self->{CacheType} = 'User';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=item GetUserData()

get user data (UserLogin, UserFirstname, UserLastname, UserEmail, ...)

    my %User = $UserObject->GetUserData(
        UserID => 123,
    );

    or

    my %User = $UserObject->GetUserData(
        User          => 'franz',
        Valid         => 1,       # not required -> 0|1 (default 0)
                                  # returns only data if user is valid
        NoOutOfOffice => 1,       # not required -> 0|1 (default 0)
                                  # returns data without out of office infos
        NoPreferences => 1,       # not required -> 0|1 (default 0)
                                  # returns data without preferences
    );

=cut

sub GetUserData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!',
        );
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $ConfigObject->Get('FirstnameLastnameOrder') || 0;

    # check if result is cached
    if ( $Param{Valid} ) {
        $Param{Valid} = 1;
    }
    else {
        $Param{Valid} = 0;
    }
    if ( $Param{NoOutOfOffice} ) {
        $Param{NoOutOfOffice} = 1;
    }
    else {
        $Param{NoOutOfOffice} = 0;
    }
    if ( $Param{NoPreferences} ) {
        $Param{NoPreferences} = 1;
    }
    else {
        $Param{NoPreferences} = 0;
    }

    my $CacheKey;
    if ( $Param{User} ) {
        $CacheKey = join '::', 'GetUserData', 'User',
            $Param{User},
            $Param{Valid},
            $FirstnameLastNameOrder,
            $Param{NoOutOfOffice},
            $Param{NoPreferences};
    }
    else {
        $CacheKey = join '::', 'GetUserData', 'UserID',
            $Param{UserID},
            $Param{Valid},
            $FirstnameLastNameOrder,
            $Param{NoOutOfOffice},
            $Param{NoPreferences};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get initial data
    my @Bind;
    my $SQL = "SELECT $Self->{UserTableUserID}, $Self->{UserTableUser}, "
        . " title, first_name, last_name, $Self->{UserTableUserPW}, email, phone, mobile, "
        . " comments, valid_id, create_time, change_time, create_by, change_by FROM $Self->{UserTable} WHERE ";

    if ( $Param{User} ) {
        my $User = lc $Param{User};
        $SQL .= " $Self->{Lower}($Self->{UserTableUser}) = ?";
        push @Bind, \$User;
    }
    else {
        $SQL .= " $Self->{UserTableUserID} = ?";
        push @Bind, \$Param{UserID};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{UserID}        = $Row[0];
        $Data{UserLogin}     = $Row[1];
        $Data{UserTitle}     = $Row[2];
        $Data{UserFirstname} = $Row[3];
        $Data{UserLastname}  = $Row[4];
        $Data{UserPw}        = $Row[5];
        $Data{UserEmail}     = $Row[6];
        $Data{UserPhone}     = $Row[7];
        $Data{UserMobile}    = $Row[8];
        $Data{UserComment}   = $Row[9];
        $Data{ValidID}       = $Row[10];
        $Data{CreateTime}    = $Row[11];
        $Data{ChangeTime}    = $Row[12];
        $Data{CreateBy}      = $Row[13];
        $Data{ChangeBy}      = $Row[14];
    }

    # check data
    if ( !$Data{UserID} ) {
        if ( $Param{User} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Panic! No UserData for user: '$Param{User}'!!!",
            );
            return;
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Panic! No UserData for user id: '$Param{UserID}'!!!",
            );
            return;
        }
    }

    # Store CacheTTL locally so that we can reduce it for users that are out of office.
    my $CacheTTL = $Self->{CacheTTL};

    # check valid, return if there is locked for valid users
    if ( $Param{Valid} ) {

        my $Hit = 0;

        for ( $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet() ) {
            if ( $_ eq $Data{ValidID} ) {
                $Hit = 1;
            }
        }

        if ( !$Hit ) {

            # set cache
            $Kernel::OM->Get('Kernel::System::Cache')->Set(
                Type  => $Self->{CacheType},
                TTL   => $CacheTTL,
                Key   => $CacheKey,
                Value => {},
            );
            return;
        }
    }

    # generate the full name and save it in the hash
    my $UserFullname = $Self->_UserFullname(
        %Data,
        NameOrder => $FirstnameLastNameOrder,
    );

    # save the generated fullname in the hash.
    $Data{UserFullname} = $UserFullname;

    # get preferences
    my %Preferences = $Self->GetPreferences( UserID => $Data{UserID} );

    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # out of office check
    if ( !$Param{NoOutOfOffice} ) {
        if ( $Preferences{OutOfOffice} ) {
            my $Time = $TimeObject->SystemTime();
            my $Start
                = "$Preferences{OutOfOfficeStartYear}-$Preferences{OutOfOfficeStartMonth}-$Preferences{OutOfOfficeStartDay} 00:00:00";
            my $TimeStart = $TimeObject->TimeStamp2SystemTime(
                String => $Start,
            );
            my $End
                = "$Preferences{OutOfOfficeEndYear}-$Preferences{OutOfOfficeEndMonth}-$Preferences{OutOfOfficeEndDay} 23:59:59";
            my $TimeEnd = $TimeObject->TimeStamp2SystemTime(
                String => $End,
            );
            if ( $TimeStart < $Time && $TimeEnd > $Time ) {
                my $OutOfOfficeMessageTemplate =
                    $ConfigObject->Get('OutOfOfficeMessageTemplate') || '*** out of office until %s (%s d left) ***';
                my $TillDate = sprintf(
                    '%04d-%02d-%02d',
                    $Preferences{OutOfOfficeEndYear},
                    $Preferences{OutOfOfficeEndMonth},
                    $Preferences{OutOfOfficeEndDay}
                );
                my $Till = int( ( $TimeEnd - $Time ) / 60 / 60 / 24 );
                $Data{OutOfOfficeMessage} = sprintf( $OutOfOfficeMessageTemplate, $TillDate, $Till );
            }

            # Reduce CacheTTL to one hour for users that are out of office to make sure the cache expires timely
            #   even if there is no update action.
            $CacheTTL = 60 * 60 * 1;
        }
    }

    if ( !$Param{NoPreferences} ) {

        # add last login timestamp
        if ( $Preferences{UserLastLogin} ) {
            $Preferences{UserLastLoginTimestamp} = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $Preferences{UserLastLogin},
            );
        }

        # add preferences defaults
        my $Config = $ConfigObject->Get('PreferencesGroups');
        if ( $Config && ref $Config eq 'HASH' ) {

            KEY:
            for my $Key ( sort keys %{$Config} ) {

                next KEY if !defined $Config->{$Key}->{DataSelected};

                # check if data is defined
                next KEY if defined $Preferences{ $Config->{$Key}->{PrefKey} };

                # set default data
                $Preferences{ $Config->{$Key}->{PrefKey} } = $Config->{$Key}->{DataSelected};
            }
        }

        # add preferences to data hash
        $Data{Preferences} = \%Preferences;
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $CacheTTL,
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item UserAdd()

to add new users

    my $UserID = $UserObject->UserAdd(
        UserFirstname => 'Huber',
        UserLastname  => 'Manfred',
        UserLogin     => 'mhuber',
        UserPw        => 'some-pass',           # optional
        UserEmail     => 'email@example.com',
        UserPhone     => '1234567890',          # optional
        UserMobile    => '1234567890',          # optional
        UserComment   => 'some comment',        # optional
        ValidID       => 1,
        ChangeUserID  => 123,
    );

=cut

sub UserAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserFirstname UserLastname UserLogin UserEmail ValidID ChangeUserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check if a user with this login (username) already exits
    if ( $Self->UserLoginExistsCheck( UserLogin => $Param{UserLogin} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A user with username '$Param{UserLogin}' already exists!"
        );
        return;
    }

    # check email address
    if (
        $Param{UserEmail}
        && !$Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Param{UserEmail} )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $Kernel::OM->Get('Kernel::System::CheckItem')->CheckError() . ")!",
        );
        return;
    }

    # check password
    if ( !$Param{UserPw} ) {
        $Param{UserPw} = $Self->GenerateRandomPassword();
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # Don't store the user's password in plaintext initially. It will be stored in a
    #   hashed version later with SetPassword().
    my $RandomPassword = $Self->GenerateRandomPassword();

    # sql
    return if !$DBObject->Do(
        SQL => "INSERT INTO $Self->{UserTable} "
            . "(title, first_name, last_name, email, phone, mobile, "
            . " $Self->{UserTableUser}, $Self->{UserTableUserPW}, "
            . " comments, valid_id, create_time, create_by, change_time, change_by)"
            . " VALUES "
            . " (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{UserTitle}, \$Param{UserFirstname}, \$Param{UserLastname},
            \$Param{UserEmail}, \$Param{UserPhone}, \$Param{UserMobile}, 
            \$Param{UserLogin}, \$RandomPassword, \$Param{UserComment}, \$Param{ValidID},
            \$Param{ChangeUserID}, \$Param{ChangeUserID},
        ],
    );

    # get new user id
    my $UserLogin = lc $Param{UserLogin};
    return if !$DBObject->Prepare(
        SQL => "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} "
            . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
        Bind  => [ \$UserLogin ],
        Limit => 1,
    );

    # fetch the result
    my $UserID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $UserID = $Row[0];
    }

    # check if user exists
    if ( !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Unable to create User: '$Param{UserLogin}' ($Param{ChangeUserID})!",
        );
        return;
    }

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message =>
            "User: '$Param{UserLogin}' ID: '$UserID' created successfully ($Param{ChangeUserID})!",
    );

    # set password
    $Self->SetPassword(
        UserLogin => $Param{UserLogin},
        PW        => $Param{UserPw}
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return $UserID;
}

=item UserUpdate()

to update users

    $UserObject->UserUpdate(
        UserID        => 4321,
        UserFirstname => 'Huber',
        UserLastname  => 'Manfred',
        UserLogin     => 'mhuber',
        UserPw        => 'some-pass',           # optional
        UserEmail     => 'email@example.com',
        UserPhone     => '1234567890',          # optional
        UserMobile    => '1234567890',          # optional
        UserComment   => 'some comment',        # optional
        ValidID       => 1,
        ChangeUserID  => 123,
    );

=cut

sub UserUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID UserFirstname UserLastname UserLogin ValidID UserID ChangeUserID)) {

        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # store old user login for later use
    my $OldUserLogin = $Self->UserLookup(
        UserID => $Param{UserID},
    );

    # check if a user with this login (username) already exists
    if (
        $Self->UserLoginExistsCheck(
            UserLogin => $Param{UserLogin},
            UserID    => $Param{UserID}
        )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A user with username '$Param{UserLogin}' already exists!"
        );
        return;
    }

    # check email address
    if (
        $Param{UserEmail}
        && !$Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Param{UserEmail} )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $Kernel::OM->Get('Kernel::System::CheckItem')->CheckError() . ")!",
        );
        return;
    }

    # update db
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE $Self->{UserTable} SET title = ?, first_name = ?, last_name = ?, email = ?, phone = ?, mobile = ?, "
            . " $Self->{UserTableUser} = ?, comments = ?, valid_id = ?, "
            . " change_time = current_timestamp, change_by = ? "
            . " WHERE $Self->{UserTableUserID} = ?",
        Bind => [
            \$Param{UserTitle}, \$Param{UserFirstname}, \$Param{UserLastname},
            \$Param{UserEmail}, \$Param{UserPhone}, \$Param{UserMobile},
            \$Param{UserLogin}, \$Param{UserComment}, \$Param{ValidID}, 
            \$Param{ChangeUserID}, \$Param{UserID},
        ],
    );

    # check pw
    if ( $Param{UserPw} ) {
        $Self->SetPassword(
            UserLogin => $Param{UserLogin},
            PW        => $Param{UserPw}
        );
    }

    # update search profiles if the UserLogin changed
    if ( lc $OldUserLogin ne lc $Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileUpdateUserLogin(
            Base         => 'TicketSearch',
            UserLogin    => $OldUserLogin,
            NewUserLogin => $Param{UserLogin},
        );
    }

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

=item UserSearch()

to search users

    my %List = $UserObject->UserSearch(
        Search => '*some*', # also 'hans+huber' possible
        Valid  => 1, # not required
    );

    my %List = $UserObject->UserSearch(
        UserLogin => '*some*',
        Limit     => 50,
        Valid     => 1, # not required
    );

    my %List = $UserObject->UserSearch(
        PostMasterSearch => 'email@example.com',
        Valid            => 1, # not required
    );

Returns hash of UserID, Login pairs:

    my %List = (
        1 => 'root@locahost',
        4 => 'admin',
        9 => 'joe',
    );

For PostMasterSearch, it returns hash of UserID, Email pairs:

    my %List = (
        4 => 'john@example.com',
        9 => 'joe@example.com',
    );

=cut

sub UserSearch {
    my ( $Self, %Param ) = @_;

    my %Users;
    my $Valid = $Param{Valid} // 1;

    # check needed stuff
    if ( !$Param{Search} && !$Param{UserLogin} && !$Param{PostMasterSearch} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Search, UserLogin or PostMasterSearch!',
        );
        return;
    }

    my $CacheKey = 'UserSearch::'.($Param{Search} || '').'::'.($Param{PostMasterSearch} || '').'::'.($Param{Userlogin} || '').'::'.($Param{Valid} || '').'::'.($Param{Limit} || '');

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # build SQL string
    my $SQL = "SELECT $Self->{UserTableUserID}, login FROM $Self->{UserTable} WHERE ";
    my @Bind;

    if ( $Param{Search} ) {

        my %QueryCondition = $DBObject->QueryCondition(
            Key      => [qw(login first_name last_name email phone mobile)],
            Value    => $Param{Search},
            BindMode => 1,
        );
        $SQL .= $QueryCondition{SQL} . ' ';
        push @Bind, @{ $QueryCondition{Values} };
    }
    elsif ( $Param{PostMasterSearch} ) {

        return if !$DBObject->Prepare(
            SQL   => $SQL. ' email = ?',
            Bind  => [ \$Param{PostMasterSearch} ],
        );

        # fetch the result
        my %UserList;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $UserList{ $Row[0] } = $Row[1];
        }

        foreach my $UserID ( sort keys %UserList ) {
            my %User = $Self->GetUserData(
                UserID => $UserID,
                Valid  => $Param{Valid},
            );
            if (%User) {
                $UserList{$UserID} = $User{UserEmail};
                return %UserList;
            }
        }

        return;
    }
    elsif ( $Param{UserLogin} ) {

        $SQL .= " $Self->{Lower}($Self->{UserTableUser}) LIKE ? $LikeEscapeString";
        $Param{UserLogin} =~ s/\*/%/g;
        $Param{UserLogin} = $DBObject->Quote( $Param{UserLogin}, 'Like' );
        push @Bind, \$Param{UserLogin};
    }

    # add valid option
    if ($Valid) {
        $SQL .= "AND valid_id IN (" . join( ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet() ) . ")";
    }

    # get data
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Self->{UserSearchListLimit} || $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Users{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Users,
    );

    return %Users;
}

=item SetPassword()

to set users passwords

    $UserObject->SetPassword(
        UserLogin => 'some-login',
        PW        => 'some-new-password'
    );

=cut

sub SetPassword {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!'
        );
        return;
    }

    # get old user data
    my %User = $Self->GetUserData( User => $Param{UserLogin} );
    if ( !$User{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No such User!',
        );
        return;
    }

    my $Pw = $Param{PW} || '';
    my $CryptedPw = '';

    # get crypt type
    my $CryptType = $Kernel::OM->Get('Kernel::Config')->Get('AuthModule::DB::CryptType') || 'sha2';

    # crypt plain (no crypt at all)
    if ( $CryptType eq 'plain' ) {
        $CryptedPw = $Pw;
    }

    # crypt with UNIX crypt
    elsif ( $CryptType eq 'crypt' ) {

        # encode output, needed by crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with md5
    elsif ( $CryptType eq 'md5' || !$CryptType ) {

        # encode output, needed by unix_md5_crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = unix_md5_crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with md5 (compatible with Apache's .htpasswd files)
    elsif ( $CryptType eq 'apr1' ) {

        # encode output, needed by unix_md5_crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = apache_md5_crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with sha1
    elsif ( $CryptType eq 'sha1' ) {

        my $SHAObject = Digest::SHA->new('sha1');

        # encode output, needed by sha1_hex() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # bcrypt
    elsif ( $CryptType eq 'bcrypt' ) {

        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require('Crypt::Eksblowfish::Bcrypt') ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "User: '$User{UserLogin}' tried to store password with bcrypt but 'Crypt::Eksblowfish::Bcrypt' is not installed!",
            );
            return;
        }

        my $Cost = 9;
        my $Salt = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString( Length => 16 );

        # remove UTF8 flag, required by Crypt::Eksblowfish::Bcrypt
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        # calculate password hash
        my $Octets = Crypt::Eksblowfish::Bcrypt::bcrypt_hash(
            {
                key_nul => 1,
                cost    => 9,
                salt    => $Salt,
            },
            $Pw
        );

        # We will store cost and salt in the password string so that it can be decoded
        #   in future even if we use a higher cost by default.
        $CryptedPw = "BCRYPT:$Cost:$Salt:" . Crypt::Eksblowfish::Bcrypt::en_base64($Octets);
    }

    # crypt with sha256 as fallback
    else {

        my $SHAObject = Digest::SHA->new('sha256');

        # encode output, needed by sha256_hex() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # update db
    my $UserLogin = lc $Param{UserLogin};
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE $Self->{UserTable} SET $Self->{UserTableUserPW} = ? "
            . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
        Bind => [ \$CryptedPw, \$UserLogin ],
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "User: '$Param{UserLogin}' changed password successfully!",
    );

    return 1;
}

=item UserLookup()

user login or id lookup

    my $UserLogin = $UserObject->UserLookup(
        UserID => 1,
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $UserID = $UserObject->UserLookup(
        UserLogin => 'some_user_login',
        Silent    => 1, # optional, don't generate log entry if user was not found
    );

=cut

sub UserLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin or UserID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Param{UserLogin} ) {

        # check cache
        my $CacheKey = 'UserLookup::ID::' . $Param{UserLogin};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        my $UserLogin = lc $Param{UserLogin};

        return if !$DBObject->Prepare(
            SQL => "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} "
                . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
            Bind  => [ \$UserLogin ],
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        if ( !$ID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No UserID found for '$Param{UserLogin}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $ID,
        );

        return $ID;
    }

    else {

        # check cache
        my $CacheKey = 'UserLookup::Login::' . $Param{UserID};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        return if !$DBObject->Prepare(
            SQL => "SELECT $Self->{UserTableUser} FROM $Self->{UserTable} "
                . " WHERE $Self->{UserTableUserID} = ?",
            Bind  => [ \$Param{UserID} ],
            Limit => 1,
        );

        # fetch the result
        my $Login;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Login = $Row[0];
        }

        if ( !$Login ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No UserLogin found for '$Param{UserID}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $Login,
        );

        return $Login;
    }
}

=item UserName()

get user name

    my $Name = $UserObject->UserName(
        UserLogin => 'some-login',
    );

    or

    my $Name = $UserObject->UserName(
        UserID => 123,
    );

=cut

sub UserName {
    my ( $Self, %Param ) = @_;

    my %User = $Self->GetUserData(%Param);

    return if !%User;
    return $User{UserFullname};
}

=item UserList()

return a hash with all users

    my %List = $UserObject->UserList(
        Type          => 'Short', # Short|Long, default Short
        Valid         => 1,       # default 1
        NoOutOfOffice => 1,       # (optional) default 0
    );

=cut

sub UserList {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || 'Short';

    # set valid option
    my $Valid = $Param{Valid} // 1;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $ConfigObject->Get('FirstnameLastnameOrder') || 0;
    my $NoOutOfOffice = $Param{NoOutOfOffice} || 0;

    # check cache
    my $CacheKey = join '::', 'UserList', $Type, $Valid, $FirstnameLastNameOrder, $NoOutOfOffice;
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SelectStr;
    if ( $Type eq 'Short' ) {
        $SelectStr = "$Self->{UserTableUserID}, "
            . " $Self->{UserTableUser}";
    }
    else {
        $SelectStr = "$Self->{UserTableUserID}, "
            . " last_name, first_name, "
            . " $Self->{UserTableUser}";
    }

    my $SQL = "SELECT $SelectStr FROM $Self->{UserTable}";

    # sql query
    if ($Valid) {
        $SQL
            .= " WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    my %UsersRaw;
    my %Users;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $UsersRaw{ $Row[0] } = \@Row;
    }

    if ( $Type eq 'Short' ) {
        for my $CurrentUserID ( sort keys %UsersRaw ) {
            $Users{$CurrentUserID} = $UsersRaw{$CurrentUserID}->[1];
        }
    }
    else {
        for my $CurrentUserID ( sort keys %UsersRaw ) {
            my @Data         = @{ $UsersRaw{$CurrentUserID} };
            my $UserFullname = $Self->_UserFullname(
                UserFirstname => $Data[2],
                UserLastname  => $Data[1],
                UserLogin     => $Data[3],
                NameOrder     => $FirstnameLastNameOrder,
            );

            $Users{$CurrentUserID} = $UserFullname;
        }
    }

    # check vacation option
    if ( !$NoOutOfOffice ) {

        USERID:
        for my $UserID ( sort keys %Users ) {
            next USERID if !$UserID;

            my %User = $Self->GetUserData(
                UserID => $UserID,
            );
            if ( $User{Preferences}->{OutOfOfficeMessage} ) {
                $Users{$UserID} .= ' ' . $User{Preferences}->{OutOfOfficeMessage};
            }
        }
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Users,
    );

    return %Users;
}

=item UserLoginExistsCheck()

return 1 if another user with this login (username) already exists

    $Exist = $UserObject->UserLoginExistsCheck(
        UserLogin => 'Some::UserLogin',
        UserID => 1, # optional
    );

=cut

sub UserLoginExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL =>
            "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} WHERE $Self->{UserTableUser} = ?",
        Bind => [ \$Param{UserLogin} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{UserID} || $Param{UserID} ne $Row[0] ) {
            $Flag = 1;
        }
    }
    if ($Flag) {
        return 1;
    }
    return 0;
}

=item PermissionList()

return a list of all permission of a given user

    my %List = $UserObject->PermissionList(
        UserID => 123
        RoleID => 456,                           # optional, restrict result to this role
        Types  => [ 'Resource', 'Object' ]       # optional
    );

=cut

sub PermissionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'PermissionList::'.$Param{UserID}.'::'.$Param{RoleID}.'::'.(IsArrayRefWithData($Param{Types}) ? join('::', @{$Param{Types}}) : '');
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get all permissions from every valid role the user is assigned to
    my @Bind;
    my $SQL = 'SELECT id FROM role_permission WHERE role_id IN (SELECT role_id FROM role_user WHERE user_id = ? AND role_id IN (SELECT id FROM roles WHERE valid_id = 1)';
    push(@Bind, \$Param{UserID});
    if ( $Param{RoleID} ) {
        $SQL .= ' AND role_id = ?';
        push(@Bind, \$Param{RoleID});
    }

    # filter specific permission types
    if ( IsArrayRefWithData($Param{Types}) ) {
        my %TypesMap = map { $_ => 1 } @{$Param{Types}};
        my %PermissionTypeList = $Kernel::OM->Get('Kernel::System::Role')->PermissionTypeList();
        my @PermissionTypeIDs;
        foreach my $ID ( sort keys %PermissionTypeList ) {
            next if !$TypesMap{$PermissionTypeList{$ID}};
            push(@PermissionTypeIDs, $ID);
        }
        if ( @PermissionTypeIDs ) {
            $SQL .= ' AND type_id IN (' . join(',', sort @PermissionTypeIDs) . ')';
        }
    }

    # close sub-query
    $SQL .= ')';

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( 
        SQL  => $SQL,
        Bind => \@Bind
    );

    # fetch the result
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = $Row[1];
    }

    # resolve permissions for IDs
    foreach my $ID ( keys %Result ) {
        my %Permission = $Kernel::OM->Get('Kernel::System::Role')->PermissionGet(
            ID => $ID
        );
        $Result{$ID} = \%Permission;
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    );

    return %Result;
}

=item RoleList()

return a list of all roles of a given user

    my @RoleIDs = $UserObject->RoleList(
        UserID => 123
    );

=cut

sub RoleList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'RoleList::'.$Param{UserID};
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( 
        SQL  => 'SELECT role_id FROM role_user WHERE user_id = ?',
        Bind => [
            \$Param{UserID}
        ]
    );

    # fetch the result
    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item CheckPermission()

returns true if the requested permission is granted

    my ($Granted, $ResultingPermission) = $UserObject->CheckPermission(
        UserID              => 123,
        Types               => [ 'Resource', 'Object' ]
        Target              => '/tickets',
        RequestedPermission => 'READ'
    );

=cut

sub CheckPermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(UserID Target RequestedPermission) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # UserID 1 has God Mode ;)
    return (1, Kernel::System::Role::Permission->PERMISSION_CRUD) if (!$Kernel::OM->Get('Kernel::Config')->Get('SecureMode') && $Param{UserID} == 1);

    $Self->_PermissionDebug("checking $Param{RequestedPermission} permission for target $Param{Target}");

    # get list of all roles to resolve names
    my %RoleList = $Kernel::OM->Get('Kernel::System::Role')->RoleList();

    # get all roles the user is assigned to
    my @UserRoleList = $Self->RoleList(
        UserID => $Param{UserID}
    );
    
    $Self->_PermissionDebug("roles assigned to UserID $Param{UserID}: " . join(', ', map { "\"$RoleList{$_}\" (ID $_)" } sort @UserRoleList));

    # check the permission for each target level (from top to bottom) and role
    my $ResultingPermission;
    my $Target;
    foreach my $TargetPart ( split(/\//, $Param{Target}) ) {
        next if !$TargetPart;

        $Target .= "/$TargetPart";

        my $TargetPermission;
        foreach my $RoleID ( sort @UserRoleList ) {
            my ($RoleGranted, $RolePermission) = $Self->_CheckPermissionForRole(
                %Param,
                Target => $Target,
                RoleID => $RoleID,
            );

            # if no permissions have been found, go to the next role
            next if !$RolePermission;

            # init the value
            if ( !defined $TargetPermission ) {
                $TargetPermission = 0;
            }

            # combine permissions
            $TargetPermission |= ($RolePermission || 0);
        }

        # if we don't have a target permission don't try use it
        next if !defined $TargetPermission;

        # combine permissions
        if ( defined $ResultingPermission ) {
            $ResultingPermission &= ($TargetPermission || 0);
        }
        else {
            $ResultingPermission = ($TargetPermission || 0);
        }

        my $ResultingPermissionShort = $Kernel::OM->Get('Kernel::System::Role')->GetReadablePermissionValue(
            Value  => $ResultingPermission,
            Format => 'Short'
        );

        $Self->_PermissionDebug("resulting permission on target $Target: $ResultingPermissionShort");
    }

    # check if we have a DENY 
    return 0 if ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{DENY}) == Kernel::System::Role::Permission->PERMISSION->{DENY};

    my $Granted = ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{$Param{RequestedPermission}}) == Kernel::System::Role::Permission->PERMISSION->{$Param{RequestedPermission}};

    return ( $Granted, $ResultingPermission);
}

=item CheckPermissionForRole()

returns true if the requested permission is granted for a given role

    my ($Granted, $ResultingPermission) = $UserObject->CheckPermissionForRole(
        UserID              => 123,
        RoleID              => 456,
        Types               => [ 'Resource', 'Object' ]
        Target              => '/tickets',
        RequestedPermission => 'READ'
    );

=cut

sub _CheckPermissionForRole {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(UserID RoleID Target RequestedPermission) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # UserID 1 has God Mode ;)
    return (1, Kernel::System::Role::Permission->PERMISSION_CRUD)  if (!$Kernel::OM->Get('Kernel::Config')->Get('SecureMode') && $Param{UserID} == 1);

    $Self->_PermissionDebug("checking $Param{RequestedPermission} permission for role $Param{RoleID} on target $Param{Target}");

    my %PermissionList = $Self->PermissionList(
        UserID => $Param{UserID},
        RoleID => $Param{RoleID},
        Types  => $Param{Types},
    );

    my $Result = 0;
    my %RelevantPermissions;
    my %SpecificPermissions;
    foreach my $ID ( sort keys %PermissionList ) {
        my $Permission = $PermissionList{$ID};

        # prepare target
        my $Target = $Permission->{Target};
        $Target =~ s/\//\\\//g;
        $Target =~ s/\*/(\\w|\\d)+?/g;

        # check if permission target matches the target to be checked (check whole resources)
        next if $Param{Target} !~ /^$Target$/;

        my %PermissionType = $Kernel::OM->Get('Kernel::System::Role')->PermissionTypeGet(
            ID => $Permission->{TypeID}
        );

        $RelevantPermissions{$PermissionType{Name}}->{$ID} = $Permission;
    }

    $Self->_PermissionDebug("relevant permissions for role $Param{RoleID} on target $Param{Target}: ".Dumper(\%RelevantPermissions));

    # return if no relevant permissions exist
    if ( !IsHashRefWithData(\%RelevantPermissions) ) {
        my $ResultingPermissionShort = $Kernel::OM->Get('Kernel::System::Role')->GetReadablePermissionValue(
            Value  => 0,
            Format => 'Short'
        );
        $Self->_PermissionDebug("no relevant permissions found, returning");

        return 0;
    }
    
    # sum up all the relevant permissions
    my $ResultingPermission = 0;
    TYPE_RELEVANT:
    foreach my $Type ( qw(Resource Object) ) {
        PERMISSION_RELEVANT:
        foreach my $ID ( sort { length($RelevantPermissions{$Type}->{$a}->{Target}) <=> length($RelevantPermissions{$Type}->{$b}->{Target}) } keys %{$RelevantPermissions{$Type}} ) {            
            my $Permission = $RelevantPermissions{$Type}->{$ID};
            $ResultingPermission |= $Permission->{Value};
            if ( ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{DENY}) == Kernel::System::Role::Permission->PERMISSION->{DENY} ) {
                $Self->_PermissionDebug("DENY in permission ID $Permission->{ID} for role $Param{RoleID} on target \"$Permission->{Target}\"" . ($Permission->{Comment} ? "(Comment: $Permission->{Comment})" : '') );
                last TYPE_RELEVANT;
            }
        }
    }

    # check if we have a DENY already
    return (0, Kernel::System::Role::Permission->PERMISSION->{NONE}) if ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{DENY}) == Kernel::System::Role::Permission->PERMISSION->{DENY};

    my $ResultingPermissionShort = $Kernel::OM->Get('Kernel::System::Role')->GetReadablePermissionValue(
        Value  => $ResultingPermission,
        Format => 'Short'
    );

    $Self->_PermissionDebug("resulting permissions for role $Param{RoleID} on target $Param{Target}: $ResultingPermissionShort");

    # check if we have a DENY 
    return 0 if ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{DENY}) == Kernel::System::Role::Permission->PERMISSION->{DENY};

    my $Granted = ($ResultingPermission & Kernel::System::Role::Permission->PERMISSION->{$Param{RequestedPermission}}) == Kernel::System::Role::Permission->PERMISSION->{$Param{RequestedPermission}};

    return ( $Granted, $ResultingPermission);
}

=item GenerateRandomPassword()

generate a random password

    my $Password = $UserObject->GenerateRandomPassword();

    or

    my $Password = $UserObject->GenerateRandomPassword(
        Size => 16,
    );

=cut

sub GenerateRandomPassword {
    my ( $Self, %Param ) = @_;

    # generated passwords are eight characters long by default.
    my $Size = $Param{Size} || 8;

    my $Password = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => $Size,
    );

    return $Password;
}

=item SetPreferences()

set user preferences

    $UserObject->SetPreferences(
        Key    => 'UserComment',
        Value  => 'some comment',
        UserID => 123,
    );

=cut

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Key UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get current setting
    my %User = $Self->GetUserData(
        UserID        => $Param{UserID},
        NoOutOfOffice => 1,
    );

    # no updated needed
    return 1
        if defined $User{ $Param{Key} }
        && defined $Param{Value}
        && $User{ $Param{Key} } eq $Param{Value};

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $ConfigObject->Get('FirstnameLastnameOrder') || 0;

    # get user preferences config
    my $GeneratorModule = $ConfigObject->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    # set preferences
    return $PreferencesObject->SetPreferences(%Param);
}

=item GetPreferences()

get user preferences

    my %Preferences = $UserObject->GetPreferences(
        UserID => 123,
    );

=cut

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # get user preferences config
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    return $PreferencesObject->GetPreferences(%Param);
}

=item DeletePreferences()

delete a user preference

    my $Succes = $UserObject->DeletePreferences(
        UserID => 123,
        Key    => 'UserEmail',
    );

=cut

sub DeletePreferences {
    my $Self = shift;

    # get user preferences config
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    return $PreferencesObject->DeletePreferences(@_);
}

=item SearchPreferences()

search in user preferences

    my %UserList = $UserObject->SearchPreferences(
        Key   => 'UserEmail',
        Value => 'email@example.com',   # optional, limit to a certain value/pattern
    );

=cut

sub SearchPreferences {
    my $Self = shift;

    # get user preferences config
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    return $PreferencesObject->SearchPreferences(@_);
}

=item TokenGenerate()

generate a random token

    my $Token = $UserObject->TokenGenerate(
        UserID => 123,
    );

=cut

sub TokenGenerate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!"
        );
        return;
    }
    my $Token = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => 15,
    );

    # save token in preferences
    $Self->SetPreferences(
        Key    => 'UserToken',
        Value  => $Token,
        UserID => $Param{UserID},
    );

    return $Token;
}

=item TokenCheck()

check password token

    my $Valid = $UserObject->TokenCheck(
        Token  => $Token,
        UserID => 123,
    );

=cut

sub TokenCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Token} || !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Token and UserID!'
        );
        return;
    }

    # get preferences token
    my %Preferences = $Self->GetPreferences(
        UserID => $Param{UserID},
    );

    # check requested vs. stored token
    if ( $Preferences{UserToken} && $Preferences{UserToken} eq $Param{Token} ) {

        # reset password token
        $Self->SetPreferences(
            Key    => 'UserToken',
            Value  => '',
            UserID => $Param{UserID},
        );

        # return true if token is valid
        return 1;
    }

    # return false if token is invalid
    return;
}

=begin Internal:

=item _UserFullname()

Builds the user fullname based on firstname, lastname and login. The order
can be configured.

    my $Fullname = $Object->_UserFullname(
        UserFirstname => 'Test',
        UserLastname  => 'Person',
        UserLogin     => 'tp',
        NameOrder     => 0,         # optional 0, 1, 2, 3, 4, 5
    );

=cut

sub _UserFullname {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(UserFirstname UserLastname UserLogin)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $FirstnameLastNameOrder = $Param{NameOrder} || 0;

    my $UserFullname;
    if ( $FirstnameLastNameOrder eq '0' ) {
        $UserFullname = $Param{UserFirstname} . ' '
            . $Param{UserLastname};
    }
    elsif ( $FirstnameLastNameOrder eq '1' ) {
        $UserFullname = $Param{UserLastname} . ', '
            . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '2' ) {
        $UserFullname = $Param{UserFirstname} . ' '
            . $Param{UserLastname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '3' ) {
        $UserFullname = $Param{UserLastname} . ', '
            . $Param{UserFirstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '4' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserFirstname}
            . ' ' . $Param{UserLastname};
    }
    elsif ( $FirstnameLastNameOrder eq '5' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserLastname}
            . ', ' . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '6' ) {
        $UserFullname = $Param{UserLastname} . ' '
            . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '7' ) {
        $UserFullname = $Param{UserLastname} . ' '
            . $Param{UserFirstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '8' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserLastname}
            . ' ' . $Param{UserFirstname};
    }
    return $UserFullname;
}

sub _PermissionDebug {
    my ( $Self, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Kernel::Config')->Get('Permission::Debug') );

    printf STDERR "(%5i) %-15s %s\n", $$, "[Permission]", $Message;
}

=end Internal:

=cut

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
