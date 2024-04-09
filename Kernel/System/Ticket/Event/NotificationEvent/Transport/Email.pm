# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent::Transport::Email;

use strict;
use warnings;

use Email::Address::XS;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

use base qw(Kernel::System::Ticket::Event::NotificationEvent::Transport::Base);

our @ObjectDependencies = (
    'Config',
    'Output::HTML::Layout',
    'Contact',
    'Email',
    'Log',
    'Main',
    'Queue',
    'SystemAddress',
    'Ticket',
    'User',
    'WebRequest',
    'DynamicField',
);

=head1 NAME

Kernel::System::Ticket::Event::NotificationEvent::Transport::Email - email transport layer

=head1 SYNOPSIS

Notification event transport layer.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a notification transport object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new('');
    my $TransportObject = $Kernel::OM->Get('Ticket::Event::NotificationEvent::Transport::Email');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub SendNotification {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID Notification Recipient)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # cleanup event data
    $Self->{EventData} = undef;

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Config');
    my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');
    my $LayoutObject        = $Kernel::OM->Get('Output::HTML::Layout');

    # get recipient data
    my %Recipient = %{ $Param{Recipient} };

    # Verify a customer have an email
    # check if recipient hash has DynamicField
    if (
        $Recipient{DynamicFieldName}
        && $Recipient{DynamicFieldType}
    ) {
        # get objects
        my $ContactObject = $Kernel::OM->Get('Contact');
        my $TicketObject  = $Kernel::OM->Get('Ticket');
        my $UserObject    = $Kernel::OM->Get('User');

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        return 1 if ( !$Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} );

        # get recipients from df
        my @DFRecipients = ();

        # process values from ticket data
        my @FieldRecipients = ();
        if (ref($Ticket{'DynamicField_' . $Recipient{DynamicFieldName}}) eq 'ARRAY') {
            @FieldRecipients = @{ $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} };
        } else {
            push(@FieldRecipients, $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}});
        }
        FIELDRECIPIENT:
        for my $FieldRecipient (@FieldRecipients) {
            next FIELDRECIPIENT if !$FieldRecipient;

            my $AddressLine = q{};
            # handle dynamic field by type
            if ($Recipient{DynamicFieldType} eq 'User') {
                my $ExistingUserID = $Kernel::OM->('User')->UserLookup(
                    UserLogin => $FieldRecipient,
                );
                my %UserContactData = $ContactObject->ContactGet(
                    UserID => $ExistingUserID,
                    Valid  => 1,
                );
                next FIELDRECIPIENT if !$UserContactData{Email};
                $AddressLine = $UserContactData{Email};
            } elsif ($Recipient{DynamicFieldType} eq 'Contact') {
                my %Contact = $ContactObject->ContactGet(
                    ID => $FieldRecipient,
                );
                next FIELDRECIPIENT if !$Contact{Email};
                $AddressLine = $Contact{Email};
            } else {
                $AddressLine = $FieldRecipient;
            }

            # generate recipient
            my %DFRecipient = (
                Realname  => q{},
                Email     => $AddressLine,
                Type      => $Recipient{Type},
            );

            # check recipients
            if ( $DFRecipient{Email} && $DFRecipient{Email} =~ /@/ ) {
                push (@DFRecipients, \%DFRecipient);
            }
        }

        # handle recipients
        for my $DFRecipient (@DFRecipients) {
            $Self->SendNotification(
                TicketID              => $Param{TicketID},
                UserID                => $Param{UserID},
                Notification          => $Param{Notification},
                CustomerMessageParams => $Param{CustomerMessageParams},
                Recipient             => $DFRecipient,
                Event                 => $Param{Event},
                Attachments           => $Param{Attachments},
            );
        }

        # done
        return 1;
    }

    # get the contact for the recipient user
    if ( !$Recipient{Email} && $Recipient{UserID} ) {
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Recipient{UserID},
        );

        if ( !$Contact{Email} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Can't send notification because of missing "
                    . "recipient email (UserID=$Recipient{UserID}, ContactID=$Contact{ContactID})!",
            );
            return;
        }

        $Recipient{Email} = $Contact{Email};
    }

    return if !$Recipient{Email};
    return if $Recipient{Email} !~ /@/;

    my $IsLocalAddress = $Kernel::OM->Get('SystemAddress')->SystemAddressIsLocalAddress(
        Address => $Recipient{Email},
    );

    return if $IsLocalAddress;

    # create new array to prevent attachment growth (see bug#5114)
    my @Attachments = @{ $Param{Attachments} };

    my %Notification = %{ $Param{Notification} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # send notification
    # prepare subject
    if (
        defined( $Notification{Data}->{RecipientSubject} )
        && defined( $Notification{Data}->{RecipientSubject}->[0] )
        && !$Notification{Data}->{RecipientSubject}->[0]
    ) {
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TicketID},
        );

        $Notification{Subject} = $TicketObject->TicketSubjectClean(
            TicketNumber => $TicketNumber,
            Subject      => $Notification{Subject},
            Size         => 0,
        );
    }

    if (
        $Param{Notification}->{ContentType}
        && $Param{Notification}->{ContentType} eq 'text/html'
    ) {

        # Get configured template with fallback to Default.
        my $EmailTemplate = $Param{Notification}->{Data}->{TransportEmailTemplate}->[0] || 'Default';

        my $Home        = $Kernel::OM->Get('Config')->Get('Home');
        my $TemplateDir = "$Home/Kernel/Output/HTML/Templates/Notification/Email";

        if ( !-r "$TemplateDir/$EmailTemplate.tt" ) {
            $EmailTemplate = 'Default';
        }

        my $TemplateString = $ConfigObject->Get('Notification::Template');
        if ($TemplateString =~ /^\s*$/) {
            $TemplateString = undef;
        }

        # generate HTML
        $Notification{Body} = $LayoutObject->Output(
            Template     => $TemplateString || undef,
            TemplateFile => "Notification/Email/$EmailTemplate",
            Data         => {
                TicketID => $Param{TicketID},
                Body     => $Notification{Body},
                Subject  => $Notification{Subject}
            },
        );

        # remove script tags
        $Notification{Body} =~ s/<script.*?>.*?<\/script>//gs;
    }

    if (
        $Notification{Data}->{RecipientAttachmentDF}
        && ref($Notification{Data}->{RecipientAttachmentDF}) eq 'ARRAY'
    ) {
        # get objects
        my $DFAttachmentObject = $Kernel::OM->Get('DFAttachment');
        my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        my @FieldAttachments = ();
        for my $ID ( sort( @{ $Notification{Data}->{RecipientAttachmentDF} } ) ) {
            my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
                ID => $ID,
            );
            # gather values from ticket data
            if (ref($Ticket{'DynamicField_' . $DynamicField->{Name}}) eq 'ARRAY') {
                push(@FieldAttachments, @{ $Ticket{'DynamicField_' . $DynamicField->{Name}} });
            } else {
                push(@FieldAttachments, $Ticket{'DynamicField_' . $DynamicField->{Name}});
            }
        }

        ATTACHMENT:
        for my $Attachment ( @FieldAttachments ) {
            # read file from virtual fs
            my %File = $Kernel::OM->Get('DFAttachment')->Read(
                Filename        => $Attachment,
                Mode            => 'binary',
                DisableWarnings => 1,
            );
            next ATTACHMENT if ( !%File );

            # prepare attachment data
            my %Data = (
                'Filename'           => $File{Preferences}->{Filename},
                'Content'            => ${$File{Content}},
                'ContentType'        => $File{Preferences}->{ContentType},
                'ContentID'          => q{},
                'ContentAlternative' => q{},
                'Filesize'           => $File{Preferences}->{Filesize},
                'FilesizeRaw'        => $File{Preferences}->{FilesizeRaw},
                'Disposition'        => 'attachment',
            );
            # add attachment
            push( @{ $Param{Attachments} }, \%Data );
        }
    }

    # send notification
    if ( $Recipient{Type} eq 'Agent' ) {

        my $FromEmail = $ConfigObject->Get('NotificationSenderEmail');

        # send notification
        my $From = $ConfigObject->Get('NotificationSenderName') . ' <'
            . $FromEmail . '>';

        # security part
        my $SecurityOptions = $Self->SecurityOptionsGet( %Param, FromEmail => $FromEmail );
        return if !$SecurityOptions;

        my $Sent = $Kernel::OM->Get('Email')->Send(
            From       => $From,
            To         => $Recipient{Email},
            Subject    => $Notification{Subject},
            MimeType   => $Notification{ContentType},
            Type       => $Notification{ContentType},
            Charset    => 'utf-8',
            Body       => $Notification{Body},
            Loop       => 1,
            Attachment => $Param{Attachments},
            %{$SecurityOptions},
        );

        if ( !$Sent ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to agent '$Recipient{Email} ",
            );

            return;
        }

        if (
            IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle})
            && $Param{Notification}->{Data}->{CreateArticle}->[0]
        ) {
            # create an article if requested
            my $ArticleID = $Self->CreateArticle(
                %Param,
                %{$SecurityOptions},
                Recipient => \%Recipient,
                Address   => {
                    RealName => $ConfigObject->Get('NotificationSenderName'),
                    Email    => $FromEmail,
                }
            );
        }

        # log event
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Sent agent '$Notification{Name}' notification to '$Recipient{Email}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleAgentNotification',
            Data  => {
                TicketID      => $Param{TicketID},
                RecipientID   => $Recipient{UserID},     # out of office-substitute notification
                RecipientMail => $Recipient{Email},
                Notification  => \%Notification,
                Attachment    => $Param{Attachments},
            },
            UserID => $Param{UserID},
        };
    }
    else {
        # get queue object
        my $QueueObject = $Kernel::OM->Get('Queue');

        # get article
        my %Article = $TicketObject->ArticleLastCustomerArticle(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        # set "From" address from Article if exist, otherwise use ticket information, see bug# 9035
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );
        my $QueueID = $Ticket{QueueID};

        # get queue
        my %Queue = $QueueObject->QueueGet(
            ID => $QueueID,
        );

        my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
            QueueID => $QueueID
        );

        # security part
        my $SecurityOptions = $Self->SecurityOptionsGet(
            %Param,
            FromEmail => $Address{Email},
            Queue     => \%Queue
        );
        return if !$SecurityOptions;

        my $Sent = $Kernel::OM->Get('Email')->Send(
            From       => "$Address{RealName} <$Address{Email}>",
            To         => $Recipient{Email},
            Subject    => $Notification{Subject},
            MimeType   => $Notification{ContentType},
            Type       => $Notification{ContentType},
            Charset    => 'utf-8',
            Body       => $Notification{Body},
            Loop       => 1,
            Attachment => $Param{Attachments},
            %{$SecurityOptions},
        );

        if ( !$Sent ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to customer '$Recipient{Email} ",
            );

            return;
        }

        my $ArticleID;
        if (
            IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle})
            && $Param{Notification}->{Data}->{CreateArticle}->[0]
        ) {
            # create an article if requested
            $ArticleID = $Self->CreateArticle(
                %Param,
                %{$SecurityOptions},
                Recipient => \%Recipient,
                Address   => \%Address,
            );
        }

        # log event
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Sent customer '$Notification{Name}' notification to '$Recipient{Email}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleCustomerNotification',
            Data  => {
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
            },
            UserID => $Param{UserID},
        };
    }

    return 1;
}

