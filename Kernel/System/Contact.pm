# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Contact;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;
use Kernel::System::VariableCheck qw( IsArrayRefWithData );
use Data::UUID;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Organisation',
    'DB',
    'Log',
    'Main',
    'Time',
    'User',
);

=head1 NAME

Kernel::System::Contact - customer user lib

=head1 SYNOPSIS

All customer user functions. E. g. to add and update customer users.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ContactObject = $Kernel::OM->Get('Contact');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $MainObject   = $Kernel::OM->Get('Main');

    # load generator contact preferences module
    my $GeneratorModule = $ConfigObject->Get('ContactPreferences')->{Module}
        || 'Contact::Preferences::DB';

    if ( $MainObject->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new();
    }

    $Self->{CacheType} = 'Contact';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'Contact::EventModulePost',
    );

    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=item ContactAdd()

add a new contact

    my $ID = $ContactObject->ContactAdd(
        Firstname             => 'Huber',
        Lastname              => 'Manfred',
        Email                 => 'email@example.com',      # optional
        PrimaryOrganisationID => 123,                      # optional
        OrganisationIDs       => [                         # optional, if only PrimaryOrganisationID should be set.
            123,
            456
        ],
        Title                 => 'Dr.',                    # optional
        Phone                 => '123456789',              # optional
        Fax                   => '123456789',              # optional
        Mobile                => '123456789',              # optional
        Street                => 'Somestreet 123',         # optional
        Zip                   => '12345',                  # optional
        City                  => 'Somewhere',              # optional
        Country               => 'Somecountry',            # optional
        Comment               => 'some comment',           # optional
        AssignedUserID        => 123,                      # optional
        ValidID               => 1,
        UserID                => 123,
    );

=cut

sub ContactAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Firstname Lastname)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    #if no mail is given for a new contact, a random, but unique, dummy email address is generated.
    if (!$Param{Email}) {
        my $uuid = Data::UUID->new();
        $Param{Email} = "noreply-" . $uuid->to_hexstring($uuid->create()) . '@nomail.com';
    }
    elsif ( $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck') ) {
        # check duplicate email
        my $ExistingContactID = $Self->ContactLookup(
            Email  => $Param{Email},
            Silent => 1
        );
        if ($ExistingContactID) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot add contact. Email \"$Param{Email}\" already exists.",
            );
            return;
        }
    }

    # check if primary OrganisationID exists
    if ($Param{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $Param{PrimaryOrganisationID},
        );

        if (!%OrgData || $OrgData{ValidID} != 1) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'No valid organisation found for primary organisation ID "' . $Param{PrimaryOrganisationID} . '".',
            );
            return;
        }
    }

    if (IsArrayRefWithData($Param{OrganisationIDs})) {
        # check if primary OrganisationID is contained in assigned OrganisationIDs
        if (!grep /$Param{PrimaryOrganisationID}/, @{$Param{OrganisationIDs}}) {
            push(@{$Param{OrganisationIDs}}, $Param{PrimaryOrganisationID});
        }
        foreach my $OrgID (@{$Param{OrganisationIDs}}) {
            my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if (!%OrgData || $OrgData{ValidID} != 1) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'No valid organisation found for assigned organisation ID "' . $OrgID . '".',
                );
                return;
            }
        }
    }
    else {
        $Param{OrganisationIDs} = ($Param{PrimaryOrganisationID}) ? [$Param{PrimaryOrganisationID}] : undef;
    }

    # if assigned user ist given, check associated user exists
    my %ExistingUser;
    if ($Param{AssignedUserID}) {
        %ExistingUser = $Kernel::OM->Get('User')->GetUserData(
            UserID => $Param{AssignedUserID}
        );
        if (!IsHashRefWithData(\%ExistingUser)) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot create contact. No user with ID $Param{AssignedUserID} exists.",
            );
            return;
        } else {
            my $ExistingContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                UserID => $Param{AssignedUserID},
                Silent => 1,
            );
            if ($ExistingContactID) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Cannot create contact. User '$Param{AssignedUserID}' already has a contact.",
                );
                return;
            }
        }
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO contact (firstname, lastname, email, title, phone, fax,
                     mobile, street, zip, city, country, comments, valid_id,
                     create_time, create_by, change_time, change_by, user_id)
            VALUES ( ?, ?, ?, ?, ?, ?,
                     ?, ?, ?, ?, ?, ?, ?,
                    current_timestamp, ?, current_timestamp, ?, ?)',
        Bind => [
            \$Param{Firstname}, \$Param{Lastname}, \$Param{Email}, \$Param{Title}, \$Param{Phone}, \$Param{Fax},
            \$Param{Mobile}, \$Param{Street}, \$Param{Zip}, \$Param{City}, \$Param{Country}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID}, \$Param{AssignedUserID}
        ],
    );

    # find ID of new item
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id FROM contact WHERE email = ? AND firstname = ? AND lastname = ? ORDER BY id DESC',
        Bind  => [
            \$Param{Email}, \$Param{Firstname}, \$Param{Lastname}
        ],
        Limit => 1,
    );

    # fetch the result
    my $ContactID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ContactID = $Row[0];
    }

    if ( $ContactID ) {
        if ( $Param{OrganisationIDs} ) {
            # remove duplicates
            my @OrgIDs = $Kernel::OM->Get('Main')->GetUnique(@{$Param{OrganisationIDs}});
            for my $orgID ( @OrgIDs ) {
                return if !$Kernel::OM->Get('DB')->Do(
                    SQL  => 'INSERT INTO contact_organisation (contact_id, org_id, is_primary) VALUES (?,?,?)',
                    Bind => [\$ContactID, \$orgID, \( $orgID eq $Param{PrimaryOrganisationID} ? 1 : 0 )],
                );
            }
        }

        # log notice
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  =>
                "Contact: $ContactID ('$Param{Firstname}/$Param{Lastname}') created successfully (created by user id $Param{UserID})!",
        );
        # reset cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType},
        );

        # trigger event
        $Self->EventHandler(
            Event  => 'ContactAdd',
            Data   => {
                ID      => $ContactID,
                NewData => \%Param,
            },
            UserID => $Param{UserID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientRegistration')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Contact',
            ObjectID  => $ContactID,
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot find new contact with email $Param{Email} (and firstname: $Param{Firstname}, lastname: $Param{Lastname})!",
        );
    }

    # update user valid if necessary (user is no agent/customer or contact is invalid = user is invalid)
    if (IsHashRefWithData(\%ExistingUser)) {
        my @ValidList = $Kernel::OM->Get('Valid')->ValidIDsGet();
        my $NewUserValid = (!$ExistingUser{IsAgent} && !$ExistingUser{IsCustomer})
            || (!grep { $Param{ValidID} == $_ } @ValidList) ? 2 : 1;
        if ($NewUserValid != $ExistingUser{ValidID}) {
            my $Success = $Kernel::OM->Get('User')->UserUpdate(
                %ExistingUser,
                ValidID      => $NewUserValid,
                ChangeUserID => 1,
            );
        }
    }

    # return data
    return $ContactID;
}

