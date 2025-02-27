#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1719',
    },
);

use vars qw(%INC);

# add new notifications
_AddNotifications();


sub _AddNotifications {
    my ( $Self, %Param ) = @_;

    my @Notifications = (
        {
            Name => 'Customer - Follow Up Rejection',
            ValidID => 2,
            Filter => { AND => [
                { Field => "SenderTypeID", Operator => "IN", Value => [3] },
                { Field => "ChannelID", Operator => "IN", Value => [2] }
            ]},
            Data => {
                Events            => [ 'ArticleCreateFollowUpReject' ],
                Recipients        => [ '' ],
                SendOnOutOfOffice => [ 0 ],
                Transports        => [ 'Email' ],
                RecipientEmail    => [ '<KIX_ARTICLE_From>' ],
                RecipientSubject  => [ 1 ],
                VisibleForAgent   => [ 0 ],
                OncePerDay        => [ 0 ],
                CreateArticle     => [ 0 ],
            },
            Message => {
                en => {
                    Subject     => Encode::decode_utf8('Re: <KIX_CUSTOMER_Subject_64> (rejected).'),
                    Body        => Encode::decode_utf8('<p>Thank you very much for your email. The ticket has already been closed. Therefore, although your follow-up has been recorded, no action is taken. Please create a new request.</p>'),
                    ContentType => 'text/html',
                },
                de => {
                    Subject     => Encode::decode_utf8('Re: <KIX_CUSTOMER_Subject_64> (abgelehnt)'),
                    Body        => Encode::decode_utf8('<p>Vielen Dank f&uuml;r Ihre E-Mail. Das Ticket wurde bereits geschlossen. Daher wurde Ihre Nachfrage zwar erfasst, aber es folgt keine Aktion. Bitte erstellen Sie eine neue Anfrage.</p>'),
                    ContentType => 'text/html',
                },
            },
        },
    );

    my %NotificationList = $Kernel::OM->Get('NotificationEvent')->NotificationList(
        All => 1,
    );
    %NotificationList = reverse %NotificationList;

    foreach my $Notification ( @Notifications ) {
        next if $NotificationList{$Notification->{Name}};

        my $Result = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
            %{$Notification},
            UserID  => 1
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority  => 'error',
                Message   => "Unable to add notification \"$Notification->{Name}\"!",
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority  => 'info',
                Message   => "Added notification \"$Notification->{Name}\"!",
            );
        }
    }

    return 1;
}

exit 0;

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
