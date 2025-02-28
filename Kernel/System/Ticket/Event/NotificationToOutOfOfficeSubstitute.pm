# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::NotificationToOutOfOfficeSubstitute;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Contact',
    'Email',
    'HTMLUtils',
    'Log',
    'User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(TicketID Notification)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "NotificationToOutOfOfficeSubstitute: Need $_!"
            );
            return;
        }
    }
    my %Notification = %{ $Param{Data}->{Notification} };

    # check if recipient data is availible
    if ( !$Param{Data}->{RecipientMail} && !$Param{Data}->{RecipientID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "NotificationToOutOfOfficeSubstitute: Need RecipientMail or RecipientID!"
        );
        return;
    }

    # check if recipient is valid and out of office
    my %UserSearchResult = ();
    if ( $Param{Data}->{RecipientID} ) {
        %UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
            SearchUserID  => $Param{Data}->{RecipientID},
            IsOutOfOffice => 1,
            Valid         => 1,
            Limit         => 1,
        );
    }
    else {
        my $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
            Email  => $Param{Data}->{RecipientMail},
            Silent => 1
        );
        if ($ContactID) {
            my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                ID => $ContactID
            );
            if (
                %Contact
                && $Contact{AssignedUserID}
            ) {
                %UserSearchResult = $Kernel::OM->Get('User')->UserSearch(
                    SearchUserID  => $Contact{AssignedUserID},
                    IsOutOfOffice => 1,
                    Valid         => 1,
                    Limit         => 1,
                );
            }
        }
    }

    # check if recipient is out of office
    my $UserID;
    my $UserLogin;
    for my $ResultUserID ( keys( %UserSearchResult ) ) {
        $UserID = $ResultUserID;
        $UserID = $UserSearchResult{ $ResultUserID };
    }
    return if (
        !$UserID
        || !$UserLogin
    );

    # get preference OutOfOfficeSubstitute of user
    my %Preferences = $Kernel::OM->Get('User')->GetPreferences(
        UserID => $UserID,
    );
    return if (
        !%Preferences
        || !$Preferences{OutOfOfficeSubstitute}
    );

    # get substitute contact data
    my %SubstituteUserContact = $Kernel::OM->Get('Contact')->ContactGet(
        UserID => $Preferences{OutOfOfficeSubstitute},
    );
    return if (
        !%SubstituteUserContact
        || !$SubstituteUserContact{Email}
    );

    # prepare notification body
    if ( $Preferences{OutOfOfficeSubstituteNote} ) {
        if (
            $Notification{ContentType}
            && $Notification{ContentType} eq 'text/html'
        ) {
            $Notification{Body} = $Kernel::OM->Get('HTMLUtils')->DocumentStrip(
                String => $Notification{Body},
            );
            $Notification{Body} = $Preferences{OutOfOfficeSubstituteNote}
                . "<br/>**********************************************************************<br/><br/>"
                . $Notification{Body};
            $Notification{Body} = $Kernel::OM->Get('HTMLUtils')->DocumentComplete(
                String  => $Notification{Body},
                Charset => 'utf-8',
            );
        }
        else {
            $Notification{Body} = $Preferences{OutOfOfficeSubstituteNote}
                . "\n**********************************************************************\n\n"
                . $Notification{Body};
        }
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message =>
            "Sent substitute email to '$SubstituteUserContact{Email}' for agent '$UserLogin'",
    );

    # send notification to substitute
    $Kernel::OM->Get('Email')->Send(
        From => $Kernel::OM->Get('Config')->Get('NotificationSenderName') . ' <'
            . $Kernel::OM->Get('Config')->Get('NotificationSenderEmail') . '>',
        To         => $SubstituteUserContact{Email},
        Subject    => $Notification{Subject},
        MimeType   => $Notification{ContentType} || 'text/plain',
        Charset    => 'utf-8',
        Body       => $Notification{Body},
        Loop       => 1,
        Attachment => $Param{Data}->{Attachments} || [],
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
