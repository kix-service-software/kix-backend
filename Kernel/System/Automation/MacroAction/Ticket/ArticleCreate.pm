# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::ArticleCreate;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::ArticleCreate - A module to create an article

=head1 SYNOPSIS

All ArticleCreate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Creates an article for a ticket.'));
    $Self->AddOption(
        Name        => 'Channel',
        Label       => Kernel::Language::Translatable('Channel'),
        Description => Kernel::Language::Translatable('(Optional) The channel of the new article. "note" will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'SenderType',
        Label       => Kernel::Language::Translatable('Sender Type'),
        Description => Kernel::Language::Translatable('(Optional) The sender type of the new article. "agent" will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'From',
        Label       => Kernel::Language::Translatable('From'),
        Description => Kernel::Language::Translatable('(Optional) The email address of the sender for the new article. Agent data will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'To',
        Label       => Kernel::Language::Translatable('To'),
        Description => Kernel::Language::Translatable('(Optional) The email addresses of the receiver of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Cc',
        Label       => Kernel::Language::Translatable('Cc'),
        Description => Kernel::Language::Translatable('(Optional) The email addresses of the Cc receiver of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Bcc',
        Label       => Kernel::Language::Translatable('Bcc'),
        Description => Kernel::Language::Translatable('(Optional) The email addresses of the Bcc receiver of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Subject',
        Label       => Kernel::Language::Translatable('Subject'),
        Description => Kernel::Language::Translatable('The subject of the new article.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Body',
        Label       => Kernel::Language::Translatable('Body'),
        Description => Kernel::Language::Translatable('The text of the new article.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'TimeUnits',
        Label       => Kernel::Language::Translatable('TimeUnits'),
        Description => Kernel::Language::Translatable('The time units to add for the new article.'),
        Required    => 0,
    );
    # FIXME: add if necessary
    # $Self->AddOption(
    #     Name        => 'CustomerVisible',
    #     Label       => 'For Customer Visible',
    #     Description => '(Optional) If the new article is visible for customer. Possible are 0 or 1.',
    #     Required    => 0,
    # );
    # Charset          => 'utf-8',                                # 'ISO-8859-15'
    # MimeType         => 'text/plain',
    # HistoryType      => 'OwnerUpdate',                          # EmailCustomer|Move|AddNote|PriorityUpdate|WebRequestCustomer|...
    # HistoryComment   => 'Some free text!',
    # UnlockOnAway     => 1,                                      # Unlock ticket if owner is away
    # ForceNotificationToUserID
    # ExcludeNotificationToUserID
    # ExcludeMuteNotificationToUserID

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            Channel          => 'note',
            SenderType       => 'agent',
            Subject          => 'some short description',
            Body             => 'the message text',
        },
        UserID   => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    # FIXME: needed?
    # convert scalar items into array references
    for my $Attribute ( qw(ForceNotificationToUserID ExcludeNotificationToUserID ExcludeMuteNotificationToUserID) ) {
        if ( IsStringWithData( $Param{Config}->{$Attribute} ) ) {
            $Param{Config}->{$Attribute} = $Self->_ConvertScalar2ArrayRef(
                Data => $Param{Config}->{$Attribute},
            );
        }
    }

    # if "From" is not set use current user
    if ( !$Param{Config}->{From} ) {
        my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->GetContact(
            UserID => $Param{UserID},
        );
        $Param{Config}->{From} = $Contact{Fullname} . ' <' . $Contact{Email} . '>';
    }

    $Param{Config}->{CustomerVisible} = $Param{Config}->{CustomerVisible} || 0,
    $Param{Config}->{Channel} = $Param{Config}->{Channel} || 'note';
    $Param{Config}->{SenderType} = $Param{Config}->{SenderType} || 'agent';
    $Param{Config}->{Charset} = $Param{Config}->{Charset} || 'utf-8';
    $Param{Config}->{MimeType} = $Param{Config}->{MimeType} || 'text/html';
    $Param{Config}->{HistoryType} = $Param{Config}->{HistoryType} || 'AddNote';
    $Param{Config}->{HistoryComment} = $Param{Config}->{HistoryComment} || 'Added during job execution.';

    if ( $Param{Config}->{Channel} ) {
        my $ChannelID = $Kernel::OM->Get('Kernel::System::Channel')->ChannelLookup( Name => $Param{Config}->{Channel} );

        if ( !$ChannelID ) {
            $Kernel::OM->Get('Kernel::System::Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create article for ticket $Param{TicketID}. Can't find channel with name \"$Param{Config}->{Channel}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ( $Param{Config}->{SenderType} ) {
        my $SenderTypeID = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleSenderTypeLookup( SenderType => $Param{Config}->{SenderType} );

        if ( !$SenderTypeID ) {
            $Kernel::OM->Get('Kernel::System::Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create article for ticket $Param{TicketID}. Can't find sender type with name \"$Param{Config}->{SenderType}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }
    $Param{Config}->{Body} = $Kernel::OM->Get('Kernel::System::TemplateGenerator')->ReplacePlaceHolder(
        RichText => 1,
        Text     => $Param{Config}->{Body},
        TicketID => $Param{TicketID},
        Data     => {},
        UserID   => $Param{UserID},
    );
    $Param{Config}->{Subject} = $Kernel::OM->Get('Kernel::System::TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $Param{Config}->{Subject},
        TicketID => $Param{TicketID},
        Data     => {},
        UserID   => $Param{UserID},
    );

    my $ArticleID = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleCreate(
        %{ $Param{Config} },
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Kernel::System::Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - creating new article failed!",
            UserID   => $Param{UserID}
        );
        return;
    }

    return 1;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::ValidateConfig(%Param);

    if ( $Param{Config}->{TimeUnits} && !IsNumber( $Param{Config}->{TimeUnits} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Validation of parameter \"TimeUnits\" failed."
        );
        return;
    }

    return 1;
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