=item ContactGet()

get contact data (Firstname, Lastname, Email, ...) by contact id or for assigned user id

    my %Contact = $ContactObject->ContactGet(
        ID => 123,
        DynamicFields => 0|1,         # Optional, default 0. To include the dynamic field values for this contact to the return structure.
    );

    my %Contact = $ContactObject->ContactGet(
        UserID => 123
        DynamicFields => 0|1,         # Optional, default 0. To include the dynamic field values for this contact to the return structure.
    );

=cut

sub ContactGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if (!$Param{ID} && !$Param{UserID}) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or UserID!"
        );
        return;
    }

    my $SQLWhere = ' WHERE ';
    my @BindVars;
    my $CacheKey;

    # check cache
    my $FetchDynamicFields = $Param{DynamicFields} ? 1 : 0;

    if ($Param{ID}) {
        # ignore non-numeric IDs
        return if $Param{ID} !~ /^\d+$/;

        # check cache
        $CacheKey = "ContactGet::ContactID::$Param{ID}::$FetchDynamicFields";
        my $Data = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );

        return %{$Data} if ref $Data eq 'HASH';

        $SQLWhere .= ' id = ?';
        push(@BindVars,\$Param{ID});

    }
    elsif ($Param{UserID}) {
        return if $Param{UserID} !~ /^\d+$/;

        $CacheKey = "ContactGet::UserID::$Param{UserID}::$FetchDynamicFields";
        my $Data = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );

        return %{$Data} if ref $Data eq 'HASH';

        $SQLWhere .= 'user_id IS NOT NULL AND user_id = ?';
        push(@BindVars,\$Param{UserID});
    }

    # ask database
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id, firstname, lastname, email, title, phone, fax, mobile, street, zip, city, country, comments,'
                . 'valid_id, create_time, create_by, change_time, change_by, user_id FROM contact ' . $SQLWhere,
        Bind  => \@BindVars,
        Limit => 1,
    );

    # fetch the result
    my %Contact;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {

        $Contact{ID}                    = $Row[0];
        $Contact{UserID}                = $Row[0]; # for backward compatibility (e.g. NotifcationEvent)
        $Contact{Firstname}             = $Row[1];
        $Contact{Lastname}              = $Row[2];
        $Contact{Email}                 = $Row[3];
        $Contact{Title}                 = $Row[4];
        $Contact{Phone}                 = $Row[5];
        $Contact{Fax}                   = $Row[6];
        $Contact{Mobile}                = $Row[7];
        $Contact{Street}                = $Row[8];
        $Contact{Zip}                   = $Row[9];
        $Contact{City}                  = $Row[10];
        $Contact{Country}               = $Row[11];
        $Contact{Comment}               = $Row[12] || '';
        $Contact{ValidID}               = $Row[13];
        $Contact{CreateTime}            = $Row[14];
        $Contact{CreateBy}              = $Row[15];
        $Contact{ChangeTime}            = $Row[16];
        $Contact{ChangeBy}              = $Row[17];
        $Contact{AssignedUserID}        = $Row[18];
        last;
    }
    # get organisations
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT org_id, is_primary FROM contact_organisation WHERE contact_id = ?',
        Bind  => [ \$Contact{ID} ],
    );
    my @OrganisationIDs;
    while (my @Row =$Kernel::OM->Get('DB')->FetchrowArray()) {
        push(@OrganisationIDs,$Row[0]);
        $Contact{PrimaryOrganisationID} = $Row[0] if ($Row[1]);

    }
    $Contact{OrganisationIDs} = \@OrganisationIDs;

    # check item
    if ( $Param{ID} && !$Contact{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Contact with ID $Param{ID} not found in database!",
        );
        return;
    }

    # check item
    if ( $Param{UserID} && !$Contact{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "No contact assigned to user id $Param{UserID}!",
        );
        return;
    }

    $Contact{Fullname} = $Self->_ContactFullname(
        Firstname => $Contact{Firstname},
        Lastname  => $Contact{Lastname},
        UserLogin => ($Contact{AssignedUserID}) ? $Kernel::OM->Get('User')->UserLookup(
            UserID => $Contact{AssignedUserID},
        ) : '',
        NameOrder => $Kernel::OM->Get('Config')->Get('FirstnameLastnameOrder') || 0,
    );

    # check if need to return DynamicFields
    if ($FetchDynamicFields) {

        # get all dynamic fields for the object type Ticket
        my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            ObjectType => 'Contact'
        );

        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

            # validate each dynamic field
            next DYNAMICFIELD if !$DynamicFieldConfig;
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

            # get the current value for each dynamic field
            my $Value = $Kernel::OM->Get('DynamicField::Backend')->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Contact{ID},
            );

            # set the dynamic field name and value into the ticket hash
            $Contact{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
        }
    }

    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Contact,
    );

    return %Contact;
}

