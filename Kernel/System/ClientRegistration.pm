# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ClientRegistration;

use strict;
use warnings;

use CGI;
use LWP::UserAgent;
use Time::HiRes;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

use base qw(Kernel::System::AsynchronousExecutor);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::ClientRegistration

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ClientRegistration object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ClientRegistrationObject = $Kernel::OM->Get('ClientRegistration');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{DBObject}     = $Kernel::OM->Get('DB');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');

    $Self->{CacheType} = 'ClientRegistration';

    $Self->{DisableClientNotifications} = $Param{DisableClientNotifications};

    $Self->{NotificationCount} = 0;

    return $Self;
}

=item ClientRegistrationGet()

Get a client registration.

    my %Data = $ClientRegistrationObject->ClientRegistrationGet(
        ClientID      => '...',
        Silent        => 1|0       # optional - default 0
    );

=cut

sub ClientRegistrationGet {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check required params...
    if ( !$Param{ClientID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need ClientID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'ClientRegistrationGet::' . $Param{ClientID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Self->{DBObject}->Prepare(
        SQL   => "SELECT client_id, notification_url, notification_authorization, additional_data FROM client_registration WHERE client_id = ?",
        Bind => [ \$Param{ClientID} ],
    );

    my %Data;

    # fetch the result
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ClientID                  => $Row[0],
            NotificationURL           => $Row[1],
            Authorization             => $Row[2],
        );
        if ( $Row[3] ) {
            # prepare additional data
            my $AdditionalData = $Kernel::OM->Get('JSON')->Decode(
                Data => $Row[3]
            );
            if ( IsHashRefWithData($AdditionalData) ) {
                $Data{Plugins}  = $AdditionalData->{Plugins};
                $Data{Requires} = $AdditionalData->{Requires};
            }
        }
    }

    # no data found...
    if ( !%Data ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Registration for client '$Param{ClientID}' not found!",
            );
        }
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;

}

=item ClientRegistrationAdd()

Adds a new client registration

    my $Result = $ClientRegistrationObject->ClientRegistrationAdd(
        ClientID             => 'CLIENT1',
        NotificationURL      => '...',            # optional
        Authorization        => '...',            # optional
        Translations         => '...',            # optional
        Plugins              => [],               # optional
        Requires             => []                # optional
    );

=cut

sub ClientRegistrationAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # prepare additional data
    my $AdditionalDataJSON = $Kernel::OM->Get('JSON')->Encode(
        Data => {
            Plugins  => $Param{Plugins},
            Requires => $Param{Requires}
        }
    );

    # do the db insert...
    my $Result = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO client_registration (client_id, notification_url, notification_authorization, additional_data) VALUES (?, ?, ?, ?)",
        Bind => [
            \$Param{ClientID},
            \$Param{NotificationURL},
            \$Param{Authorization},
            \$AdditionalDataJSON,
        ],
    );

    # handle the insert result...
    if ( !$Result ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );

        return;
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'info',
            Message  => "Client \"$Param{ClientID}\" registered.",
        );
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return $Param{ClientID};
}

=item ClientRegistrationList()

Returns an array with all registered ClientIDs

    my @ClientIDs = $ClientRegistrationObject->ClientRegistrationList(
        Notifiable => 0|1           # optional, get only those client that requested to be notified
    );

=cut

sub ClientRegistrationList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'ClientRegistrationList::'.($Param{Notifiable} || '');
    my $CacheResult = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return @{$CacheResult} if (IsArrayRefWithData($CacheResult));

    my $SQL = 'SELECT client_id FROM client_registration';

    if ( $Param{Notifiable} ) {
        $SQL .= ' WHERE notification_url IS NOT NULL'
    }

    return if !$Self->{DBObject}->Prepare(
        SQL => $SQL,
    );

    my @Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $CacheTTL,
    );

    return @Result;
}

=item ClientRegistrationDelete()

Delete a client registration.

    my $Result = $ClientRegistrationObject->ClientRegistrationDelete(
        ClientID      => '...',
    );

=cut

sub ClientRegistrationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM client_registration WHERE client_id = ?',
        Bind => [ \$Param{ClientID} ],
    );

    $Self->{LogObject}->Log(
        Priority => 'info',
        Message  => "Client registration for \"$Param{ClientID}\" deleted.",
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return 1;
}

=item NotifyClients()

Pushes a notification event to inform the clients

    my $Result = $ClientRegistrationObject->NotifyClients(
        Event     => 'CREATE|UPDATE|DELETE',             # required
        Namespace => 'Ticket.Article',                   # required
        ObjectID  => '...'                               # optional
    );

=cut

sub NotifyClients {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Event Namespace)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return if $Self->{DisableClientNotifications};

    my $Timestamp = Time::HiRes::time();

    # get RequestID
    my $cgi = CGI->new;
    my %Headers = map { $_ => $cgi->http($_) } $cgi->http();
    my $RequestID = $Headers{HTTP_KIX_REQUEST_ID} || '';

    $Kernel::OM->Get('Cache')->Set(
        Type          => 'ClientNotification',
        Key           => $$.'_'.$Timestamp.'_'.$RequestID,
        Value         => {
            ID => $$.'_'.$Timestamp.'_'.$RequestID,
            %Param,
        },
        NoStatsUpdate => 1,
    );

    $Self->{NotificationCount}++;

    return 1;
}

=item NotificationCount()

return the number of outstanding client notifications

    my $Count = $ClientRegistrationObject->NotificationCount();

=cut

