# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'User',
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
        Name        => 'ReplyTo',
        Label       => Kernel::Language::Translatable('ReplyTo'),
        Description => Kernel::Language::Translatable('(Optional) The email address an answer should be send to of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'DoNotSendEmail',
        Label       => Kernel::Language::Translatable('DoNotSendEmail'),
        Description => Kernel::Language::Translatable('(Optional) Prevent sending of the new article by the system.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'MessageID',
        Label       => Kernel::Language::Translatable('MessageID'),
        Description => Kernel::Language::Translatable('(Optional) The message id of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'InReplyTo',
        Label       => Kernel::Language::Translatable('InReplyTo'),
        Description => Kernel::Language::Translatable('(Optional) A message id the new article is a reply to.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'References',
        Label       => Kernel::Language::Translatable('References'),
        Description => Kernel::Language::Translatable('(Optional) Message ids of references of the new article.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'CustomerVisible',
        Label       => Kernel::Language::Translatable('Show in Customer Portal'),
        Description => Kernel::Language::Translatable('If the new article is visible for customers'),
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
        Name        => 'AccountTime',
        Label       => Kernel::Language::Translatable('Account Time'),
        Description => Kernel::Language::Translatable('An integer value which will be accounted for the new article (as minutes).'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttachmentObject1',
        Label       => Kernel::Language::Translatable('Attachment Object 1'),
        Description => Kernel::Language::Translatable('An attachment object containing the attributes "Filename", "ContentType" and "Content" generated by the macro action "AssembleObject". Binary content needs to be base64 coded.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttachmentObject2',
        Label       => Kernel::Language::Translatable('Attachment Object 2'),
        Description => Kernel::Language::Translatable('An attachment object containing the attributes "Filename", "ContentType" and "Content" generated by the macro action "AssembleObject". Binary content needs to be base64 coded.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttachmentObject3',
        Label       => Kernel::Language::Translatable('Attachment Object 3'),
        Description => Kernel::Language::Translatable('An attachment object containing the attributes "Filename", "ContentType" and "Content" generated by the macro action "AssembleObject". Binary content needs to be base64 coded.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttachmentObject4',
        Label       => Kernel::Language::Translatable('Attachment Object 4'),
        Description => Kernel::Language::Translatable('An attachment object containing the attributes "Filename", "ContentType" and "Content" generated by the macro action "AssembleObject". Binary content needs to be base64 coded.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'AttachmentObject5',
        Label       => Kernel::Language::Translatable('Attachment Object 5'),
        Description => Kernel::Language::Translatable('An attachment object containing the attributes "Filename", "ContentType" and "Content" generated by the macro action "AssembleObject". Binary content needs to be base64 coded.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'ArticleDynamicFieldList',
        Label       => Kernel::Language::Translatable('Dynamic Fields'),
        Description => Kernel::Language::Translatable('The dynamic fields of the new article.'),
        Required    => 0,
    );

    # FIXME: add if necessary
    # Charset          => 'utf-8',                                # 'ISO-8859-15'
    # MimeType         => 'text/plain',
    # HistoryType      => 'OwnerUpdate',                          # EmailCustomer|Move|AddNote|PriorityUpdate|...
    # HistoryComment   => 'Some free text!',
    # UnlockOnAway     => 1,                                      # Unlock ticket if owner is away
    # ForceNotificationToUserID
    # ExcludeNotificationToUserID
    # ExcludeMuteNotificationToUserID

    $Self->AddResult(
        Name        => 'NewArticleID',
        Description => Kernel::Language::Translatable('The ID of the new article.'),
    );

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

    %Param = $Self->_PrepareEventData(%Param);

    my %ArticleData = $Kernel::OM->Get('Ticket')->PrepareArticle(
        %{ $Param{Config} },
        TicketID   => $Param{TicketID},
        UserID     => $Param{UserID},
        Data       => $Param{EventData}
    );

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        %ArticleData,
        TicketID   => $Param{TicketID},
        UserID     => $Param{UserID}
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - creating new article failed!",
            UserID   => $Param{UserID}
        );
        return;
    }

    $Self->_SetArticleDynamicFields(%Param, NewArticleID => $ArticleID);

    $Self->SetResult(Name => 'NewArticleID', Value => $ArticleID);

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

    if ( $Param{Config}->{AccountTime} && $Param{Config}->{AccountTime} !~ m/^(<|&lt;)KIX_.+>|\$\{\w+\}$/ ) {
        return 1 if (
            $Param{Config}->{AccountTime} =~ m/^-?\d+$/ &&
            $Param{Config}->{AccountTime} <= 86400 &&
            $Param{Config}->{AccountTime} >= -86400
        );

        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Validation of parameter \"AccountTime\" failed."
            );
        }
        return;
    }

    return 1;
}

sub _SetArticleDynamicFields {
    my ( $Self, %Param ) = @_;

    # set dynamic fields
    if ( $Param{NewArticleID} && IsArrayRefWithData( $Param{Config}->{ArticleDynamicFieldList} ) ) {

        my $TemplateGeneratorObject   = $Kernel::OM->Get('TemplateGenerator');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

        # get the dynamic fields
        my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => [ 'Article' ],
        );

        # create a Dynamic Fields lookup table (by name)
        my %DynamicFieldLookup;
        for my $DynamicField ( @{$DynamicFieldList} ) {
            next if !$DynamicField;
            next if !IsHashRefWithData($DynamicField);
            next if !$DynamicField->{Name};
            $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
        }

        my %Values;
        DYNAMICFIELD:
        foreach my $DynamicField (@{$Param{Config}->{ArticleDynamicFieldList}}) {
            next if (
                !IsArrayRefWithData($DynamicField)
                    || !$DynamicField->[0]
                    || !IsHashRefWithData($DynamicFieldLookup{$DynamicField->[0]})
            );

            my $ReplacedValue = $Self->_ReplaceValuePlaceholder(
                %Param,
                Value => $DynamicField->[1],
                HandleKeyLikeObjectValue => 1
            );

            next if (!$ReplacedValue);

            my @ExistingValuesForGivenDF = $Values{$DynamicField->[0]} ? @{$Values{$DynamicField->[0]}} : ();

            if (IsArrayRefWithData($ReplacedValue)) {
                push(@ExistingValuesForGivenDF, @{$ReplacedValue});
            }
            else {
                push(@ExistingValuesForGivenDF, ($ReplacedValue));
            }

            @ExistingValuesForGivenDF = $Kernel::OM->Get('Main')->GetUnique(@ExistingValuesForGivenDF);

            $Values{$DynamicField->[0]} = \@ExistingValuesForGivenDF;
        }

        for my $v (keys %Values) {
            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldLookup{$v},
                ObjectID           => $Param{NewArticleID},
                Value              => $Values{$v},
                UserID             => $Param{UserID},
            );
        }
    }
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
