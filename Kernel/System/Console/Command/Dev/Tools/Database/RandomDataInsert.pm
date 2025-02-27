# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::Database::RandomDataInsert;

use strict;
use warnings;

use Kernel::System::Role;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Contact',
    'Organisation',
    'DB',
    'DynamicField',
    'DynamicField::Backend',
    'Role',
    'Queue',
    'Ticket',
    'User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Insert random data into the KIX database for testing purposes.');
    $Self->AddOption(
        Name        => 'tickets',
        Description => "Specify how many tickets should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'articles-per-ticket',
        Description => "Specify how many articles should be generated per ticket.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'users',
        Description => "Specify how many users should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'contacts',
        Description => "Specify how many contacts should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'organisations',
        Description => "Specify how many organisations should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'roles',
        Description => "Specify how many roles should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'queues',
        Description => "Specify how many queues should be generated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'mark-tickets-as-seen',
        Description => "Specify if the generated tickets should be marked as seen.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AdditionalHelp("<red>Please don't use this command in production environments.</red>\n");

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # set dummy sendmail module to avoid notifications
    $Kernel::OM->Get('Config')->Set(
        Key   => 'SendmailModule',
        Value => 'Kernel::System::Email::DoNotSendEmail',
    );
    $Kernel::OM->Get('Config')->Set(
        Key   => 'CheckEmailAddresses',
        Value => 0,
    );

    # Refresh common objects after a certain number of loop iterations.
    #   This will call event handlers and clean up caches to avoid excessive mem usage.
    $Self->{CommonObjectRefresh} = 50;

    # get dynamic fields
    $Self->{Data}->{TicketDynamicFields} = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    $Self->{Data}->{ArticleDynamicFields} = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Article'],
    );

    # roles
    if ( !$Self->GetOption('roles') ) {
        $Self->{Data}->{RoleIDs} = [ $Self->RoleGet() ];
    }
    else {
        $Self->{Data}->{RoleIDs} = [ $Self->RoleCreate( $Self->GetOption('roles') ) ];
    }

    # users
    my @UserIDs;
    if ( !$Self->GetOption('users') ) {
        $Self->{Data}->{UserIDs} = [ $Self->UserGet() ];
    }
    else {
        $Self->{Data}->{UserIDs} = [ $Self->UserCreate( $Self->GetOption('users') ) ];
    }

    # queues
    if ( !$Self->GetOption('queues') ) {
        $Self->{Data}->{QueueIDs} = [ $Self->QueueGet() ];
    }
    else {
        $Self->{Data}->{QueueIDs} = [ $Self->QueueCreate( $Self->GetOption('queues')) ];
    }

    # customer companies
    if ( !$Self->GetOption('organisations') ) {
        $Self->{Data}->{OrganisationIDs} = [ $Self->OrganisationGet() ];
    }
    else {
        $Self->{Data}->{OrganisationIDs} = [ $Self->OrganisationCreate( $Self->GetOption('organisations') ) ];
    }

    # customer users
    if ( !$Self->GetOption('contacts') ) {
        $Self->{Data}->{ContactIDs} = [ $Self->ContactGet() ];
    }
    else {
        $Self->{Data}->{ContactIDs} = [ $Self->ContactCreate( $Self->GetOption('contacts') ) ];
    }

    if ( $Self->GetOption('tickets') ) {
        $Self->{Data}->{TicketIDs} = [ $Self->TicketCreate( $Self->GetOption('tickets') ) ];
    }

    return $Self->ExitCodeOk();
}

#
# Helper functions below
#
sub RandomAddress {
    my ($Self) = @_;

    my $Name = $Self->_GetRandomData('Firstnames').' '.$Self->_GetRandomData('Lastnames');

    return $Name . '@' . $Self->_GetRandomData('Domains');
}

sub RandomBody {
    my ($Self) = @_;

    my $Body = '';
    for ( 1 .. 50 ) {
        $Body .= $Self->_GetRandomData('Textlines') . "\n";
    }
    return $Body;
}

sub QueueGet {
    my ($Self) = @_;

    my %Queues = $Kernel::OM->Get('Queue')->GetAllQueues();

    return sort keys %Queues;
}

sub QueueCreate {
    my ($Self, $Count) = @_;

    my @QueueIDs;
    for ( 1 .. $Count ) {
        my $Name = 'fill-up-queue' . int( rand(100_000_000) );
        my $ID   = $Kernel::OM->Get('Queue')->QueueAdd(
            Name              => $Name,
            ValidID           => 1,
            SystemAddressID   => 1,
            UserID            => 1,
            MoveNotify        => 0,
            StateNotify       => 0,
            LockNotify        => 0,
            OwnerNotify       => 0,
            Comment           => 'Some Comment',
        );
        if ($ID) {
            print "Queue '$Name' with ID '$ID' created.\n";
            push( @QueueIDs, $ID );
        }
    }
    return @QueueIDs;
}

sub RoleGet {
    my ($Self) = @_;

    my %Roles = $Kernel::OM->Get('Role')->RoleList( Valid => 1 );

    return sort keys %Roles;
}