sub NotificationCount {
    my ( $Self, %Param ) = @_;

    return 0 if $Self->{DisableClientNotifications};

    return $Self->{NotificationCount};
}

=item NotificationSend()

send notifications to all clients who want to receive notifications

    my $Result = $ClientRegistrationObject->NotificationSend(
        Async => 0|1,       # optional, default 0
    );

=cut

sub NotificationSend {
    my ( $Self, %Param ) = @_;

    return if $Self->{DisableClientNotifications};

    my $CacheObject = $Kernel::OM->Get('Cache');

    # get cached events
    my @Keys = $CacheObject->GetKeysForType(
        Type => 'ClientNotification',
    );
    return 1 if !@Keys;

    my @EventList = $CacheObject->GetMulti(
        Type          => 'ClientNotification',
        Keys          => \@Keys,
        UseRawKey     => 1,
        NoStatsUpdate => 1,
    );
    return 1 if !@EventList;
    
    # delete the cached events we sent
    foreach my $Key ( @Keys ) {
        $CacheObject->Delete(
            Type          => 'ClientNotification',
            Key           => $Key,
            UseRawKey     => 1,
            NoStatsUpdate => 1,
        );
    }


    # get list of clients that requested to be notified
    my @ClientIDs = $Self->ClientRegistrationList(
        Notifiable => 1
    );
    return if !@ClientIDs;

    # inform the daemon worker of the work to be done
    $Kernel::OM->Get('Cache')->Set(
        Type          => 'ClientNotificationToSend',
        Key           => $$.Time::HiRes::time(),
        Value         => {
            EventList => \@EventList,
            ClientIDs => \@ClientIDs
        },
        NoStatsUpdate => 1,
    );

    return 1;
}

sub NotificationSendWorker {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientIDs EventList)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Stats;
    my @PreparedEventList;
    foreach my $Item ( @{$Param{EventList}} ) {
        next if !$Item->{Event};
        push @PreparedEventList, $Item;
        $Stats{lc($Item->{Event})}++;
    }
    my @StatsParts;
    foreach my $Event ( sort keys %Stats ) {
        push(@StatsParts, "$Stats{$Event} $Event".'s');
    }

    if ( $Kernel::OM->Get('Config')->Get('ClientNotification::Debug') ) {
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "[ClientNotification] sending client notifications: ".Data::Dumper::Dumper(\%Param)
        );
    }

    foreach my $ClientID ( @{$Param{ClientIDs}} ) {
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "Sending ". @PreparedEventList . " notifications to client \"$ClientID\" (" . (join(', ', @StatsParts)) . ').'
        );

        $Self->_NotificationSendToClient(
            ClientID  => $ClientID,
            EventList => \@PreparedEventList,
        );
    }

    return 1;
}

sub _NotificationSendToClient {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID EventList)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get the registration of the client
    my %ClientRegistration = $Self->ClientRegistrationGet(
        ClientID => $Param{ClientID}
    );

    # don't use Crypt::SSLeay but IO::Socket::SSL instead
    $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

    if ( !$Self->{UserAgent} ) {
        my $ConfigObject       = $Kernel::OM->Get('Config');
        my $WebUserAgentObject = $Kernel::OM->Get('WebUserAgent');

        # create user agent with short timeout
        $Self->{UserAgent} = LWP::UserAgent->new(timeout => 10);

        # set user agent
        $Self->{UserAgent}->agent(
            $ConfigObject->Get('Product') . ' ' . $ConfigObject->Get('Version')
        );

        # set timeout
        $Self->{UserAgent}->timeout( $WebUserAgentObject->{Timeout} );

        # disable SSL host verification
        if ( $ConfigObject->Get('WebUserAgent::DisableSSLVerification') ) {
            $Self->{UserAgent}->ssl_opts(
                verify_hostname => 0,
            );
        }

        # set proxy
        if ( $WebUserAgentObject->{Proxy} ) {
            $Self->{UserAgent}->proxy( [ 'http', 'https', 'ftp' ], $WebUserAgentObject->{Proxy} );
        }
    }

    my $Request = HTTP::Request->new('POST', $ClientRegistration{NotificationURL});
    $Request->header('Content-Type' => 'application/json');
    if ( $ClientRegistration{Authorization} ) {
        $Request->header('Authorization' => $ClientRegistration{Authorization});
    }

    my $JSON = $Kernel::OM->Get('JSON')->Encode(
        Data => $Param{EventList},
    );
    $Request->content($JSON);
    if ( $Kernel::OM->Get('Config')->Get('ClientNotification::Debug') ) {
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "[ClientNotification] executing request to client: ".$Request->as_string()
        );
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "[ClientNotification] LWP object: ".Data::Dumper::Dumper($Self->{UserAgent})
        );
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "[ClientNotification] ENV: ".Data::Dumper::Dumper(\%ENV)
        );
    }
    my $Response = $Self->{UserAgent}->request($Request);

    if ( $Kernel::OM->Get('Config')->Get('ClientNotification::Debug') ) {
        $Self->{LogObject}->Log(
            Priority => 'debug',
            Message  => "[ClientNotification] client response: ".$Response->as_string()
        );
    }

    if ( !$Response->is_success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Client \"$Param{ClientID}\" ($ClientRegistration{NotificationURL}) responded with error ".$Response->status_line.".",
        );
        return 0;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'debug',
        Message  => "Client \"$Param{ClientID}\" ($ClientRegistration{NotificationURL}) responded with success ".$Response->status_line.".",
    );

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