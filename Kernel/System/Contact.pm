# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Contact;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Organisation',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Time',
    'Kernel::System::User',
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
    my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # load generator contact preferences module
    my $GeneratorModule = $ConfigObject->Get('ContactPreferences')->{Module}
        || 'Kernel::System::Contact::Preferences::DB';

    if ( $MainObject->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new();
    }

    $Self->{CacheType} = 'Contact';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'Contact::EventModulePost',
    );


    return $Self;
}

=item ContactAdd()

add a new contact

    my $ID = $ContactObject->ContactAdd(
        Login      => 'mhuber',
        Firstname  => 'Huber',
        Lastname   => 'Manfred',
        Email      => 'email@example.com',
        PrimaryOrganisationID => 123,
        OrganisationIDs => [
            123,
            456
        ],
        Title      => 'Dr.',                    # optional
        Password   => 'some-pass',              # optional
        Phone      => '123456789',              # optional
        Fax        => '123456789',              # optional
        Mobile     => '123456789',              # optional
        Street     => 'Somestreet 123',         # optional
        Zip        => '12345',                  # optional
        City       => 'Somewhere',              # optional
        Country    => 'Somecountry',            # optional
        Comment    => 'some comment',           # optional
        ValidID    => 1,
        UserID     => 123,
    );

=cut

sub ContactAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Firstname Lastname PrimaryOrganisationID OrganisationIDs)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $Password = $Self->_EncryptPassword(
        Login    => $Param{Login},
        Password => $Param{Password} || $Self->_GenerateRandomPassword()
    );    
    my $OrganisationIDs = ','.join(',', @{$Param{OrganisationIDs}}).',';

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "INSERT INTO contact "
             . "(login, password, firstname, lastname, email, primary_org_id, org_ids, title, "
             . "phone, fax, mobile, street, zip, city, country, comments, valid_id, "
             . "create_time, create_by, change_time, change_by) "
             . "VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{Login}, \$Password, \$Param{Firstname}, \$Param{Lastname}, \$Param{Email},
            \$Param{PrimaryOrganisationID}, \$OrganisationIDs, \$Param{Title}, 
            \$Param{Phone}, \$Param{Fax}, \$Param{Mobile}, \$Param{Street},
            \$Param{Zip}, \$Param{City}, \$Param{Country}, \$Param{Comment}, 
            \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message =>
            "Contact: '$Param{Login}/$Param{Firstname}/$Param{Lastname}' created successfully ($Param{UserID})!",
    );

    # find ID of new item
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM contact WHERE login = ?',
        Bind  => [ 
            \$Param{Login} 
        ],
        Limit => 1,
    );

    # fetch the result
    my $ContactID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ContactID = $Row[0];
    }

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );    

    # trigger event
    $Self->EventHandler(
        Event => 'ContactAdd',
        Data  => {
            ID      => $ContactID,
            NewData => \%Param,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Contact',
        ObjectID  => $ContactID,
    );

    # return data
    return $ContactID;
}

=item ContactGet()

get contact data (Login, Firstname, Lastname, Email, ...)

    my %Contact = $ContactObject->ContactGet(
        ID => 123
    );

=cut

sub ContactGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need ID!"
        );
        return;
    }

    # check cache
    my $CacheKey = "ContactGet::$Param{ID}";
    my $Data = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Data} if ref $Data eq 'HASH';

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, login, firstname, lastname, primary_org_id, org_ids, email, '
             . 'title, phone, fax, mobile, street, zip, city, country, comments, valid_id, '
             . 'create_time, create_by, change_time, change_by FROM contact WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    # fetch the result
    my %Contact;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {

        my @OrganisationIDs = split(',', $Row[5]);
        
        # remove dummy
        pop @OrganisationIDs;

        $Contact{ID}                    = $Row[0];
        $Contact{Login}                 = $Row[1];
        $Contact{Firstname}             = $Row[2];
        $Contact{Lastname}              = $Row[3];
        $Contact{PrimaryOrganisationID} = $Row[4];
        $Contact{OrganisationIDs}       = \@OrganisationIDs;
        $Contact{Email}                 = $Row[6];
        $Contact{Title}                 = $Row[7];
        $Contact{Phone}                 = $Row[8];
        $Contact{Fax}                   = $Row[9];
        $Contact{Mobile}                = $Row[10];
        $Contact{Street}                = $Row[11];
        $Contact{Zip}                   = $Row[12];
        $Contact{City}                  = $Row[13];
        $Contact{Country}               = $Row[14];
        $Contact{Comment}               = $Row[15] || '';
        $Contact{ValidID}               = $Row[16];
        $Contact{CreateTime}            = $Row[17];
        $Contact{CreateBy}              = $Row[18];
        $Contact{ChangeTime}            = $Row[19];
        $Contact{ChangeBy}              = $Row[20];
    }

    # check item
    if ( !$Contact{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Contact with ID $Param{ID} not found in database!",
        );
        return;
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Contact,
    );

    return %Contact;
}

