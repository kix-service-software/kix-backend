# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Helper;

use strict;
use warnings;

use File::Path qw(rmtree);

use Kernel::System::SysConfig;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Cache',
    'Contact',
    'Role',
    'Main',
    'UnitTest',
    'User',
);

=head1 NAME

Kernel::System::UnitTest::Helper - unit test helper functions

=over 4

=cut

=item new()

construct a helper object.

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'UnitTest::Helper' => {
            RestoreDatabase            => 1,        # runs the test in a transaction,
                                                    # and roll it back in the destructor
                                                    #
                                                    # NOTE: Rollback does not work for
                                                    # changes in the database layout. If you
                                                    # want to do this in your tests, you cannot
                                                    # use this option and must handle the rollback
                                                    # yourself.
        },
    );
    my $Helper = $Kernel::OM->Get('UnitTest::Helper');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{UnitTestObject} = $Kernel::OM->Get('UnitTest');

    # remove any leftover configuration changes from aborted previous runs
    $Self->ConfigSettingCleanup();

    # set environment variable to skip SSL certificate verification if needed
    if ( $Param{SkipSSLVerify} ) {

        # remember original value
        $Self->{PERL_LWP_SSL_VERIFY_HOSTNAME} = $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME};

        # set environment value to 0
        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

        $Self->{RestoreSSLVerify} = 1;
        $Self->{UnitTestObject}->True( 1, 'Skipping SSL certificates verification' );
    }

    # switch article dir to a temporary one to avoid collisions
    if ( $Param{UseTmpArticleDir} ) {
        $Self->UseTmpArticleDir();
    }

    if ( $Param{RestoreDatabase} ) {
        $Self->{RestoreDatabase} = 1;
        my $StartedTransaction = $Self->BeginWork();
        $Self->{UnitTestObject}->True( $StartedTransaction, 'Started database transaction.' );

    }

    # disable debugging
    foreach my $Type ( qw(Permission Cache) ) {
        my $Success = $Kernel::OM->Get('Config')->Set(
            Key   => $Type."::Debug",
            Value => 0,
        );

        $Self->{UnitTestObject}->True(
            $Success,
            "Disabled $Type debugging",
        );
    }

    return $Self;
}

=item GetRandomID()

creates a random ID that can be used in tests as a unique identifier.

It is guaranteed that within a test this function will never return a duplicate.

Please note that these numbers are not really random and should only be used
to create test data.

=cut

sub GetRandomID {
    my ( $Self, %Param ) = @_;

    return 'test' . $Self->GetRandomNumber();
}

=item GetRandomNumber()

creates a random Number that can be used in tests as a unique identifier.

It is guaranteed that within a test this function will never return a duplicate.

Please note that these numbers are not really random and should only be used
to create test data.

=cut

# Use package variables here (instead of attributes in $Self)
# to make it work across several unit tests that run during the same second.
my %GetRandomNumberPrevious;

sub GetRandomNumber {

    my $PIDReversed = reverse $$;
    my $PID = reverse sprintf '%.6d', $PIDReversed;

    my $Prefix = $PID . substr time(), -5, 5;

    return $Prefix . $GetRandomNumberPrevious{$Prefix}++ || 0;
}

=item TestUserCreate()

creates a test user that can be used in tests. It will
be set to invalid automatically during the destructor. Returns
the login name of the new user, the password is the same.

    my $TestUserLogin = $Helper->TestUserCreate(
        Roles => ['admin', 'users'],            # optional, list of roles to add this user to
        Language => 'de'                        # optional, defaults to 'en' if not set
    );

=cut