=item ContactLookup()

contact id, email oder user id lookup

    my $Email = $ContactObject->ContactLookup(
        ID     => 1,
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $ID = $ContactObject->ContactLookup(
        Email  => 'some_user_email',
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $ID = $ContactObject->ContactLookup(
        UserID  => 123,
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $ID = $ContactObject->ContactLookup(
        UserLogin => 'some_login',
        Silent    => 1, # optional, don't generate log entry if user was not found
    );

=cut

sub ContactLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if (!$Param{Email} && !$Param{ID} && !$Param{UserID} && !$Param{UserLogin}) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Email, ID of contact or UserID or UserLogin!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{Email}) {

        # check cache
        my $CacheKey = 'ContactLookup::Email::' . $Param{Email};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        my $Email = lc $Param{Email};

        return if !$DBObject->Prepare(
            SQL   => "SELECT id FROM contact WHERE $Self->{Lower}(email) = ? ORDER BY lastname, firstname",
            Bind  => [ \$Email ],
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        if ( !$ID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No ID found for contact email '$Param{Email}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $ID,
        );

        return $ID;
    }
    elsif ($Param{ID}){

        # ignore non-numeric IDs
        return if $Param{ID} && $Param{ID} !~ /^\d+$/;

        # check cache
        my $CacheKey = 'ContactLookup::ID::' . $Param{ID};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        return if !$DBObject->Prepare(
            SQL => "SELECT email FROM contact WHERE id = ?",
            Bind  => [ \$Param{ID} ],
            Limit => 1,
        );

        # fetch the result
        my $Email;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Email = $Row[0];
        }

        if ( !$Email ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No contact email found for ID '$Param{ID}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $Email,
        );

        return $Email;
    }
    elsif ($Param{UserID}){

        # ignore non-numeric IDs
        return if $Param{UserID} && $Param{UserID} !~ /^\d+$/;

        # check cache
        my $CacheKey = 'ContactLookup::UserID::' . $Param{UserID};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT id FROM contact WHERE user_id = ?",
            Bind  => [ \$Param{UserID} ],
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        if ( !$ID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No ID found for assigned user id '$Param{UserID}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $ID,
        );

        return $ID;
    }
    elsif ($Param{UserLogin}){

        # check cache
        my $CacheKey = 'ContactLookup::UserLogin::' . $Param{UserLogin};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT c.id FROM contact c, users u WHERE u.id = c.user_id AND u.login = ?",
            Bind  => [ \$Param{UserLogin} ],
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        if ( !$ID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No ID found for assigned user login '$Param{UserLogin}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $ID,
        );

        return $ID;
    }
}

=item ContactUpdate()

update contact attributes

    my $Success = $ContactObject->ContactUpdate(
        ID         => 123,
        Firstname  => 'Huber',
        Lastname   => 'Manfred',
        Email      => 'email@example.com',
        PrimaryOrganisationID => 123,
        OrganisationIDs => [
            123,
            456
        ],
        Title      => 'Dr.',
        Phone      => '123456789',
        Fax        => '123456789',
        Mobile     => '123456789',
        Street     => 'Somestreet 123',
        Zip        => '12345',
        City       => 'Somewhere',
        Country    => 'Somecountry',
        Comment    => 'some comment',
        ValidID    => 1,
        UserID     => 123,
        AssignedUserID => 123
    );

=cut

sub ContactUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check if contact exists
    my %Contact = $Self->ContactGet(
        ID => $Param{ID}
    );
    if ( !%Contact ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such contact with ID $Param{ID}!",
        );
        return;
    }

    # check duplicate email
    if ( $Param{Email} && $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck') ) {
        my $ExistingContactID = $Self->ContactLookup(
            Email  => $Param{Email},
            Silent => 1,
        );
        if ($ExistingContactID && $ExistingContactID != $Param{ID}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot update contact. Email \"$Param{Email}\" already in use by a contact.",
            );
            return;
        }
    }

    # check if primary OrganisationID exists
    if ($Param{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $Param{PrimaryOrganisationID},
        );

        if (!%OrgData || $OrgData{ValidID} != 1) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'No valid organisation found for primary organisation ID "' . $Param{PrimaryOrganisationID} . '".',
            );
            return;
        }
    }

    if (IsArrayRefWithData($Param{OrganisationIDs})) {
        foreach my $OrgID (@{$Param{OrganisationIDs}}) {
            my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if (!%OrgData || $OrgData{ValidID} != 1) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'No valid organisation found for assigned organisation ID "' . $OrgID . '".',
                );
                return;
            }
        }
    } elsif (!defined $Param{OrganisationIDs}) {
        $Param{OrganisationIDs} = $Contact{OrganisationIDs};
    }

    # check if primary OrganisationID is contained in assigned OrganisationIDs
    if ($Param{PrimaryOrganisationID} && !grep /$Param{PrimaryOrganisationID}/, @{$Param{OrganisationIDs}}) {
        push(@{$Param{OrganisationIDs}}, $Param{PrimaryOrganisationID});
    }

    # if assigned user ist given, check associated user exists
    my %ExistingUser;
    if ($Param{AssignedUserID}) {
        %ExistingUser = $Kernel::OM->Get('User')->GetUserData(
            UserID => $Param{AssignedUserID}
        );
        if (!IsHashRefWithData(\%ExistingUser)) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Cannot update contact. No user with ID $Param{AssignedUserID} exists.",
            );
            return;
        } else {
            my $ExistingContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                UserID => $Param{AssignedUserID},
                Silent => 1,
            );
            if ($ExistingContactID && $ExistingContactID != $Param{ID}) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Cannot update contact. User '$Param{AssignedUserID}' is already assigned to contact '$ExistingContactID'.",
                );
                return;
            }
        }
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (qw(Firstname Lastname Email Title Phone Fax Mobile Street Zip City Country Comment ValidID AssignedUserID)) {
        next KEY if defined $Contact{$Key} && $Contact{$Key} eq $Param{$Key};
        $ChangeRequired = 1;
        last KEY;
    }

    my @DeleteOrgIDs;
    my @InsertOrgIDs;
    for my $OrgID (@{$Param{OrganisationIDs}}) {
        if (!grep ( /^$OrgID$/, @{$Contact{OrganisationIDs}})) {
            push(@InsertOrgIDs, $OrgID);
        }
    }
    for my $OrgID (@{$Contact{OrganisationIDs}}) {
        if (!grep ( /^$OrgID$/, @{$Param{OrganisationIDs}})) {
            push(@DeleteOrgIDs, $OrgID);
        }
    }

    $ChangeRequired = 1 if (
        $Param{PrimaryOrganisationID} &&
        (!$Contact{PrimaryOrganisationID} || $Param{PrimaryOrganisationID} != $Contact{PrimaryOrganisationID})
    );

    $ChangeRequired = 1 if (@DeleteOrgIDs || @InsertOrgIDs);

    return 1 if !$ChangeRequired;

    # update contact in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE contact SET firstname = ?, lastname = ?, '
            . 'email = ?, title = ?, phone = ?, fax = ?, mobile = ?, street = ?, '
            . 'zip = ?, city = ?, country = ?, comments = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ?, user_id = ? WHERE id = ?',
        Bind => [
            \$Param{Firstname}, \$Param{Lastname},
            \$Param{Email}, \$Param{Title}, \$Param{Phone}, \$Param{Fax}, \$Param{Mobile}, \$Param{Street},
            \$Param{Zip}, \$Param{City}, \$Param{Country}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{AssignedUserID}, \$Param{ID}
        ],
    );

    # update organisation IDs
    if (@DeleteOrgIDs) {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => "DELETE FROM contact_organisation WHERE contact_id = ? AND org_id IN ( ${\(join ', ', @DeleteOrgIDs)} )",
            Bind => [ \$Param{ID} ],
        );
    }

    # remove duplicates
    @InsertOrgIDs = $Kernel::OM->Get('Main')->GetUnique(@InsertOrgIDs);
    for my $orgID (@InsertOrgIDs) {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'INSERT INTO contact_organisation (contact_id, org_id) VALUES (?,?)',
            Bind => [ \$Param{ID}, \$orgID ],
        );
    }

    # update Primary Org ID
    if (
        $Param{PrimaryOrganisationID} &&
        (!$Contact{PrimaryOrganisationID} || $Param{PrimaryOrganisationID} != $Contact{PrimaryOrganisationID})
    ) {
        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'UPDATE contact_organisation SET is_primary = 0 WHERE org_id = ? AND contact_id = ?',
            Bind => [ \$Contact{PrimaryOrganisationID}, \$Param{ID} ],
        );
        return if !$Kernel::OM->Get('DB')->Do(
            SQL  => 'UPDATE contact_organisation SET is_primary = 1 WHERE org_id = ? AND contact_id = ?',
            Bind => [ \$Param{PrimaryOrganisationID}, \$Param{ID} ],
        );
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'ContactUpdate',
        Data  => {
            NewData => \%Param,
            OldData => \%Contact,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Contact',
        ObjectID  => $Param{ID},
    );

    # update user valid if necessary (user is no agent/customer or contact is invalid = user is invalid)
    if (IsHashRefWithData(\%ExistingUser)) {
        my @ValidList = $Kernel::OM->Get('Valid')->ValidIDsGet();
        my $NewUserValid = (!$ExistingUser{IsAgent} && !$ExistingUser{IsCustomer})
            || (!grep { $Param{ValidID} == $_ } @ValidList) ? 2 : 1;
        if ($NewUserValid != $ExistingUser{ValidID}) {
            my $Success = $Kernel::OM->Get('User')->UserUpdate(
                %ExistingUser,
                ValidID      => $NewUserValid,
                ChangeUserID => 1,
            );
        }
    }

    return 1;
}