=item ContactUpdate()

update contact attributes

    my $Success = $ContactObject->ContactUpdate(
        ID         => 123,
        Login      => 'mhuber',
        Firstname  => 'Huber',
        Lastname   => 'Manfred',
        Email      => 'email@example.com',
        PrimaryOrganisationID => 123,
        OrganisationIDs => [
            123,
            456
        ],
        Title      => 'Dr.',
        Password   => 'some-pass',
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
    );

=cut

sub ContactUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ( $Param{Password} ) {
        $Param{Password} = $Self->_EncryptPassword(
            Login    => $Param{Login},
            Password => $Param{Password} || $Self->GenerateRandomPassword()
        );
    }
    if ( $Param{OrganisationIDs} ) {
        $Param{OrganisationIDs} = ','.join(',', $Param{OrganisationIDs}).',';
    }

    # check if contact exists
    my %Contact = $Self->ContactGet( 
        ID => $Param{ID} 
    );
    if ( !%Contact ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such contact with ID $Param{ID}!",
        );
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (qw(Login Firstname Lastname PrimaryOrganisationID OrganisationIDs Email Title 
                    Phone Fax Mobile Password Street Zip City Country Comment ValidID)) {

        next KEY if defined $Contact{$Key} && $Contact{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    # update role in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE Contact SET login = ?, password = ?, firstname = ?, lastname = ?, '
            . 'email = ?, title = ?, phone = ?, fax = ?, mobile = ?, street = ?, '
            . 'zip = ?, city = ?, country = ?, comments = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Login}, \$Param{Password}, \$Param{Firstname}, \$Param{Lastname}, 
            \$Param{Email}, \$Param{Title}, \$Param{Phone}, \$Param{Fax}, \$Param{Mobile},
            \$Param{Street}, \$Param{Zip}, \$Param{City}, \$Param{Country},
            \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
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
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Contact',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item ContactSearch()

to search contacts

    # text search
    my %List = $ContactObject->ContactSearch(
        Search => '*some*', # also 'hans+huber' possible
        Valid  => 1,        # (optional) default 1
        Limit  => 100,      # (optional) overrides limit of the config
    );

    # username search
    my %List = $ContactObject->ContactSearch(
        Login => '*some*',
        Valid     => 1,         # (optional) default 1
    );

    # email search
    my %List = $ContactObject->ContactSearch(
        PostMasterSearch => 'email@example.com',
        Valid            => 1,                    # (optional) default 1
    );

    # search by CustomerID
    my %List = $ContactObject->ContactSearch(
        OrganisationID => 123,
        Valid          => 1,                # (optional) default 1
    );

=cut

sub ContactSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = "ContactSearch::${Valid}::";
    foreach my $Key ( qw(Login OrganisationID Search PostMasterSearch Limit) ) {
        $CacheKey .= '::'.($Param{$Key} || '');
    }
    my $Data = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Data} if ref $Data eq 'HASH';

    # add valid option if required
    my $SQL;
    my @Bind;

    if ($Valid) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

        $SQL .= "valid_id IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )";
    }

    # where
    if ( $Param{Search} ) {

        my @Parts = split /\+/, $Param{Search}, 6;
        for my $Part (@Parts) {
            $Part = '*' . $Part . '*';
            $Part =~ s/\*/%/g;
            $Part =~ s/%%/%/g;

            if ( defined $SQL ) {
                $SQL .= " AND ";
            }

            my @SQLParts;
            for my $Field ( qw(login firstname lastname email title phone fax mobile street zip city country) ) {
                if ( $Self->{CaseSensitive} ) {
                    push(@SQLParts, "$Field LIKE ?");
                    push(@Bind, \$Part);
                }
                else {
                    push(@SQLParts, "LOWER($Field) LIKE LOWER(?)");
                    push(@Bind, \$Part);
                }
            }
            if (@SQLParts) {
                $SQL .= '(' . join( ' OR ', @SQLParts ) . ')';
            }
        }
    }
    elsif ( $Param{PostMasterSearch} ) {

        if ( defined $SQL ) {
            $SQL .= " AND ";
        }

        my $Email = $Param{PostMasterSearch};
        $Email =~ s/\*/%/g;
        $Email =~ s/%%/%/g;

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "Email LIKE ?";
            push(@Bind, \$Email);
        }
        else {
            $SQL .= "LOWER(email) LIKE LOWER(?)";
            push(@Bind, \$Email);
        }
    }
    elsif ( $Param{Login} ) {

        if ( defined $SQL ) {
            $SQL .= " AND ";
        }

        my $Login = $Param{Login};
        $Login =~ s/\*/%/g;
        $Login =~ s/%%/%/g;

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "login LIKE ?";
            push(@Bind, \$Login);
        }
        else {
            $SQL .= "LOWER(login) LIKE LOWER(?)";
            push(@Bind, \$Login);
        }
    }
    elsif ( $Param{OrganisationID} ) {

        if ( defined $SQL ) {
            $SQL .= " AND ";
        }

        $SQL .= "(primary_org_id = ? OR org_ids LIKE '%,'||?||',%')";
        push(@Bind, \$Param{OrganisationID});
        push(@Bind, \$Param{OrganisationID});
    }

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => "SELECT id, login FROM contact " . ($SQL ? "WHERE $SQL" : ''),
        Bind  => \@Bind,
        Limit => $Param{Limit},
    );

    # fetch the result
    my %List;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $List{$Row[0]} = $Row[1];
    }

    # cache request
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM contact WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ContactID!'
        );
        return;
    }

    # check if contact exists
    my %Contact = $Self->ContactGet( ID => $Param{ContactID} );
    if ( !%Contact ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ContactID!'
        );
        return;
    }

    # check if contact exists
    my %Contact = $Self->ContactGet( ID => $Param{ContactID} );
    if ( !%Contact ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need ContactID!"
        );
        return;
    }

    my $Token = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
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