sub GetTransportRecipients {
    my ($Self, %Param) = @_;

    for my $Needed (qw(Notification)) {
        if (!$Param{$Needed}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    my @Recipients;

    # get recipients by RecipientEmail
    if ( IsArrayRefWithData($Param{Notification}->{Data}->{RecipientEmail}) ) {
        my $RecipientString = $Param{Notification}->{Data}->{RecipientEmail}->[0];

        # check and replace placeholders
        if ($RecipientString =~ m/(<|&lt;)KIX_.+/) {
            my $Data = {};
            if ( $Param{ArticleID} ) {
                $Data->{ArticleID} = $Param{ArticleID};
            }

            $RecipientString = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                RichText => 0,
                Text     => $RecipientString,
                TicketID => $Param{TicketID},
                Data     => $Data,
                UserID   => $Param{UserID} || 1,
            );
        }

        # parse mail addresses
        my @ParsedMailAddresses = Email::Address::XS->parse($RecipientString);

        foreach my $MailAddress (@ParsedMailAddresses) {
            my %Recipient;
            $Recipient{Realname} = q{};
            $Recipient{Type}     = 'Customer';
            $Recipient{Email}    = $MailAddress->address;

            # check if we have a specified channel
            if ($Param{Notification}->{Data}->{ChannelID}) {
                $Recipient{NotificationChannel} = $Kernel::OM->Get('Channel')->ChannelLookup(
                    ID => $Param{Notification}->{Data}->{ChannelID}->[0]
                ) || 'email';
            }

            # check recipients
            if ($Recipient{Email} && $Recipient{Email} =~ /@/) {
                push @Recipients, \%Recipient;
            }
        }
    }

    # get object
    my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

    # get dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => [ 'Ticket' ],
    );

    # get dynamic fields config
    my %DynamicFieldConfig;
    for my $DynamicField (@{$DynamicFieldList}) {
        $DynamicFieldConfig{ $DynamicField->{ID} } = \%{$DynamicField};
    }

    # get recipients by RecipientAgentDF
    if (
        $Param{Notification}->{Data}->{RecipientAgentDF}
            && ref($Param{Notification}->{Data}->{RecipientAgentDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID (sort(@{$Param{Notification}->{Data}->{RecipientAgentDF}})) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Agent',
            );
            push(@Recipients, \%Recipient);
        }
    }

    # get recipients by RecipientCustomerDF
    if (
        $Param{Notification}->{Data}->{RecipientCustomerDF}
            && ref($Param{Notification}->{Data}->{RecipientCustomerDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID (sort(@{$Param{Notification}->{Data}->{RecipientCustomerDF}})) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Customer',
            );
            push(@Recipients, \%Recipient);
        }
    }

    return @Recipients;
}