=item ContactSearch()

to search contacts

    # text search
    my %List = $ContactObject->ContactSearch(
        Search => '*some*', # also 'hans+huber' possible
        Valid  => 1,        # (optional) default 1
        Limit  => 100       # (optional)
    );

    # title search
    my %List = $ContactObject->ContactSearch(
        Title     => '*Sir*',
        Valid     => 1,                      # (optional) default 1
        Limit     => 100                     # (optional)
    );

    # firstname search
    my %List = $ContactObject->ContactSearch(
        Firstname => '*John*',
        Valid     => 1,                      # (optional) default 1
        Limit     => 100                     # (optional)
    );

    # lastname search
    my %List = $ContactObject->ContactSearch(
        Lastname  => '*Doe*',
        Valid     => 1,                      # (optional) default 1
        Limit     => 100                     # (optional)
    );

    # address data search (City Country Fax Mobil Phone Street Zip)
    my %List = $ContactObject->ContactSearch(
        City      => '*City*',               # or other attribute from above
        Valid     => 1,                      # (optional) default 1
        Limit     => 100                     # (optional)
    );

    # valid search
    my %List = $ContactObject->ContactSearch(
        ValidID   => [1,2],                  # if ValidId given, param Valid is ignored
        Limit     => 100                     # (optional)
    );

    # email search (exact match)
    my %List = $ContactObject->ContactSearch(
        EmailEquals => 'email@example.com',
        Valid       => 1,                      # (optional) default 1
        Limit       => 100                     # (optional)
    );

    # email search (like match)
    my %List = $ContactObject->ContactSearch(
        Email       => 'email*com',
        Valid       => 1,                      # (optional) default 1
        Limit       => 100                     # (optional)
    );

    # email list search (exact match)
    my %List = $ContactObject->ContactSearch(
        EmailIn => ['email1@example.com', 'email2@example.com']
        Valid   => 1,                      # (optional) default 1
        Limit   => 100                     # (optional)
    );

    # search by OrganisationID
    my %List = $ContactObject->ContactSearch(
        OrganisationID => 123
        Valid          => 1,                    # (optional) default 1
        Limit          => 100                   # (optional)
    );

    # search by multiple OrganisationIDs
    my %List = $ContactObject->ContactSearch(
        OrganisationIDs =>  [ 123, 456, 789 ]
        Valid           => 1,                    # (optional) default 1
        Limit           => 100                   # (optional)
    );

    #search by UserID
    my %List = $ContactObject->ContactSearch(
        UserID         => 123,
        Valid          => 1,                    # (optional) default 1
        Limit          => 100                   # (optional)
    );

    #search by AssignedUserID
    my %List = $ContactObject->ContactSearch(
        AssignedUserID => 123,
        Valid          => 1,                    # (optional) default 1
        Limit          => 100                   # (optional)
    );

    #search by UserLogin
    my %List = $ContactObject->ContactSearch(
        Login          => '*some_user_login*',
        Valid          => 1,                    # (optional) default 1
        Limit          => 100                   # (optional)
    );

    #search by UserLogin (exact match)
    my %List = $ContactObject->ContactSearch(
        LoginEquals    => 'some_user_login,
        Valid          => 1,                    # (optional) default 1
        Limit          => 100                   # (optional)
    );