=item SetPassword()

set new password

    my $Success = $ContactObject->SetPassword(
        ID       => 123,
        Password => 'somepassword'
        UserID   => 1,
    );

=cut

sub SetPassword {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Password UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my %Contact = $Self->ContactGet(
        ID => $Param{ID}
    );

    if ( !%Contact ) {
        return;
    }

    my $Password = $Self->_EncryptPassword(
        Login    => $Contact{Login},
        Password => $Param{Password}
    );    

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "UPDATE contact SET password = ?, change_by = ?, change_time = current_timestamp WHERE id = ?",
        Bind => [ \$Password, \$Param{UserID}, \$Param{ID} ],
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "Contact: '$Contact{Login}' changed password successfully!",
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return 1;
}

=item GenerateRandomPassword()

generate a random password

    my $RandomPw = $ContactObject->GenerateRandomPassword(
        Size => 12              # optional, default is 8
    );

=cut

sub GenerateRandomPassword {
    my ( $Self, %Param ) = @_;

    # generated passwords are eight characters long by default
    my $Size = $Param{Size} || 8;

    my $Password = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => $Size,
    );

    return $Password;
}

=item _EncryptPassword()

encrypt the given password

    my $CryptedPw = $ContactObject->_EncryptPassword(
        Login    => '...',
        Password => '...',
    );

=cut

sub _EncryptPassword {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Password)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $Login = $Param{Login};
    my $Pw    = $Param{Password} || '';

    my $CryptedPw = '';

    # get crypt type
    my $CryptType = $Kernel::OM->Get('Kernel::Config')->Get('Contact::AuthModule::DB::CryptType') || 'sha2';

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    # crypt plain (no crypt at all)
    if ( $CryptType eq 'plain' ) {
        $CryptedPw = $Pw;
    }

    # crypt with unix crypt
    elsif ( $CryptType eq 'crypt' ) {

        # encode output, needed by crypt() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );
        $EncodeObject->EncodeOutput( \$Login );

        $CryptedPw = crypt( $Pw, $Login );
        $EncodeObject->EncodeInput( \$CryptedPw );
    }

    # crypt with md5 crypt
    elsif ( $CryptType eq 'md5' || !$CryptType ) {

        # encode output, needed by unix_md5_crypt() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );
        $EncodeObject->EncodeOutput( \$Login );

        $CryptedPw = unix_md5_crypt( $Pw, $Login );
        $EncodeObject->EncodeInput( \$CryptedPw );
    }

    # crypt with md5 crypt (compatible with Apache's .htpasswd files)
    elsif ( $CryptType eq 'apr1' ) {

        # encode output, needed by apache_md5_crypt() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );
        $EncodeObject->EncodeOutput( \$Login );

        $CryptedPw = apache_md5_crypt( $Pw, $Login );
        $EncodeObject->EncodeInput( \$CryptedPw );
    }

    # crypt with sha1
    elsif ( $CryptType eq 'sha1' ) {

        my $SHAObject = Digest::SHA->new('sha1');

        # encode output, needed by sha1_hex() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # bcrypt
    elsif ( $CryptType eq 'bcrypt' ) {

        # get main object
        my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

        if ( !$MainObject->Require('Crypt::Eksblowfish::Bcrypt') ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "Contact: '$Login' tried to store password with bcrypt but 'Crypt::Eksblowfish::Bcrypt' is not installed!",
            );
            return;
        }

        my $Cost = 9;
        my $Salt = $MainObject->GenerateRandomString( Length => 16 );

        # remove UTF8 flag, required by Crypt::Eksblowfish::Bcrypt
        $EncodeObject->EncodeOutput( \$Pw );

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

    # crypt with sha2 as fallback
    else {

        my $SHAObject = Digest::SHA->new('sha256');

        # encode output, needed by sha256_hex() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # need no pw to set
    return $CryptedPw;
}

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