sub TestUserCreate {
    my ( $Self, %Param ) = @_;

    # disable email checks to create new user
    my $ConfigObject = $Kernel::OM->Get('Config');
    local $ConfigObject->{CheckEmailAddresses} = 0;

    # create test user
    my $OrgID;
    my $TestUserID;
    my $TestUserLogin;
    my $TestUserContactID;
    COUNT:
    for my $Count ( 1 .. 10 ) {

        $TestUserLogin = $Self->GetRandomID();

        $TestUserID = $Kernel::OM->Get('User')->UserAdd(
            UserLogin    => $TestUserLogin,
            UserPw       => $TestUserLogin,
            ValidID      => 1,
            ChangeUserID => 1,
            IsAgent      => 1,
        );

        $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            Number  => $Self->GetRandomID(),
            Name    => 'testorg-'.$Self->GetRandomID(),
            ValidID => 1,
            UserID  => 1,
        );

        $TestUserContactID =  $Kernel::OM->Get('Contact')->ContactAdd(
            AssignedUserID        => $TestUserID,
            Firstname             => $TestUserLogin,
            Lastname              => $TestUserLogin,
            Email                 => $TestUserLogin . '@localunittest.com',
            PrimaryOrganisationID => $OrgID,
            OrganisationIDs       => [ $OrgID ],
            ValidID               => 1,
            UserID                => 1,
        );

        last COUNT if $TestUserID;
    }

    die 'Could not create test user login' if !$TestUserLogin;
    die 'Could not create test user'       if !$TestUserID;
    die 'Could not create test user contact' if !$TestUserContactID;

    # Remember UserID of the test user to later set it to invalid
    #   in the destructor.
    $Self->{TestUsers} ||= [];
    push( @{ $Self->{TestUsers} }, $TestUserID );

    $Self->{UnitTestObject}->True( 1, "Created test user $TestUserLogin (UserID $TestUserID, ContactID $TestUserContactID, OrgID $OrgID)" );

    # Add user to roles
    ROLE_NAME:
    for my $RoleName ( @{ $Param{Roles} || [] } ) {

        # get role object
        my $RoleObject = $Kernel::OM->Get('Role');

        my $RoleID = $RoleObject->RoleLookup( Role => $RoleName );
        die "Cannot find role $RoleName" if ( !$RoleID );

        $RoleObject->RoleUserAdd(
            AssignUserID => $TestUserID,
            RoleID       => $RoleID,
            UserID       => 1,
        ) || die "Could not add test user $TestUserLogin to role $RoleName";

        $Self->{UnitTestObject}->True( 1, "Added test user $TestUserLogin to role $RoleName" );
    }

    # set user language
    my $UserLanguage = $Param{Language} || 'en';
    $Kernel::OM->Get('User')->SetPreferences(
        UserID => $TestUserID,
        Key    => 'UserLanguage',
        Value  => $UserLanguage,
    );
    $Self->{UnitTestObject}->True( 1, "Set user UserLanguage to $UserLanguage" );

    return $TestUserLogin;
}

=item TestContactCreate()

creates a test customer user that can be used in tests. It will
be set to invalid automatically during the destructor. Returns
the login name of the new customer user, the password is the same.

    my $TestContactID = $Helper->TestContactCreate(
        Language => 'de',   # optional, defaults to 'en' if not set
    );

=cut

sub TestContactCreate {
    my ( $Self, %Param ) = @_;

    # disable email checks to create new user
    my $ConfigObject = $Kernel::OM->Get('Config');
    local $ConfigObject->{CheckEmailAddresses} = 0;

    # create test user
    my $TestContactID;
    my $TestContactLogin;
    my $TestContactUserID;
    my $OrgID;
    COUNT:
    for my $Count ( 1 .. 10 ) {

        $TestContactLogin = $Self->GetRandomID();

        $TestContactUserID = $Kernel::OM->Get('User')->UserAdd(
            UserLogin    => $TestContactLogin,
            UserPw       => $TestContactLogin,
            ValidID      => 1,
            ChangeUserID => 1,
            IsCustomer   => 1,
        );

        $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            Number  => $TestContactLogin,
            Name    => $TestContactLogin,
            ValidID => 1,
            UserID  => 1,
        );

        $TestContactID = $Kernel::OM->Get('Contact')->ContactAdd(
            Firstname             => $TestContactLogin,
            Lastname              => $TestContactLogin,
            PrimaryOrganisationID => $OrgID,
            OrganisationIDs       => [ $OrgID ],
            Login                 => $TestContactLogin,
            Password              => $TestContactLogin,
            Email                 => $TestContactLogin . '@localunittest.com',
            AssignedUserID        => $TestContactUserID,
            ValidID               => 1,
            UserID                => 1,
        );

        last COUNT if $TestContactID;
    }

    die 'Could not create test user contact' if !$TestContactID;
    die 'Could not create test user organisation' if !$OrgID;
    die 'Could not create test user login' if !$TestContactUserID;

    # Remember IDs of the test user and organisation to later set it to invalid
    #   in the destructor.
    $Self->{TestContacts} ||= [];
    push( @{ $Self->{TestContacts} }, $TestContactID );

    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->{UnitTestObject}->True(1, "Created test contact $TestContactLogin (ContactID $TestContactID, UserID $TestContactUserID)");

    # set customer user language
    my $UserLanguage = $Param{Language} || 'en';
    $Kernel::OM->Get('Contact')->SetPreferences(
        ContactID => $TestContactID,
        Key       => 'UserLanguage',
        Value     => $UserLanguage,
    );
    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->{UnitTestObject}->True( 1, "Set contact UserLanguage to $UserLanguage" );

    return $TestContactID;
}