=cut

sub ContactSearch {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Cache');
    my $ValidObject = $Kernel::OM->Get('Valid');
    my $DBObject    = $Kernel::OM->Get('DB');

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = "ContactSearch::${Valid}::";
    foreach my $Key (
        qw(
            OrganisationIDs OrganisationID AssignedUserID UserID
            Search Limit Login LoginEquals
            EmailEquals Email EmailIn DynamicField
            Title Firstname Lastname
            City Country Fax Mobil Phone Street Zip
            ValidID
            PostMasterSearch
        )
    ) {
        my $CacheStrg;
        if (
            $Key eq 'DynamicField'
            && ref( $Param{ $Key } ) eq 'HASH'
        ) {
            $CacheStrg = ( $Param{ $Key }->{Field} // '' )
                        . q{;}
                        . ( $Param{ $Key }->{Operator} // '' )
                        . q{;};
            if ( defined( $Param{ $Key }->{Value} ) ) {
                $CacheStrg .= $Kernel::OM->Get('JSON')->Encode(
                    Data => $Param{ $Key }->{Value},
                );
            }
        }
        elsif ( IsArrayRefWithData($Param{$Key}) ) {
            $CacheStrg = join( q{,} , @{$Param{$Key}});
        }
        else {
            $CacheStrg = $Param{$Key};
        }
        $CacheKey .= q{::} . ($CacheStrg  || q{});
    }

    my $Data = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Data} if ref $Data eq 'HASH';

    # add valid option if required
    my $Where;
    my @Bind;
    my $Join = q{};

    if ( IsArrayRefWithData($Param{ValidID}) ) {
        $Where .= "c.valid_id IN ( ${\(join ', ', @{$Param{ValidID}})} )";
    } elsif ($Valid) {
        $Where .= "c.valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )";
    }

    # where
    if ( $Param{Search} ) {
        $Join = 'LEFT JOIN users u ON c.user_id = u.id';
        $Join .= ' LEFT JOIN contact_organisation co ON c.id = co.contact_id';
        $Join .= ' LEFT JOIN organisation o ON o.id = co.org_id';

        my $AddWildcards = 1 if ($Param{Search} =~ m/^\*.+\*$/);
        my @OrCombinedGroups = split( /\|/, $Param{Search});

        if ( defined $Where ) {
            $Where .= " AND ";
        }

        my @ORParts;
        for my $OrCombined (@OrCombinedGroups) {
            my @Parts = split(/\+/, $OrCombined, 6);

            # allow phone numbers with + (e.g. +49123456789*, also single leading * should be ingored)
            if ($Param{Search} =~ m/^\*?\+/) {
                $Parts[1] =  "+$Parts[1]";
                shift(@Parts);
            }

            my @ANDParts;

            for my $Part (@Parts) {
                if ($AddWildcards) {
                    $Part = "*$Part*";
                }
                $Part =~ s/\*/%/g;
                $Part =~ s/%%/%/g;

                my @WhereParts;
                for my $Field ( qw(firstname lastname email title phone fax mobile street zip city country) ) {
                    push(@WhereParts, "$Self->{Lower}(c.$Field) LIKE $Self->{Lower}(?)");
                    push(@Bind, \$Part);
                }

                push(@WhereParts, "$Self->{Lower}(u.login) LIKE $Self->{Lower}(?)");
                push(@Bind, \$Part);

                push(@WhereParts, "$Self->{Lower}(o.number) LIKE $Self->{Lower}(?)");
                push(@Bind, \$Part);

                push(@WhereParts, "$Self->{Lower}(o.name) LIKE $Self->{Lower}(?)");
                push(@Bind, \$Part);

                if (@WhereParts) {
                    push(@ANDParts, '(' . join( ' OR ', @WhereParts ) . ')');
                }
            }

            push(@ORParts, '(' . join( ' AND ', @ANDParts ) . ')');
        }
        $Where .= '(' . join( ' OR ', @ORParts ) . ')';
    }
    elsif ( $Param{PostMasterSearch} || $Param{Email} ) {
        if ( defined $Where ) {
            $Where .= " AND ";
        }

        my $Email = $Param{Email} || $Param{PostMasterSearch}; # TODO: PostMasterSearch is deprecated
        $Email =~ s/\*/%/g;
        $Email =~ s/%%/%/g;

        $Where .= "$Self->{Lower}(c.email) LIKE $Self->{Lower}(?)";
        push(@Bind, \$Email);
    }
    elsif ( $Param{OrganisationID} ) {
        $Join = 'LEFT JOIN contact_organisation co ON c.id = co.contact_id';
        if ( defined $Where ) {
            $Where .= " AND ";
        }
        $Where .= "co.org_id = ?";
        push(@Bind, \$Param{OrganisationID});
    }
    elsif ( $Param{OrganisationIDs} && IsArrayRefWithData($Param{OrganisationIDs}) ) {
        $Join = 'LEFT JOIN contact_organisation co ON c.id = co.contact_id';
        if ( defined $Where ) {
            $Where .= " AND ";
        }
        my @BindVars;
        foreach my $OrgID ( @{$Param{OrganisationIDs}} ) {
            push(@BindVars, '?');
            push(@Bind, \$OrgID);
        }
        $Where .= "(co.org_id IN ( " . join(q{,}, @BindVars) . " ))";
    }
    elsif ($Param{AssignedUserID}) {
        if (defined $Where) {
            $Where .= " AND ";
        }
        $Where .= "c.user_id = ?";
        push(@Bind, \$Param{AssignedUserID}) if $Param{AssignedUserID};
    }
    elsif ($Param{UserID}) {
        if (defined $Where) {
            $Where .= " AND ";
        }
        $Where .= "c.user_id = ?";
        push(@Bind, \$Param{UserID}) if $Param{UserID};
    }
    elsif ($Param{EmailEquals}) {

        if ( defined $Where ) {
            $Where .= " AND ";
        }

        $Where .= "$Self->{Lower}(c.email) = $Self->{Lower}(?)";
        push(@Bind, \$Param{EmailEquals});
    }
    elsif ($Param{EmailIn}) {

        if ( defined $Where ) {
            $Where .= " AND ";
        }

        if (!IsArrayRefWithData($Param{EmailIn})) {
            $Param{EmailIn} = [$Param{EmailIn}];
        }

        my @BindVars;
        foreach my $Mail ( @{$Param{EmailIn}} ) {
            push(@BindVars, '?');
            push(@Bind, \$Mail);
        }
        $Where .= "(c.email IN ( " . join(',', @BindVars) . " ))";
    }
    elsif ($Param{Login}) {
        $Join = 'LEFT JOIN users u ON c.user_id = u.id';

        my $Login = $Param{Login};
        $Login =~ s/\*/%/g;
        $Login =~ s/%%/%/g;

        if ( defined $Where ) {
            $Where .= " AND ";
        }

        $Where .= "$Self->{Lower}(u.login) LIKE $Self->{Lower}(?)";
        push(@Bind, \$Login);
    }
    elsif ($Param{LoginEquals}) {
        $Join = 'LEFT JOIN users u ON c.user_id = u.id';

        if ( defined $Where ) {
            $Where .= " AND ";
        }

        $Where .= "$Self->{Lower}(u.login) = $Self->{Lower}(?)";
        push(@Bind, \$Param{LoginEquals});
    }
    elsif (
        $Param{DynamicField}
        && IsHashRefWithData($Param{DynamicField})
    ) {
        if (defined $Where) {
            $Where .= " AND ";
        }

        my $SQLReturn = $Self->_SearchInDynamicField(
            Search       => $Param{DynamicField},
            BoolOperator => 'AND',
            JoinCounter  => '0'
        );

        $Join  .= join( q{ }, @{$SQLReturn->{SQLJoin}});
        $Where .= join( ' AND ', @{$SQLReturn->{SQLWhere}});
    }

    my %AttributMapping = (
        Title     => 'c.title',
        Firstname => 'c.firstname',
        Lastname  => 'c.lastname',
        City      => 'c.city',
        Country   => 'c.country',
        Fax       => 'c.fax',
        Mobil     => 'c.mobile',
        Phone     => 'c.phone',
        Street    => 'c.street',
        Zip       => 'c.zip'
    );

    for my $Attribute ( qw(Title Firstname Lastname City Country Fax Mobil Phone Street Zip) ) {
        if ($Param{$Attribute}) {
            if ( defined $Where ) {
                $Where .= " AND ";
            }

            my $AttributeValue = $Param{$Attribute};
            $AttributeValue =~ s/\*/%/g;
            $AttributeValue =~ s/%%/%/g;

            $Where .= "$Self->{Lower}($AttributMapping{$Attribute}) LIKE $Self->{Lower}(?)";
            push(@Bind, \$AttributeValue);
        }
    }

    my $SQL = "SELECT DISTINCT c.id, c.email, c.lastname, c.firstname FROM contact c $Join ";
    if ( $Where ) {
        $SQL .= "WHERE ".$Where;
    }
    $SQL .= ' ORDER BY c.lastname, c.firstname';

    # ask database
    $DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Param{Limit},
    );

    # fetch the result
    my %List;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $List{$Row[0]} = $Row[1];
    }

    # cache request
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%List,
        TTL   => $Self->{CacheTTL},
    );

    return %List;
}