sub RoleCreate {
    my ($Self, $Count) = @_;

    my @RoleIDs;
    for ( 1 .. $Count ) {
        my $Name = 'fill-up-role' . int( rand(100_000_000) );
        my $ID   = $Kernel::OM->Get('Role')->RoleAdd(
            Name    => $Name,
            UsageContext => Kernel::System::Role->USAGE_CONTEXT->{AGENT},
            ValidID => 1,
            UserID  => 1,
        );
        if ($ID) {
            print "Role '$Name' with ID '$ID' created.\n";
            push( @RoleIDs, $ID );

            # add root to every role
            $Kernel::OM->Get('Role')->RoleUserAdd(
                AssignUserID => 1,
                RoleID       => $ID,
                UserID       => 1,
            );
        }
    }
    return @RoleIDs;
}

sub UserGet {
    my ($Self) = @_;

    my %Users = $Kernel::OM->Get('User')->UserList(
        Type  => 'Short',    # Short|Long
        Valid => 1,          # not required
    );
    return sort keys %Users;
}

sub UserCreate {
    my ($Self, $Count) = @_;

    my @UserIDs;
    for ( 1 .. $Count ) {
        my $Firstname = $Self->_GetRandomData('Firstnames');
        my $Lastname = $Self->_GetRandomData('Lastnames');
        my $Email = $Firstname . '.' . $Lastname . '@' . $Self->_GetRandomData('Domains');

        print STDERR "$Firstname, $Lastname, $Email\n";

        my $UserID   = $Kernel::OM->Get('User')->UserAdd(
            UserLogin    => $Firstname . ' ' . $Lastname,
            ValidID      => 1,
            ChangeUserID => 1,
            IsAgent      => 1,
        );
        print "Agent '$Firstname $Lastname' with ID '$UserID' created.\n";
        if ($UserID) {
            my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
                AssignedUserID => $UserID,
                Firstname      => $Firstname,
                Lastname       => $Lastname,
                Email          => $Email,
                ValidID        => 1,
                UserID         => 1,
                ValidID        => 1,
            );
            print "    Contact '$Firstname $Lastname' with ID '$ContactID' for user created.\n";
            push( @UserIDs, $UserID );
            ROLEADD:
            for ( 0..int( rand(5) ) ) {
                my $RoleID = $Self->_GetRandomData('RoleIDs');

                my @Users = $Kernel::OM->Get('Role')->RoleUserList(
                    RoleID => $RoleID,
                );
                my %UserList = map { $_ => 1 } @Users;
                next ROLEADD if $UserList{$UserID};

                $Kernel::OM->Get('Role')->RoleUserAdd(
                    AssignUserID => $UserID,
                    RoleID       => $RoleID,
                    UserID       => 1,
                );
            }
        }
    }
    return @UserIDs;
}

sub ContactGet {
    my ($Self) = @_;

    my %Contacts = $Kernel::OM->Get('Contact')->ContactList(
        Valid => 1,          # not required
    );
    return sort keys %Contacts;
}

sub ContactCreate {
    my ($Self, $Count) = @_;

    my @ContactIDs;
    for ( 1 .. $Count ) {
        my $Firstname = $Self->_GetRandomData('Firstnames');
        my $Lastname  = $Self->_GetRandomData('Lastnames');

        my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
            Firstname      => $Firstname,
            Lastname       => $Lastname,
            Email          => "$Firstname.$Lastname".'@'.$Self->_GetRandomData('Domains'),
            Street         => $Self->_GetRandomData('Streets'),
            City           => $Self->_GetRandomData('Cities'),
            Zip            => $Self->_GetRandomData('Postcodes'),
            ValidID        => 1,
            UserID         => 1,
        );

        push @ContactIDs, $ContactID;

        print "Contact '$Firstname $Lastname' (ID '$ContactID') created.\n";
    }

    return @ContactIDs;
}

sub OrganisationGet {
    my ($Self) = @_;

    return $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Valid',
                    Operator => 'EQ',
                    Type     => 'STRING',
                    Value    => 'valid'
                }
            ]
        },
        UserType   => 'Agent',
        UserID     => 1,
    );
}

sub OrganisationCreate {
    my ($Self, $Count) = @_;

    my @OrganisationIDs;
    for ( 1 .. $Count ) {

        my $Name       = $Self->_GetRandomData('Organisations');
        my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            Number   => 'CO' . sprintf('%09i', rand(100_000_000)),
            Name     => $Name,
            Street   => $Self->_GetRandomData('Streets'),
            Zip      => $Self->_GetRandomData('Postcodes'),
            City     => $Self->_GetRandomData('Cities'),
            Country  => $Self->_GetRandomData('Countries'),
            Url      => 'http://www.'.$Self->_GetRandomData('Domains'),
            Comment  => 'some comment',
            ValidID  => 1,
            UserID   => 1,
        );
        push @OrganisationIDs, $OrganisationID;

        print "Organisation '$Name' created.\n";
    }

    return @OrganisationIDs;
}

