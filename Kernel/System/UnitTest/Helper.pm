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

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    DB
    Cache
    Contact
    Role
    Main
    UnitTest
    User
    Organisation
    SysConfig
);

=head1 NAME

Kernel::System::UnitTest::Helper - unit test helper functions

=over 4

=cut

=item new()

construct a helper object.

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'UnitTest::Helper' => {},
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
        Firstname => 'Max',                      # optional, uses random login if not given
        Lastname  => 'Mustermann',               # optional, uses random login if not given
        Roles     => ['admin', 'users'],         # optional, list of roles to add this user to
        Language  => 'de'                        # optional, defaults to 'en' if not set
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

        my $TestFirstname = $Param{Firstname} || $TestUserLogin;
        my $TestLastname  = $Param{Lastname}  || $TestUserLogin;

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
            Firstname             => $TestFirstname,
            Lastname              => $TestLastname,
            Email                 => $TestUserLogin . '@localunittest.com',
            PrimaryOrganisationID => $OrgID,
            OrganisationIDs       => [ $OrgID ],
            ValidID               => 1,
            UserID                => 1,
        );

        last COUNT if $TestUserID;
    }

    die 'Could not create test user login'   if !$TestUserLogin;
    die 'Could not create test user'         if !$TestUserID;
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
            Email1                => $TestContactLogin . '@sub.localunittest.com',
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

    # Add user to roles
    ROLE_NAME:
    for my $RoleName ( @{ $Param{Roles} || [] } ) {

        # get role object
        my $RoleObject = $Kernel::OM->Get('Role');

        my $RoleID = $RoleObject->RoleLookup( Role => $RoleName );
        die "Cannot find role $RoleName" if ( !$RoleID );

        $RoleObject->RoleUserAdd(
            AssignUserID => $TestContactUserID,
            RoleID       => $RoleID,
            UserID       => 1,
        ) || die "Could not add test contact $TestContactLogin to role $RoleName";

        $Self->{UnitTestObject}->True( 1, "Added test contact $TestContactLogin to role $RoleName" );
    }

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

    if ( !$Self->{RollbackDB} ) {
        my $DBObject = $Kernel::OM->Get('DB');
        $DBObject->Connect();

        return if ( !$DBObject->{dbh}->begin_work() );

        $Self->{RollbackDB} = 1;
    }

    return 1;
}

sub SSLVerify {
    my ( $Self, %Param ) = @_;

    # set environment variable to skip SSL certificate verification if needed
    if (
        $Param{SkipSSLVerify}
        && !$Self->{RestoreSSLVerify}
    ) {

        # remember original value
        $Self->{PERL_LWP_SSL_VERIFY_HOSTNAME} = $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME};

        # set environment value to 0
        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

        $Self->{RestoreSSLVerify} = 1;
        $Self->{UnitTestObject}->True( 1, 'Skipping SSL certificates verification' );
    }

    # restore environment variable to skip SSL certificate verification if needed
    if ( $Param{RestoreSSLVerify} ) {

        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = $Self->{PERL_LWP_SSL_VERIFY_HOSTNAME};

        $Self->{RestoreSSLVerify} = 0;

        $Self->{UnitTestObject}->True( 1, 'Restored SSL certificates verification' );
    }

    return 1;
}

=item Rollback()

    $Helper->Rollback()

Rolls back the current database transaction.

=cut

sub Rollback {
    my ( $Self, %Param ) = @_;

    # reset time freeze
    $Self->FixedTimeUnset();

    $Kernel::OM->Get('Cache')->CleanUp();

    if ( $Self->{SysConfigChanged} ) {
        $Kernel::OM->Get('SysConfig')->CleanUp();
        $Kernel::OM->Get('SysConfig')->Rebuild();
        $Self->{SysConfigChanged} = 0;
    }

    # cleanup temporary article directory
    if (
        $Self->{TmpArticleDir}
        && -d $Self->{TmpArticleDir}
    ) {
        File::Path::rmtree( $Self->{TmpArticleDir} );
    }

    if ( $Self->{RestoreSSLVerify} ) {
        $Self->SSLVerify(
            RestoreSSLVerify => 1
        );
    }

    my $DatabaseHandle = $Kernel::OM->Get('DB')->{dbh};

    # if there is no database handle, there's nothing to rollback
    if (
        $Self->{RollbackDB}
        && $DatabaseHandle
    ) {
        $Self->{RollbackDB} = 0;
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

    # This is needed to reload objects that directly use the time functions
    #   to get a hold of the overrides.
    my @Objects = (
        'Kernel::System::Time',
        'Kernel::System::Cache::FileStorable'
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
        Silent => $Param{Silent},
    );

    # set in Config
    $Kernel::OM->Get('Config')->Set(
        Key   => $Param{Key},
        Value => $Valid ? $Value : undef,
    );

    $Self->{SysConfigChanged} = 1;

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