=item ContactDelete()

delete a contact

    my $Success = $ContactObject->ContactDelete(
        ID => 123,
    );

=cut

sub ContactDelete {
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

    # delete preferences (foreign key)
    $Self->{PreferencesObject}->DeleteAllPreferencesForContact(
        ContactID => $Param{ID}
    );

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get all dynamic fields for this object type
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Contact',
        Valid      => 0,
    );

    # delete dynamicfield values for this contact
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

        next DYNAMICFIELD if !$DynamicFieldConfig;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
        next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );

        $DynamicFieldBackendObject->ValueDelete(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{ID},
            UserID             => $Param{UserID},
            NoPostHandling     => 1,                # we will delete the contact, so no additional handling needed when deleting the DF values
        );
    }

    # delete assignment to organisations
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM contact_organisation WHERE contact_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete contact
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM contact WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Contact',
        ObjectID  => $Param{ID},
    );

    return 1;
}


=item SetPreferences()

set contact preferences

    $ContactObject->SetPreferences(
        ContactID => 123,
        Key       => 'UserComment',
        Value     => 'some comment',
    );

=cut

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ContactID!'
        );
        return;
    }

    # check if contact exists
    my %Contact = $Self->ContactGet( ID => $Param{ContactID} );
    if ( !%Contact ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such contact '$Param{ContactID}'!",
        );
        return;
    }

    my $Result = $Self->{PreferencesObject}->SetPreferences(%Param);

    # trigger event handler
    if ($Result) {
        $Self->EventHandler(
            Event => 'ContactSetPreferences',
            Data  => {
                %Param,
                ContactData => \%Contact,
                Result   => $Result,
            },
            UserID => 1,
        );
    }

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Contact.Preference',
        ObjectID  => $Param{ContactID}.'::'.$Param{Key},
    );

    return $Result;
}

