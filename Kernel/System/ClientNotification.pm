# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ClientNotification;

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

Kernel::System::ClientNotification

=head1 SYNOPSIS

Add client notification functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ClientNotification object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ClientNotificationObject = $Kernel::OM->Get('ClientNotification');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{LogObject} = $Kernel::OM->Get('Log');
    $Self->{CacheObject} = $Kernel::OM->Get('Cache');

    $Self->{DisableClientNotifications} = $Param{DisableClientNotifications};

    $Self->{NotificationCount} = 0;

    return $Self;
}

=item NotifyClients()

Pushes a notification event to inform the clients

    my $Result = $ClientNotificationObject->NotifyClients(
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

    $Self->{CacheObject}->Set(
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

    my $Count = $ClientNotificationObject->NotificationCount();

=cut

sub NotificationCount {
    my ( $Self, %Param ) = @_;

    return 0 if $Self->{DisableClientNotifications};

    return $Self->{NotificationCount};
}

=item NotificationSend()

send notifications to all clients who want to receive notifications

    my $Result = $ClientNotificationObject->NotificationSend(
        Async => 0|1,       # optional, default 0
    );

=cut

sub NotificationSend {
    my ( $Self, %Param ) = @_;

    return if $Self->{DisableClientNotifications};

    # get cached events
    my @Keys = $Self->{CacheObject}->GetKeysForType(
        Type => 'ClientNotification',
    );
    return 1 if !@Keys;

    my @EventList = $Self->{CacheObject}->GetMulti(
        Type          => 'ClientNotification',
        Keys          => \@Keys,
        UseRawKey     => 1,
        NoStatsUpdate => 1,
    );
    return 1 if !@EventList;
    
    # delete the cached events we sent
    foreach my $Key ( @Keys ) {
        $Self->{CacheObject}->Delete(
            Type          => 'ClientNotification',
            Key           => $Key,
            UseRawKey     => 1,
            NoStatsUpdate => 1,
        );
    }

    # push events to our frontend server
    $Self->NotificationSendWorker(
        EventList => \@EventList,
    );

    # get list of clients that requested to be notified
    my @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList(
        Notifiable => 1
    );
    return if !@ClientIDs;

    # inform the daemon worker of the work to be done
    $Self->{CacheObject}->Set(
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
    if ( !$Param{EventList} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need EventList!"
        );
        return;
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

    # create event list JSON
    my $EventList = $Kernel::OM->Get('JSON')->Encode(
        Data => \@PreparedEventList,
    );

    if ( IsArrayRef($Param{ClientIDs}) ) {
        # inform the relevant registered clients
        foreach my $ClientID ( @{$Param{ClientIDs}} ) {
            $Self->{LogObject}->Log(
                Priority => 'debug',
                Message  => "Sending ". @PreparedEventList . " notifications to client \"$ClientID\" (" . (join(', ', @StatsParts)) . ').'
            );

            $Self->_NotificationSendToClient(
                ClientID  => $ClientID,
                EventList => $EventList,
            );
        }
    }
    else {
        my $Result = $Self->{CacheObject}->{CacheObject}->_RedisCall(
            'publish',
            'KIXFrontendNotify',
            $EventList,
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
    my %ClientNotification = $Self->ClientNotificationGet(
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

    my $Request = HTTP::Request->new('POST', $ClientNotification{NotificationURL});
    $Request->header('Content-Type' => 'application/json');
    if ( $ClientNotification{Authorization} ) {
        $Request->header('Authorization' => $ClientNotification{Authorization});
    }

    $Request->content($Param{EventList});
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
            Message  => "Client \"$Param{ClientID}\" ($ClientNotification{NotificationURL}) responded with error ".$Response->status_line.".",
        );
        return 0;
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'debug',
        Message  => "Client \"$Param{ClientID}\" ($ClientNotification{NotificationURL}) responded with success ".$Response->status_line.".",
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