sub IsUsable {
    my ( $Self, %Param ) = @_;

    # define if this transport is usable on
    # this specific moment
    return 1;
}

sub SecurityOptionsGet {
    my ( $Self, %Param ) = @_;

    return {};
}

sub CreateArticle {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Address Notification Recipient TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my $Channel = 'note';
    if ( IsArrayRefWithData( $Param{Notification}->{Data}->{Channel} ) ) {
        $Channel = $Param{Notification}->{Data}->{Channel}->[0];
    }

    my $VisibleForCustomer = 0;
    if ( IsArrayRefWithData( $Param{Notification}->{Data}->{VisibleForCustomer} ) ) {
        $VisibleForCustomer = $Param{Notification}->{Data}->{VisibleForCustomer}->[0];
    }

    my $ArticleID = $TicketObject->ArticleCreate(
        Channel        => $Channel,
        CustomerVisible => $VisibleForCustomer,
        SenderType     => 'system',
        TicketID       => $Param{TicketID},
        HistoryType    => $Param{Recipient}->{Type} eq 'Agent' ? 'SendAgentNotification' : 'SendCustomerNotification',
        HistoryComment => $Param{Recipient}->{Type} eq 'Agent' ? "\%\%$Param{Notification}->{Name}\%\%$Param{Recipient}->{UserLogin}\%\%Email" : "\%\%$Param{Recipient}->{Email}",
        From           => "$Param{Address}->{RealName} <$Param{Address}->{Email}>",
        To             => $Param{Recipient}->{Email},
        Subject        => $Param{Notification}->{Subject},
        Body           => $Param{Notification}->{Body},
        MimeType       => $Param{Notification}->{ContentType},
        Type           => $Param{Notification}->{ContentType},
        Charset        => 'utf-8',
        UserID         => $Param{UserID},
        Loop           => 1,
        Attachment     => $Param{Attachments},
        %{$Param{SecurityOptions}},
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "'$Param{Notification}->{Name}' notification could not be sent to customer '$Param{Recipient}->{Email} ",
        );

        return;
    }

    # if required mark new article as seen for all users
    if ( $Param{Notification}->{Data}->{MarkAsSeenForAgents} ) {
        my %UserList = $Kernel::OM->Get('User')->UserList();
        for my $UserID ( keys %UserList ) {
            $TicketObject->ArticleFlagSet(
                ArticleID => $ArticleID,
                Key       => 'Seen',
                Value     => 1,
                UserID    => $UserID,
            );
        }
    }

    return $ArticleID;
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