=item GetPreferences()

get customer user preferences

    my %Preferences = $ContactObject->GetPreferences(
        ContactID => 123,
    );

=cut

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ContactID!'
        );
        return;
    }

    # check if contact exists
    my %Contact = $Self->ContactGet( ID => $Param{ContactID} );
    if ( !%Contact ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such contact '$Param{ContactID}'!",
        );
        return;
    }

    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

=item SearchPreferences()

search in user preferences

    my %UserList = $ContactObject->SearchPreferences(
        Key   => 'UserSomeKey',
        Value => 'SomeValue',   # optional, limit to a certain value/pattern
    );

=cut

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    return $Self->{PreferencesObject}->SearchPreferences(%Param);
}

=item TokenGenerate()

generate a random token

    my $Token = $UserObject->TokenGenerate(
        ContactID => 123,
    );

=cut

sub TokenGenerate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ContactID!"
        );
        return;
    }

    my $Token = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length => 14,
    );

    # save token in preferences
    $Self->SetPreferences(
        Key    => 'UserToken',
        Value  => $Token,
        ContactID => $Param{ContactID},
    );

    return $Token;
}

=item TokenCheck()

check password token

    my $Valid = $UserObject->TokenCheck(
        Token  => $Token,
        ContactID => 123,
    );

=cut

sub TokenCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Token} || !$Param{ContactID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Token and ContactID!"
        );
        return;
    }

    # get preferences token
    my %Preferences = $Self->GetPreferences(
        ContactID => $Param{ContactID},
    );

    # check requested vs. stored token
    return if !$Preferences{UserToken};
    return if $Preferences{UserToken} ne $Param{Token};

    # reset password token
    $Self->SetPreferences(
        Key    => 'UserToken',
        Value  => '',
        ContactID => $Param{ContactID},
    );

    return 1;
}

=item ContactList()

return a hash with all contacts

    my %List = $ContactObject->ContactList(
        Valid         => 1,       # default 1
    );

=cut

