# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
use Kernel::System::EmailParser;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Cache
    ClientRegistragtion
    Config
    Contact
    Organisation
    DB
    DynamicField
    Log
    Main
    Time
    User
    Valid
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

    $Self->{CacheType}   = 'Contact';
    $Self->{OSCacheType} = 'ObjectSearch_Contact';
    $Self->{CacheTTL}    = 60 * 60 * 24 * 20;

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
        Email                 => 'email@example.com',      # optional, but will be set with something like "noreply-somethingRandom@nomail.com"
        Email1                => 'email1@example.com',     # optional
        Email2                => 'email2@example.com',     # optional
        Email3                => 'email3@example.com',     # optional
        Email4                => 'email4@example.com',     # optional
        Email5                => 'email5@example.com',     # optional
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
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # prepare emails
    for my $MailAttr ( qw(Email Email1 Email2 Email3 Email4 Email5) ) {
        if ($Param{$MailAttr}) {
            if ( $Kernel::OM->Get('Config')->Get('ContactEmailUniqueCheck') ) {
                my $ExistingContactID = $Self->ContactLookup(
                    Email  => $Param{$MailAttr},
                    Silent => 1
                );
                if ($ExistingContactID) {
                    return if $Param{Silent};
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Cannot add contact. Email \"$Param{$MailAttr}\" ($MailAttr) already exists.",
                    );
                    return;
                }
            }
        } else {
            $Param{$MailAttr} = '';
        }
    }

    # if no mail is given for a new contact, a random, but unique, dummy email address is generated.
    if (!$Param{Email}) {
        my $uuid = Data::UUID->new();
        $Param{Email} = "noreply-" . $uuid->to_hexstring($uuid->create()) . '@nomail.com';
    }

    # check if primary OrganisationID exists
    if ($Param{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $Param{PrimaryOrganisationID},
        );

        if (
            !%OrgData
            || $OrgData{ValidID} != 1
        ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'No valid organisation found for primary organisation ID "'
                    . $Param{PrimaryOrganisationID}
                    . q{".},
            );
            return;
        }
    }

    if (IsArrayRefWithData($Param{OrganisationIDs})) {
        # check if primary OrganisationID is contained in assigned OrganisationIDs
        if (
            defined $Param{PrimaryOrganisationID}
            && $Param{PrimaryOrganisationID}
            && !grep( {/$Param{PrimaryOrganisationID}/} @{$Param{OrganisationIDs}})
        ) {
            push(@{$Param{OrganisationIDs}}, $Param{PrimaryOrganisationID});
        }
        foreach my $OrgID (@{$Param{OrganisationIDs}}) {
            my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if (
                !%OrgData
                || $OrgData{ValidID} != 1
            ) {
                return if $Param{Silent};
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'No valid organisation found for assigned organisation ID "'
                        . $OrgID
                        . q{".},
                );
                return;
            }
        }

        if (
            !$Param{PrimaryOrganisationID}
            && $Param{OrganisationIDs}->[0]
        ) {
            $Param{PrimaryOrganisationID} = $Param{OrganisationIDs}->[0];
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
            return if $Param{Silent};
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
                return if $Param{Silent};
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Cannot create contact. User '$Param{AssignedUserID}' already has a contact.",
                );
                return;
            }
        }
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO contact (
                    firstname, lastname, email, email1, email2, email3, email4, email5,
                    title, phone, fax, mobile, street, zip, city, country, comments, valid_id,
                    create_time, create_by, change_time, change_by, user_id
            ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    current_timestamp, ?, current_timestamp, ?, ?)',
        Bind => [
            \$Param{Firstname}, \$Param{Lastname}, \$Param{Email}, \$Param{Email1}, \$Param{Email2}, \$Param{Email3}, \$Param{Email4}, \$Param{Email5},
            \$Param{Title}, \$Param{Phone}, \$Param{Fax},
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
            Message  => "Contact: $ContactID ('$Param{Firstname}/$Param{Lastname}') created successfully (created by user id $Param{UserID})!",
        );
        # reset cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType},
        );

        # reset cache object search
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{OSCacheType},
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
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'Contact',
            ObjectID  => $ContactID,
        );
    }
    elsif( !$Param{Silent} ) {
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
                . 'valid_id, create_time, create_by, change_time, change_by, user_id, email1, email2, email3, email4, email5 FROM contact ' . $SQLWhere,
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
        $Contact{Email1}                = $Row[19] || '';
        $Contact{Email2}                = $Row[20] || '';
        $Contact{Email3}                = $Row[21] || '';
        $Contact{Email4}                = $Row[22] || '';
        $Contact{Email5}                = $Row[23] || '';
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Contact with ID $Param{ID} not found in database!",
            );
        }
        return;
    }

    # check item
    if ( $Param{UserID} && !$Contact{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "No contact assigned to user id $Param{UserID}!",
            );
        }
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
        Silent => 1, # optional, don't generate log entry if contact was not found
    );

    my $ID = $ContactObject->ContactLookup(
        Email  => 'some_user_email',
        Silent => 1, # optional, don't generate log entry if contact was not found
        Valid  => 1  # optional, only valid contact, default 0
    );

    my $ID = $ContactObject->ContactLookup(
        UserID  => 123,
        Silent => 1, # optional, don't generate log entry if contact was not found
    );

    my $ID = $ContactObject->ContactLookup(
        UserLogin => 'some_login',
        Silent    => 1, # optional, don't generate log entry if contact was not found
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

    my $ValidSQL = '';
    my $ValidCachePart = '::Valid::' . ($Param{Valid} || 0);
    if ($Param{Valid}) {
        my $ValidID = $Kernel::OM->Get('Valid')->ValidLookup(
            Valid => 'valid'
        );

        if ($ValidID) {
            $ValidSQL = " AND c.valid_id = $ValidID ";
        } else {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Could not get ID of valid!'
                );
            }
            return;
        }
    }

    if ( $Param{Email}) {

        # check cache
        my $CacheKey = 'ContactLookup::Email::' . $Param{Email} . $ValidCachePart;
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        my $Email = lc $Param{Email};

        return if !$DBObject->Prepare(
            SQL   => "SELECT c.id FROM contact c WHERE ($Self->{Lower}(c.email) = ? OR $Self->{Lower}(c.email1) = ? OR $Self->{Lower}(c.email2) = ? OR $Self->{Lower}(c.email3) = ? OR $Self->{Lower}(c.email4) = ? OR $Self->{Lower}(c.email5) = ?) $ValidSQL ORDER BY c.lastname, c.firstname",
            Bind  => [ \$Email, \$Email, \$Email, \$Email, \$Email, \$Email ],
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
        my $CacheKey = 'ContactLookup::ID::' . $Param{ID} . $ValidCachePart;
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        return if !$DBObject->Prepare(
            SQL => "SELECT c.email FROM contact c WHERE c.id = ? $ValidSQL",
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
        my $CacheKey = 'ContactLookup::UserID::' . $Param{UserID} . $ValidCachePart;
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        return if !$DBObject->Prepare(
            SQL => "SELECT c.id FROM contact c WHERE c.user_id = ? $ValidSQL",
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
        my $CacheKey = 'ContactLookup::UserLogin::' . $Param{UserLogin} . $ValidCachePart;
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        my $UserLogin = lc $Param{UserLogin};

        return if !$DBObject->Prepare(
            SQL => "SELECT c.id FROM contact c, users u WHERE u.id = c.user_id AND $Self->{Lower}(u.login) = ? $ValidSQL",
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
        Email1     => 'email1@example.com',
        Email2     => 'email2@example.com',
        Email3     => 'email3@example.com',
        Email4     => 'email4@example.com',
        Email5     => 'email5@example.com',
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

    my %OrgaIDs;
    # check if primary OrganisationID exists
    if ($Param{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $Param{PrimaryOrganisationID},
        );

        if (
            !%OrgData
            || $OrgData{ValidID} != 1
        ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid organisation found for primary organisation ID \"$Param{PrimaryOrganisationID}\".",
            );
            return;
        }
        $OrgaIDs{$Param{PrimaryOrganisationID}} = 1;
    }

    if (IsArrayRefWithData($Param{OrganisationIDs})) {
        foreach my $OrgID (@{$Param{OrganisationIDs}}) {
            next if ($OrgaIDs{$OrgID});

            my %OrgData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if (
                !%OrgData
                || $OrgData{ValidID} != 1
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No valid organisation found for assigned organisation ID \"$OrgID\".",
                );
                return;
            }
            $OrgaIDs{$OrgID} = 1;
        }
    }

    # if assigned user is given, check associated user exists
    my %ExistingUser;
    if ($Param{AssignedUserID}) {
        my %ExistingUser = $Kernel::OM->Get('User')->GetUserData(
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

        # update user valid if necessary (user is no agent/customer or contact is invalid = user is invalid)
        my @ValidList = $Kernel::OM->Get('Valid')->ValidIDsGet();
        my $NewUserValid = (!$ExistingUser{IsAgent} && !$ExistingUser{IsCustomer})
            || (!grep { $Param{ValidID} == $_ } @ValidList) ? 2 : 1;
        if ($NewUserValid != $ExistingUser{ValidID}) {
            delete $ExistingUser{UserPw};
            my $Success = $Kernel::OM->Get('User')->UserUpdate(
                %ExistingUser,
                ValidID      => $NewUserValid,
                ChangeUserID => 1
            );
        }
    }

    # set default value
    $Param{Comment} ||= q{};

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (
        qw(
            Firstname Lastname
            Email Email1 Email2 Email3 Email4 Email5
            Title Phone Fax Mobile Street Zip City Country
            Comment ValidID AssignedUserID
        )
    ) {
        next KEY if (
            (
                !defined( $Contact{ $Key } )
                && !defined( $Param{ $Key } )
            )
            || (
                defined( $Contact{ $Key } )
                && defined( $Param{ $Key } )
                && $Contact{ $Key } eq $Param{ $Key }
            )
        );

        $ChangeRequired = 1;
        last KEY;
    }

    my $OldAssignedUserID;
    if ($Contact{AssignedUserID} && $Contact{AssignedUserID} != $Param{AssignedUserID}) {
        $OldAssignedUserID = $Contact{AssignedUserID};
    }

    my @DeleteOrgIDs;
    my @InsertOrgIDs;
    for my $OrgID (@{$Contact{OrganisationIDs}}) {
        next if ($OrgaIDs{$OrgID});
        push(@DeleteOrgIDs, $OrgID);
    }
    my %KnownIDs = map { $_ => 1 } @{$Contact{OrganisationIDs} || []};
    for my $OrgID ( keys %OrgaIDs ) {
        next if ($KnownIDs{$OrgID});
        push(@InsertOrgIDs, $OrgID);
    }

    $ChangeRequired = 1 if (
        $Param{PrimaryOrganisationID}
        && (
            !$Contact{PrimaryOrganisationID}
            || $Param{PrimaryOrganisationID} != $Contact{PrimaryOrganisationID}
        )
    );

    $ChangeRequired = 1 if (@DeleteOrgIDs || @InsertOrgIDs);

    return 1 if !$ChangeRequired;

    # update contact in database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE contact SET firstname = ?, lastname = ?, '
            . 'email = ?, email1 = ?, email2 = ?, email3 = ?, email4 = ?, email5 = ?, '
            . 'title = ?, phone = ?, fax = ?, mobile = ?, street = ?, '
            . 'zip = ?, city = ?, country = ?, comments = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ?, user_id = ? WHERE id = ?',
        Bind => [
            \$Param{Firstname}, \$Param{Lastname},
            \$Param{Email}, \$Param{Email1}, \$Param{Email2}, \$Param{Email3}, \$Param{Email4}, \$Param{Email5},
            \$Param{Title}, \$Param{Phone}, \$Param{Fax}, \$Param{Mobile}, \$Param{Street},
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

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'ContactUpdate',
        Data  => {
            ID      => $Param{ID},
            NewData => \%Param,
            OldData => \%Contact,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Contact',
        ObjectID  => $Param{ID},
    );

    # push client callback event for assigned user (contact include)
    if ($Param{AssignedUserID}) {
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'User',
            ObjectID  => $Param{AssignedUserID}
        );
    }
    if ($OldAssignedUserID) {
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'User',
            ObjectID  => $OldAssignedUserID
        );
    }

    return 1;
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

    # trigger event
    $Self->EventHandler(
        Event  => 'ContactDelete',
        Data   => {
            ID => $Param{ID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Contact',
        ObjectID  => $Param{ID},
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

    my $SQL = "SELECT c.id, c.firstname, c.lastname, c.email, c.email1, c.email2, c.email3, c.email4, c.email5, c.user_id FROM contact c ";

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

=item GetOrCreateID()

return a contact id for a given email. If no matching contact exists, new contact is created

    my $ContactID = $ContactObject->GetOrCreateID(
        Email                 => "\"Mustermann, Max\" <max.mustermann@example.com>",    # single email to parse
        UserID                => 1,
        ParserObject          => $ParserObject,                                         # optional. Standalone instance of Kernel::System::EmailParser
        PrimaryOrganisationID => 123,                                                   # optional. PrimaryOrganisationID to use when creating a new contact
    );

=cut
sub GetOrCreateID {

    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Email UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );

            return;
        }
    }

    # get parser object
    my $ParserObject;
    if ( defined( $Param{ParserObject} ) ) {
        $ParserObject = $Param{ParserObject};
    }
    else {
        $ParserObject = Kernel::System::EmailParser->new(
            Mode => 'Standalone',
        );
    }

    # parse email
    my $ContactEmail = $ParserObject->GetEmailAddress(
        Email => $Param{Email},
    );
    if ( !$ContactEmail ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not parse email from "' . $Param{Email} . '"!',
        );

        return;
    }

    # lookup existing valid contact
    my $ContactID = $Self->ContactLookup(
        Email  => $ContactEmail,
        Silent => 1,
        Valid  => 1
    );
    return $ContactID if ( $ContactID );

    # lookup existing invalid contact
    $ContactID = $Self->ContactLookup(
        Email  => $ContactEmail,
        Silent => 1
    );
    return $ContactID if ( $ContactID );

    # set email as fallback for firstname and lastname
    my $Firstname = $ContactEmail;
    my $Lastname  = $ContactEmail;

    # get and process realname part of given email
    my $ContactEmailRealname = $ParserObject->GetRealname(
        Email => $Param{Email},
    );
    if ( $ContactEmailRealname ) {
        # remove quotes
        $ContactEmailRealname =~ s/["']//g;

        # remove leading/trailing whitespace
        $ContactEmailRealname =~ s/^\s+|\s+$//g;

        # realname contains comma, use part before comma as lastname, part after as firstname
        if ( $ContactEmailRealname =~ m/^(.+)\s*,\s*(.+)$/ ) {
            $Firstname = $2;
            $Lastname  = $1;
        }
        # realname contains whitespace, use part before last whitespace as firstname, part after as lastname
        elsif ( $ContactEmailRealname =~ m/^(.+)\s+(.+?)$/ ) {
            $Firstname = $1;
            $Lastname  = $2;
        }
        # fallback: use realname as firstname and set dash to lastname
        else {
            $Firstname = $ContactEmailRealname;
            $Lastname  = '-';
        }
    }

    # create contact
    $ContactID = $Self->ContactAdd(
        Firstname             => $Firstname,
        Lastname              => $Lastname,
        Email                 => $ContactEmail,
        PrimaryOrganisationID => $Param{PrimaryOrganisationID},
        ValidID               => 1,
        UserID                => $Param{UserID},
    );
    if ( !$ContactID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Could not create contact for "' . $Param{Email} . '"!',
        );

        return;
    }

    return $ContactID;
}

=item GetAssignedContactsForObject()

return all assigned contact IDs

    my $ContactIDList = $ContactObject->GetAssignedContactsForObject(
        ObjectType   => 'Contact',
        Object       => $ContactHashRef,         # (optional)
        UserID       => 1,
        UserType     => 'Customer'               # 'Agent' | 'Customer'
    );

=cut

sub GetAssignedContactsForObject {
    my ( $Self, %Param ) = @_;

    my @AssignedContactIDs = ();

    my %SearchData = $Kernel::OM->Get('Main')->GetAssignedSearchParams(
        %Param,
        AssignedObjectType => 'Contact'
    );

    if (IsHashRefWithData(\%SearchData)) {
        my @ORSearch = map { { Field => $_, Operator => $_ eq 'IsCustomer' || $_ eq 'IsAgent' ? 'EQ' : 'IN', Value => $SearchData{$_} } } keys %SearchData;

        @AssignedContactIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Contact',
            Result     => 'ARRAY',
            Search     => {
                OR => \@ORSearch
            },
            UserID   => $Param{UserID},
            UserType => $Param{UserType},
            Silent   => $Param{Silent}
        );

        if ( IsArrayRefWithData(\@AssignedContactIDs) ) {
            @AssignedContactIDs = map { 0 + $_ } @AssignedContactIDs;
        }
    }

    return \@AssignedContactIDs;
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