=item TestRoleCreate()

creates a test role with given permissions that can be used in tests.
Returns the ID and Name of the new role

    my $RoleID = $Helper->TestRoleCreate(
        Name => '...',
        Permissions => {
            Resource => [
                {
                    Target => '/tickets',
                    Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
                }
            ]
        }
    );

=cut

sub TestRoleCreate {
    my ( $Self, %Param ) = @_;

    my $RoleObject = $Kernel::OM->Get('Role');

    # add ticket_read role
    my $RoleID = $RoleObject->RoleAdd(
        Name         => $Param{Name},
        UsageContext => $Param{UsageContext} || Kernel::System::Role->USAGE_CONTEXT->{AGENT},
        Comment      => $Param{Comment},
        ValidID      => $Param{ValidID} || 1,
        UserID       => 1,
    );

    die 'Could not create test role' if !$RoleID;

    # Remember RoleID of the role to later set it to invalid
    #   in the destructor.
    $Self->{TestRoles} ||= [];
    push( @{ $Self->{TestRoles} }, $RoleID );

    $Self->{UnitTestObject}->True( 1, "Created test role $Param{Name} ($RoleID)" );

    if ( ref $Param{Permissions} eq 'HASH' ) {
        my %PermissionTypes = reverse $RoleObject->PermissionTypeList();

        foreach my $Type ( %{$Param{Permissions}} ) {
            foreach my $Permission ( @{$Param{Permissions}->{$Type}} ) {
                my $Success = $RoleObject->PermissionAdd(
                    RoleID => $RoleID,
                    TypeID => $PermissionTypes{$Type},
                    Target => $Permission->{Target},
                    Value  => $Permission->{Value},
                    UserID => 1,
                );

                die 'Could not create test role' if !$Success;
            }
        }
    }

    return $RoleID
}

=item BeginWork()

    $Helper->BeginWork()

Starts a database transaction (in order to isolate the test from the static database).

=cut

sub BeginWork {
    my ( $Self, %Param ) = @_;
    my $DBObject = $Kernel::OM->Get('DB');
    $DBObject->Connect();
    return $DBObject->{dbh}->begin_work();
}

=item Rollback()

    $Helper->Rollback()

Rolls back the current database transaction.

=cut

sub Rollback {
    my ( $Self, %Param ) = @_;
    my $DatabaseHandle = $Kernel::OM->Get('DB')->{dbh};

    # if there is no database handle, there's nothing to rollback
    if ($DatabaseHandle) {
        return $DatabaseHandle->rollback();
    }
    return 1;
}

=item GetTestHTTPHostname()

returns a hostname for HTTP based tests, possibly including the port.

=cut

sub GetTestHTTPHostname {
    my ( $Self, %Param ) = @_;

    my $Host = $Kernel::OM->Get('Config')->Get('TestHTTPHostname');
    return $Host if $Host;

    my $FQDN = $Kernel::OM->Get('Config')->Get('FQDN');
    if (IsHashRefWithData($FQDN)) {
        $FQDN = $FQDN->{Backend}
    }

    # try to resolve fqdn host
    if ( $FQDN ne 'yourhost.example.com' && gethostbyname($FQDN) ) {
        $Host = $FQDN;
    }

    # try to resolve localhost instead
    if ( !$Host && gethostbyname('localhost') ) {
        $Host = 'localhost';
    }

    # use hardcoded localhost ip address
    if ( !$Host ) {
        $Host = '127.0.0.1';
    }

    return $Host;
}

my $FixedTime;

=item FixedTimeSet()

makes it possible to override the system time as long as this object lives.
You can pass an optional time parameter that should be used, if not,
the current system time will be used.

All regular perl calls to time(), localtime() and gmtime() will use this
fixed time afterwards. If this object goes out of scope, the 'normal' system
time will be used again.

=cut