sub ContactList {
    my ($Self, %Param) = @_;

    # set valid option
    my $Valid = $Param{Valid} // 1;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check cache
    my $CacheKey = join '::', 'ContactList', $Valid;
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = "SELECT c.id, c.firstname, c.lastname, c.email, c.user_id FROM contact c ";

    # sql query
    if ($Valid) {
        $SQL
            .= " WHERE c.valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet())} )";
    }
    $SQL .= ' ORDER BY c.lastname, c.firstname';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(SQL => $SQL);

    # fetch the result
    my %ContactsRaw;
    my %Contacts;
    while (my @Row = $DBObject->FetchrowArray()) {
        $ContactsRaw{ $Row[0] } = \@Row;
    }

    for my $CurrentUserID (sort keys %ContactsRaw) {
        $Contacts{$CurrentUserID} = $ContactsRaw{$CurrentUserID}->[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Contacts,
    );

    return %Contacts;
}

=begin Internal

=item _ContactFullname()

Returns a contacts full name.

    my $Fullname = $Object->_ContactFullname (
        Firstname => 'Test',
        Lastname  => 'Contact',
        UserLogin => 'some_user_login',  # optional
        NameOrder => 0,                  # optional 0,1,2,3,4,5,6,7,8
    );

=cut

sub _ContactFullname {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Firstname Lastname)) {
        if (!$Param{$Needed}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $FirstnameLastNameOrder = $Param{NameOrder} || 0;

    my $ContactFullname;
    if ($FirstnameLastNameOrder eq '0') {
        $ContactFullname = $Param{Firstname} . ' '
            . $Param{Lastname};
    }
    elsif ($FirstnameLastNameOrder eq '1') {
        $ContactFullname = $Param{Lastname} . ', '
            . $Param{Firstname};
    }
    elsif ($FirstnameLastNameOrder eq '2') {
        $ContactFullname = $Param{Firstname} . ' '
            . $Param{Lastname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ($FirstnameLastNameOrder eq '3') {
        $ContactFullname = $Param{Lastname} . ', '
            . $Param{Firstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ($FirstnameLastNameOrder eq '4') {
        $ContactFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{Firstname}
            . ' ' . $Param{Lastname};
    }
    elsif ($FirstnameLastNameOrder eq '5') {
        $ContactFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{Lastname}
            . ', ' . $Param{Firstname};
    }
    elsif ($FirstnameLastNameOrder eq '6') {
        $ContactFullname = $Param{Lastname} . ' '
            . $Param{Firstname};
    }
    elsif ($FirstnameLastNameOrder eq '7') {
        $ContactFullname = $Param{Lastname} . ' '
            . $Param{Firstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ($FirstnameLastNameOrder eq '8') {
        $ContactFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{Lastname}
            . ' ' . $Param{Firstname};
    }
    return $ContactFullname;
}

sub _SearchInDynamicField {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $LogObject                 = $Kernel::OM->Get('Log');
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # validate operator
    my %OperatorMap = (
        'EQ'         => 'Equals',
        'LIKE'       => 'Like',
        'GT'         => 'GreaterThan',
        'GTE'        => 'GreaterThanEquals',
        'LT'         => 'SmallerThan',
        'LTE'        => 'SmallerThanEquals',
        'IN'         => 'Like',
        'CONTAINS'   => 'Like',
        'STARTSWITH' => 'StartsWith',
        'ENDSWITH'   => 'EndsWith',
    );
    if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    if ( !$Self->{DynamicFields} ) {

        # get all configured dynamic fields
        my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => ['Contact'],
        );
        if ( !IsArrayRefWithData($DynamicFieldList) ) {
            # we don't have any  DFs
            return {
                SQLJoin  => [],
                SQLWhere => [],
            };
        }
        $Self->{DynamicFields} = { map { $_->{Name} => $_ } @{$DynamicFieldList} };
    }

    my $DFName = $Param{Search}->{Field};
    $DFName =~ s/DynamicField_//gsm;

    my $DynamicFieldConfig = $Self->{DynamicFields}->{$DFName};

    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => "DynamicField '$DFName' doesn't exist or is disabled. Ignoring it.",
        );
        # return empty result
        return {
            SQLJoin  => [],
            SQLWhere => [],
        };
    }

    my $Value = $Param{Search}->{Value};
    if ( !IsArrayRefWithData($Value) ) {
        $Value = [ $Value ];
    }
    foreach my $ValueItem ( @{$Value} ) {
        $Value =~ s/\*/%/g;
    }

    # increase count
    my $Count = $Param{JoinCounter}++;

    # join tables
    my $JoinTable = "dfv$Count";
    if ( $DynamicFieldConfig->{ObjectType} eq 'Contact' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, "LEFT JOIN dynamic_field_value $JoinTable ON (CAST(c.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        } else {
            push( @SQLJoin, "INNER JOIN dynamic_field_value $JoinTable ON (CAST(c.id AS char(255)) = CAST($JoinTable.object_id AS char(255)) AND $JoinTable.field_id = " . $DynamicFieldConfig->{ID} . ") " );
        }
    }

    my $DynamicFieldSQL;
    foreach my $ValueItem ( @{$Value} ) {
        # validate data type
        my $ValidateSuccess = $DynamicFieldBackendObject->ValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $ValueItem,
            SearchValidation   => 1,
            UserID             => 1,
        );

        if ( !$ValidateSuccess ) {
            $LogObject->Log(
                Priority => 'error',
                Message  =>
                    "Search not executed due to invalid value '"
                    . $ValueItem
                    . "' on field '"
                    . $DFName
                    . "'!",
            );
            return;
        }

        # get field specific SQL
        my $SQL = $DynamicFieldBackendObject->SearchSQLGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            TableAlias         => $JoinTable,
            Operator           => $OperatorMap{$Param{Search}->{Operator}},
            SearchTerm         => $ValueItem,
        );

        if ( $DynamicFieldSQL ) {
            $DynamicFieldSQL .= " OR ";
        }
        $DynamicFieldSQL .= "($SQL)";
    }

    # add field specific SQL
    push( @SQLWhere, "($DynamicFieldSQL)" );

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };
}

=end Internal

=cut
sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

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
