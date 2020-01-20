# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Organisation;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Organisation - organisation lib

=head1 SYNOPSIS

All Organisation functions. E.g. to add and update organisations.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $OrganisationObject = $Kernel::OM->Get('Kernel::System::Organisation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # load generator customer preferences module
    my $GeneratorModule = $ConfigObject->Get('OrganisationPreferences')->{Module}
        || 'Kernel::System::Organisation::Preferences::DB';

    if ( $MainObject->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new();
    }

    $Self->{CacheType} = 'Organisation';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'Organisation::EventModulePost',
    );

    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    return $Self;
}

=item OrganisationAdd()

add a new organisation

    my $ID = $OrganisationObject->OrganisationAdd(
        Number   => 'example.com',
        Name     => 'New Customer Inc.',
        Street   => '5201 Blue Lagoon Drive',    # optional
        Zip      => '33126',                     # optional
        City     => 'Miami',                     # optional
        Country  => 'USA',                       # optional
        Url      => 'http://www.example.org',    # optional
        Comment  => 'some comment',              # optional
        ValidID  => 1,                           # optional
        UserID   => 123,
    );

=cut

sub OrganisationAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Number Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "INSERT INTO organisation "
             . "(number, name, street, zip, city, country, "
             . "url, comments, valid_id, create_time, create_by, change_time, change_by) "
             . "VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{Number}, \$Param{Name}, \$Param{Street},
            \$Param{Zip}, \$Param{City}, \$Param{Country},
            \$Param{Url}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID}
        ],
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message =>
            "Organisation: '$Param{Name}/$Param{Number}' created successfully ($Param{UserID})!",
    );

    # find ID of new item
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM organisation WHERE number = ?',
        Bind  => [ 
            \$Param{Number} 
        ],
        Limit => 1,
    );

    # fetch the result
    my $OrgID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $OrgID = $Row[0];
    }

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );    

    # trigger event
    $Self->EventHandler(
        Event => 'OrganisationAdd',
        Data  => {
            ID      => $OrgID,
            NewData => \%Param,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Organisation',
        ObjectID  => $OrgID,
    );    

    # return data
    return $OrgID;
}

=item OrganisationGet()

get organisation attributes

    my %Organisation = $OrganisationObject->OrganisationGet(
        ID => 123,
    );

Returns:

    %Organisation = (
        'ID'         => 123,
        'Number'     => 'example.com',
        'Name'       => 'Customer Inc.',
        'Street'     => '5201 Blue Lagoon Drive',
        'Zip'        => '33126',
        'City'       => 'Miami',
        'Country'    => 'United States',
        'Url'        => 'http://example.com',
        'Comment'    => 'Some Comments',
        'ValidID'    => '1',
        'CreateTime' => '2010-10-04 16:35:49',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-10-04 16:36:12',
        'ChangeBy'   => 1,
    );

=cut

sub OrganisationGet {
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
    my $CacheKey = "OrganisationGet::$Param{ID}";
    my $Data = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Data} if ref $Data eq 'HASH';

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, number, name, street, zip, city, country, url, comments, valid_id, '
             . 'create_time, create_by, change_time, change_by FROM organisation WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    # fetch the result
    my %Organisation;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Organisation{ID}         = $Row[0];
        $Organisation{Number}     = $Row[1];
        $Organisation{Name}       = $Row[2];
        $Organisation{Street}     = $Row[3];
        $Organisation{Zip}        = $Row[4];
        $Organisation{City}       = $Row[5];
        $Organisation{Country}    = $Row[6];
        $Organisation{Url}        = $Row[7];
        $Organisation{Comment}    = $Row[8] || '';
        $Organisation{ValidID}    = $Row[9];
        $Organisation{CreateTime} = $Row[10];
        $Organisation{CreateBy}   = $Row[11];
        $Organisation{ChangeTime} = $Row[12];
        $Organisation{ChangeBy}   = $Row[13];
    }

    # check item
    if ( !$Organisation{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Organisation with ID $Param{ID} not found in database!",
        );
        return;
    }

    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Organisation,
    );

    return %Organisation;
}

=item OrganisationLookup()

contact id or login lookup

    my $Number = $OrganisationObject->OrganisationLookup(
        ID     => 1,
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $ID = $OrganisationObject->OrganisationLookup(
        Number => 'some_organisation_number',
        Silent => 1, # optional, don't generate log entry if user was not found
    );

=cut

sub OrganisationLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Number} && !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Number or ID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Param{Number} ) {

        # check cache
        my $CacheKey = 'OrganisationLookup::ID::' . $Param{Number};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        my $Number = lc $Param{Number};

        return if !$DBObject->Prepare(
            SQL => "SELECT id FROM organisation WHERE $Self->{Lower}(number) = ?",
            Bind  => [ \$Number ],
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
                    Message  => "No ID found for organisation number '$Param{Number}'!",
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

        # ignore non-numeric IDs
        return if $Param{ID} && $Param{ID} !~ /^\d+$/;

        # check cache
        my $CacheKey = 'OrganisationLookup::Number::' . $Param{ID};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        return if !$DBObject->Prepare(
            SQL => "SELECT number FROM organisation WHERE id = ?",
            Bind  => [ \$Param{ID} ],
            Limit => 1,
        );

        # fetch the result
        my $Number;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Number = $Row[0];
        }

        if ( !$Number ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No organisation number found for ID '$Param{ID}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $Number,
        );

        return $Number;
    }
}