sub FixedTimeSet {
    my ( $Self, $TimeToSave ) = @_;

    $FixedTime = $TimeToSave // CORE::time();

    # This is needed to reload objects that directly use the time functions
    #   to get a hold of the overrides.
    my @Objects = (
        'Kernel::System::Time',
        'Kernel::System::Cache::FileStorable',
        'Kernel::System::PID',
    );

    for my $Object (@Objects) {
        my $FilePath = $Object;
        $FilePath =~ s{::}{/}xmsg;
        $FilePath .= '.pm';
        if ( $INC{$FilePath} ) {
            no warnings 'redefine';
            delete $INC{$FilePath};
            $Kernel::OM->Get('Main')->Require($Object);
        }
    }

    return $FixedTime;
}

=item FixedTimeUnset()

restores the regular system time behaviour.

=cut

sub FixedTimeUnset {
    my ($Self) = @_;

    undef $FixedTime;

    return;
}

=item FixedTimeAddSeconds()

adds a number of seconds to the fixed system time which was previously
set by FixedTimeSet(). You can pass a negative value to go back in time.

=cut

sub FixedTimeAddSeconds {
    my ( $Self, $SecondsToAdd ) = @_;

    return if ( !defined $FixedTime );
    $FixedTime += $SecondsToAdd;
    return;
}

# See http://perldoc.perl.org/5.10.0/perlsub.html#Overriding-Built-in-Functions
BEGIN {
    *CORE::GLOBAL::time = sub {
        return defined $FixedTime ? $FixedTime : CORE::time();
    };
    *CORE::GLOBAL::localtime = sub {
        my ($Time) = @_;
        if ( !defined $Time ) {
            $Time = defined $FixedTime ? $FixedTime : CORE::time();
        }
        return CORE::localtime($Time);
    };
    *CORE::GLOBAL::gmtime = sub {
        my ($Time) = @_;
        if ( !defined $Time ) {
            $Time = defined $FixedTime ? $FixedTime : CORE::time();
        }
        return CORE::gmtime($Time);
    };
}

sub DESTROY {
    my $Self = shift;

    # reset time freeze
    FixedTimeUnset();

    # restore system configuration if needed
    if ( $Self->{SysConfigBackup} ) {
        $Self->{SysConfigObject}->Upload( Content => $Self->{SysConfigBackup} );
        $Self->{UnitTestObject}->True( 1, 'Restored the system configuration' );
    }

    # remove any configuration changes
    $Self->ConfigSettingCleanup();

    # restore environment variable to skip SSL certificate verification if needed
    if ( $Self->{RestoreSSLVerify} ) {

        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = $Self->{PERL_LWP_SSL_VERIFY_HOSTNAME};

        $Self->{RestoreSSLVerify} = 0;

        $Self->{UnitTestObject}->True( 1, 'Restored SSL certificates verification' );
    }

    # restore database, clean caches
    if ( $Self->{RestoreDatabase} ) {
        my $RollbackSuccess = $Self->Rollback();
        $Kernel::OM->Get('Cache')->CleanUp();
        $Self->{UnitTestObject}->True( $RollbackSuccess, 'Rolled back all database changes and cleaned up the cache.' );
    }

    # disable email checks to create new user
    my $ConfigObject = $Kernel::OM->Get('Config');
    local $ConfigObject->{Config}->{CheckEmailAddresses} = 0;

    # cleanup temporary article directory
    if ( $Self->{TmpArticleDir} && -d $Self->{TmpArticleDir} ) {
        File::Path::rmtree( $Self->{TmpArticleDir} );
    }

    # invalidate test users
    if ( ref $Self->{TestUsers} eq 'ARRAY' && @{ $Self->{TestUsers} } ) {
        TESTUSERS:
        for my $TestUser ( @{ $Self->{TestUsers} } ) {

            my %User = $Kernel::OM->Get('User')->GetUserData(
                UserID => $TestUser,
            );

            my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                UserID => $TestUser,
            );

            if ( !$User{UserID} ) {

                # if no such user exists, there is no need to set it to invalid;
                # happens when the test user is created inside a transaction
                # that is later rolled back.
                next TESTUSERS;
            }

            # make test user invalid
            my $Success = $Kernel::OM->Get('User')->UserUpdate(
                %User,
                ValidID      => 2,
                ChangeUserID => 1,
            );

            $Self->{UnitTestObject}->True( $Success, "Set test user $TestUser to invalid" );

            $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
                %Contact,
                ValidID      => 2,
                ChangeUserID => 1,
            );

            $Self->{UnitTestObject}->True( $Success, "Set test contact $Contact{ID} for user $TestUser to invalid" );

            # disable assigned organisation
            my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $Contact{PrimaryOrganisationID}
            );
            $Success = $Kernel::OM->Get('Organisation')->OrganisationUpdate(
                %Organisation,
                ID      => $Contact{PrimaryOrganisationID},
                ValidID => 2,
                UserID  => 1,
            );

            $Self->{UnitTestObject}->True(
                $Success, "Set test organisation $Contact{PrimaryOrganisationID} to invalid"
            );
        }
    }

    # invalidate test roles
    if ( ref $Self->{TestRoles} eq 'ARRAY' && @{ $Self->{TestRoles} } ) {
        TESTROLES:
        for my $TestRole ( @{ $Self->{TestRoles} } ) {

            my %Role = $Kernel::OM->Get('Role')->RoleGet(
                ID => $TestRole,
            );

            if ( !$Role{ID} ) {

                # if no such role exists, there is no need to set it to invalid;
                # happens when the test role is created inside a transaction
                # that is later rolled back.
                next TESTROLES;
            }

            # make test role invalid
            my $Success = $Kernel::OM->Get('Role')->RoleUpdate(
                %Role,
                ValidID      => 2,
                ChangeUserID => 1,
            );

            $Self->{UnitTestObject}->True( $Success, "Set test role $TestRole to invalid" );
        }
    }
}