sub TicketCreate {
    my ($Self, $Count) = @_;
    my $Counter;

    # create tickets
    my @TicketIDs;
    for ( 1 .. $Count ) {
        my $TicketUserID =

            my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
            Title        => $Self->_GetRandomData('Subjects'),
            QueueID      => $Self->_GetRandomData('QueueIDs'),
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            OrganisationID => $Self->_GetRandomData('OrganisationIDs'),
            ContactID    => $Self->_GetRandomData('ContactIDs'),
            OwnerID      => $Self->_GetRandomData('UserIDs'),
            UserID       => $Self->_GetRandomData('UserIDs'),
            );

        if ( $Self->GetOption('mark-tickets-as-seen') ) {

            # bulk-insert the flags directly for improved performance
            my $SQL = 'INSERT INTO ticket_flag (ticket_id, ticket_key, ticket_value, create_time, create_by) VALUES ';
            my @Values;
            for my $UserID (@{$Self->{Data}->{UserIDs}}) {
                push @Values, "($TicketID, 'Seen', 1, current_timestamp, $UserID)";
            }
            while ( my @ValuesPart = splice( @Values, 0, 50 ) ) {
                $Kernel::OM->Get('DB')->Do( SQL => $SQL . join( ',', @ValuesPart ) );
            }
        }

        if ($TicketID) {

            print "Ticket with ID '$TicketID' created.\n";

            for ( 1 .. $Self->GetOption('articles-per-ticket') // 10 ) {
                my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
                    TicketID       => $TicketID,
                    Channel        => 'note',
                    CustomerVisible => 1,
                    SenderType     => 'external',
                    From           => $Self->RandomAddress(),
                    To             => $Self->RandomAddress(),
                    Cc             => $Self->RandomAddress(),
                    Subject        => $Self->_GetRandomData('Subjects'),
                    Body           => $Self->RandomBody(),
                    ContentType    => 'text/plain; charset=ISO-8859-15',
                    HistoryType    => 'AddNote',
                    HistoryComment => 'Some free text!',
                    UserID         => $Self->_GetRandomData('UserIDs'),
                    NoAgentNotify  => 1,                                 # if you don't want to send agent notifications
                );

                if ( $Self->GetOption('mark-tickets-as-seen') ) {

                    # bulk-insert the flags directly for improved performance
                    my $SQL
                        = 'INSERT INTO article_flag (article_id, article_key, article_value, create_time, create_by) VALUES ';
                    my @Values;
                    for my $UserID (@{$Self->{Data}->{UserIDs}}) {
                        push @Values, "($ArticleID, 'Seen', 1, current_timestamp, $UserID)";
                    }
                    while ( my @ValuesPart = splice( @Values, 0, 50 ) ) {
                        $Kernel::OM->Get('DB')->Do( SQL => $SQL . join( ',', @ValuesPart ) );
                    }
                }

                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{$Self->{Data}->{ArticleDynamicFields}} ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                    next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Article';
                    next DYNAMICFIELD if $DynamicFieldConfig->{InternalField};

                    # set a random value
                    my $Result = $Kernel::OM->Get('DynamicField::Backend')->RandomValueSet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $ArticleID,
                        UserID             => $Self->_GetRandomData('UserIDs'),
                    );

                    if ( $Result->{Success} ) {
                        print "Article with ID '$ArticleID' set dynamic field "
                            . "$DynamicFieldConfig->{Name}: $Result->{Value}.\n";
                    }
                }

                print "New Article '$ArticleID' created for Ticket '$TicketID'.\n";
            }

            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$Self->{Data}->{TicketDynamicField}} ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';
                next DYNAMICFIELD if $DynamicFieldConfig->{InternalField};

                # set a random value
                my $Result = $Kernel::OM->Get('DynamicField::Backend')->RandomValueSet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $TicketID,
                    UserID             => $Self->_GetRandomData('UserIDs'),
                );

                if ( $Result->{Success} ) {
                    print "Ticket with ID '$TicketID' set dynamic field "
                        . "$DynamicFieldConfig->{Name}: $Result->{Value}.\n";
                }
            }

            push( @TicketIDs, $TicketID );

            if ( $Counter++ % $Self->{CommonObjectRefresh} == 0 ) {
                $Kernel::OM->ObjectsDiscard(
                    Objects => ['Ticket'],
                );
            }
        }
    }

    return;
}

sub _GetRandomData {
    my ($Self, $What) = @_;

    if ( !IsArrayRef($Self->{Data}->{$What}) ) {
        my $Home = $Kernel::OM->Get('Config')->Get('Home');
        # load word list from file
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Location => $Home.'/scripts/dev/RandomDataGenerate/'.$What.'.txt',
            Result   => 'ARRAY',
            Mode     => 'utf8'
        );
        if ( $Content ) {
            $Self->{Data}->{$What} = $Content;
        }
    }

    my @Array = @{$Self->{Data}->{$What} || []};

    my $Result = $Array[int(rand($#Array - 1))];
    chomp($Result) if $Result;

    $Result =~ s/\\\t/\t/;
    $Result =~ s/\\\n/\n/;
    $Result =~ s/\\\r/\r/;

    return $Result;
}

1;

#TODO add function to randomly assign contacts to organisation



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