=item OrganisationUpdate()

update organisation attributes

    $OrganisationObject->OrganisationUpdate(
        ID       => 123,
        Number   => 'example.com',
        Name     => 'New Customer Inc.',
        Street   => '5201 Blue Lagoon Drive',
        Zip      => '33126',
        Location => 'Miami',
        Country  => 'USA',
        Url      => 'http://example.com',
        Comment  => 'some comment',
        ValidID  => 1,
        UserID   => 123,
    );

=cut

sub OrganisationUpdate {
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

    # check if organisation exists
    my %Organisation = $Self->OrganisationGet( 
        ID => $Param{ID} 
    );
    if ( !%Organisation ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such organisation with ID $Param{ID}!",
        );
        return;
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (qw(Number Name Street Zip City Country Url Comment ValidID)) {

        next KEY if defined $Organisation{$Key} && $Organisation{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    # update role in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE organisation SET number = ?, name = ?, street = ?, '
            . 'zip = ?, city = ?, country = ?, url = ?, comments = ?, valid_id = ?, '
            . 'change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Number}, \$Param{Name}, \$Param{Street},
            \$Param{Zip}, \$Param{City}, \$Param{Country},
            \$Param{Url}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );    

    # trigger event
    $Self->EventHandler(
        Event => 'OrganisationUpdate',
        Data  => {
            NewData       => \%Param,
            OldData       => \%Organisation,
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Organisation',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item OrganisationSearch()

search organisations

    my %List = $OrganisationObject->OrganisationSearch();

    my %List = $OrganisationObject->OrganisationSearch(
        Valid => 0,
        Limit => 0,     # optional, override configured search result limit (0 means unlimited)
    );

    my %List = $OrganisationObject->OrganisationSearch(
        Search => 'somecompany',
    );

    my %List = $OrganisationObject->OrganisationSearch(
        Number => '1234567',
    );

    my %List = $OrganisationObject->OrganisationSearch(
        Name => 'somename',
    );

Returns:

%List = {
          1 => 'example.com Customer Inc.',
          2 => 'acme.com Acme, Inc.'
        };

=cut

sub OrganisationSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = "OrganisationSearch::${Valid}::" . ( $Param{Limit} || 0) . "::" . ( $Param{Search} || '' ) . "::" . ( $Param{Number} || '' ) . "::" . ( $Param{Name} || '' );
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
            for my $Field ( qw(number name street zip city country url) ) {
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
    elsif ( $Param{Number} ) {

        if ( defined $SQL ) {
            $SQL .= " AND ";
        }

        my $Number = $Param{Number};
        $Number =~ s/\*/%/g;
        $Number =~ s/%%/%/g;

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "number LIKE ?";
            push(@Bind, \$Number);
        }
        else {
            $SQL .= "LOWER(number) LIKE LOWER(?)";
            push(@Bind, \$Number);
        }
    }
    elsif ( $Param{Name} ) {

        if ( defined $SQL ) {
            $SQL .= " AND ";
        }

        my $Name = $Param{Name};
        $Name =~ s/\*/%/g;
        $Name =~ s/%%/%/g;

        if ( $Self->{CaseSensitive} ) {
            $SQL .= "name LIKE ?";
            push(@Bind, \$Name);
        }
        else {
            $SQL .= "LOWER(name) LIKE LOWER(?)";
            push(@Bind, \$Name);
        }
    }

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => "SELECT id, name FROM organisation " . ($SQL ? "WHERE $SQL" : ''),
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

=item OrganisationDelete()

delete an organisation

    my $Success = $OrganisationObject->OrganisationDelete(
        ID => 123,
    );

=cut

sub OrganisationDelete {
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
        SQL  => 'DELETE FROM organisation WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Organisation',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item GetPreferences()

get customer user preferences

    my %Preferences = $OrganisationObject->GetPreferences(
        UserID => 'some-login',
    );

=cut

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check if user exists
    my %User = $Self->OrganisationGet( OrganisationNumber => $Param{UserID} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserID}'!",
        );
        return;
    }

    # call new api (2.4.8 and higher)
    if ( $Self->{ $User{Source} }->can('GetPreferences') ) {
        return $Self->{ $User{Source} }->GetPreferences(%Param);
    }

    # call old api
    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

=item SetPreferences()

set customer user preferences

    $OrganisationObject->SetPreferences(
        Key    => 'UserComment',
        Value  => 'some comment',
        UserID => 'some-login',
    );

=cut

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check if user exists
    my %User = $Self->OrganisationGet( OrganisationNumber => $Param{UserID} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserID}'!",
        );
        return;
    }

    my $Result;

    # call new api (2.4.8 and higher)
    if ( $Self->{ $User{Source} }->can('SetPreferences') ) {
        $Result = $Self->{ $User{Source} }->SetPreferences(%Param);
    }

    # call old api
    else {
        $Result = $Self->{PreferencesObject}->SetPreferences(%Param);
    }

    # trigger event handler
    if ($Result) {
        $Self->EventHandler(
            Event => 'OrganisationSetPreferences',
            Data  => {
                %Param,
                UserData => \%User,
                Result   => $Result,
            },
            UserID => 1,
        );
    }

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Customer.Preference',
        ObjectID  => $Param{UserID}.'::'.$Param{Key},
    );

    return $Result;
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