=item ConfigSettingChange()

temporarily change a configuration setting system wide to another value,
both in the current ConfigObject and also in the system configuration on disk.

This will be reset when the Helper object is destroyed.

Please note that this will not work correctly in clustered environments.

    $Helper->ConfigSettingChange(
        Valid => 1,            # (optional) enable or disable setting
        Key   => 'MySetting',  # setting name
        Value => { ... } ,     # setting value
    );

=cut

sub ConfigSettingChange {
    my ( $Self, %Param ) = @_;

    my $Valid = $Param{Valid} // 1;
    my $Key   = $Param{Key};
    my $Value = $Param{Value};

    die "Need 'Key'" if !defined $Key;

    # set in SysConfig
    $Kernel::OM->Get('SysConfig')->ValueSet(
        Name   => $Key,
        Value  => $Valid ? $Value : undef,
        UserID => 1,
    );

    # set in Config
    $Kernel::OM->Get('Config')->Set(
        Key   => $Param{Key},
        Value => $Valid ? $Value : undef,
    );

    return 1;
}

=item ConfigSettingCleanup()

remove all config setting changes from ConfigSettingChange();

=cut

sub ConfigSettingCleanup {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item UseTmpArticleDir()

switch the article storage directory to a temporary one to prevent collisions;

=cut

sub UseTmpArticleDir {
    my ( $Self, %Param ) = @_;

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    my $TmpArticleDir;
    TRY:
    for my $Try ( 1 .. 100 ) {

        $TmpArticleDir = $Home . '/var/tmp/unittest-article-' . $Self->GetRandomNumber();

        next TRY if -e $TmpArticleDir;
        last TRY;
    }

    $Self->ConfigSettingChange(
        Valid => 1,
        Key   => 'ArticleDir',
        Value => $TmpArticleDir,
    );

    $Self->{TmpArticleDir} = $TmpArticleDir;

    return 1;
}

=item StartWebserver()

mock a webserver

=cut

# sub StartWebserver {
#     my ( $Self, %Param ) = @_;

#     use Test::Fake::HTTPD;

#     my $httpd = Test::Fake::HTTPD->new(
#         timeout     => 5,
#         daemon_args => { },
#     );

#     $httpd->run(sub {
#         my $req = shift;
#         print STDERR Data::Dumper::Dumper($req);
#         [ 200, [ 'Content-Type', 'text/plain' ], [ 'Mock HTTP server' ] ];
#     });

#     return $httpd;
# }

=item CombineLists()

combines two arrays (intersect or union)

    my @CombinedList = $Self->CombineLists(
        ListA   => $ListAArrayRef,
        ListB   => $ListBArrayRef,
        Union   => 1                # (optional) default 0
    );

    e.g.
        ListA = [ 1, 2, 3, 4 ]
        ListB = [ 2, 4, 5 ]

        as union = [1, 2, 3, 4, 5 ]
        as intersect = [ 2, 4 ]

=cut

sub CombineLists {
    my ( $Self, %Param ) = @_;

    my %Union;
    my %Isect;
    for my $Element ( @{ $Param{ListA} }, @{ $Param{ListB} } ) {
        $Union{$Element}++ && $Isect{$Element}++
    }

    return $Param{Union} ? keys %Union : keys %Isect;
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
