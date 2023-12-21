# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Reject;

use strict;
use warnings;

our @ObjectDependencies = (
    'DynamicField',
    'DynamicField::Backend',
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID InmailUserID GetParam Tn)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my %GetParam = %{ $Param{GetParam} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    my $Comment          = $Param{Comment}          || '';
    my $Lock             = $Param{Lock}             || '';

    # do db insert
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => $Param{TicketID},
        Channel          => $GetParam{'X-KIX-Channel'},
        SenderType       => $GetParam{'X-KIX-SenderType'},
        From             => $GetParam{From},
        ReplyTo          => $GetParam{ReplyTo},
        To               => $GetParam{To},
        Cc               => $GetParam{Cc},
        Subject          => $GetParam{'X-KIX-Subject'} || $GetParam{Subject},
        MessageID        => $GetParam{'Message-ID'},
        InReplyTo        => $GetParam{'In-Reply-To'},
        References       => $GetParam{'References'},
        ContentType      => $GetParam{'Content-Type'},
        Body             => $GetParam{Body},
        UserID           => $Param{InmailUserID},
        HistoryType      => 'FollowUp',
        HistoryComment   => "\%\%$Param{Tn}\%\%$Comment",
        OrigHeader       => \%GetParam,
        DoNotSendEmail   => 1
    );
    if ( !$ArticleID ) {
        return;
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        print "Reject Follow up Ticket\n";
        ATTRIBUTE:
        for my $Attribute ( sort keys %GetParam ) {
            next ATTRIBUTE if !$GetParam{$Attribute};
            print "$Attribute: $GetParam{$Attribute}\n";
        }
    }

    # write plain email to the storage
    $TicketObject->ArticleWritePlain(
        ArticleID => $ArticleID,
        Email     => $Self->{ParserObject}->GetPlainEmail(),
        UserID    => $Param{InmailUserID},
    );

    # write attachments to the storage
    for my $Attachment ( $Self->{ParserObject}->GetAttachments() ) {
        $TicketObject->ArticleWriteAttachment(
            Filename           => $Attachment->{Filename},
            Content            => $Attachment->{Content},
            ContentType        => $Attachment->{ContentType},
            ContentID          => $Attachment->{ContentID},
            ContentAlternative => $Attachment->{ContentAlternative},
            Disposition        => $Attachment->{Disposition},
            ArticleID          => $ArticleID,
            UserID             => $Param{InmailUserID},
        );
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # dynamic fields
    my $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 0,
        ResultType => 'HASH',
        ObjectType => 'Article',
        );

    # set dynamic fields for Article object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};

        my $Key;
        my $CheckKey  = 'X-KIX-FollowUp-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        my $CheckKey2 = 'X-KIX-FollowUp-DynamicField_' . $DynamicFieldList->{$DynamicFieldID};

        if (
            defined( $GetParam{ $CheckKey } )
            && length( $GetParam{ $CheckKey } )
        ) {
            $Key = $CheckKey;
        }
        elsif (
            defined( $GetParam{ $CheckKey2 } )
            && length( $GetParam{ $CheckKey2 } )
        ) {
            $Key = $CheckKey2;
        }

        if ( $Key ) {

            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $ArticleID,
                Value              => $GetParam{$Key},
                UserID             => $Param{InmailUserID},
            );

            if ( $Self->{Debug} > 0 ) {
                print "$Key: " . $GetParam{$Key} . "\n";
            }
        }
    }

    # reverse dynamic field list
    my %DynamicFieldListReversed = reverse %{$DynamicFieldList};

    # set free article text
    my %Values =
        (
        'X-KIX-FollowUp-ArticleKey'   => 'ArticleFreeKey',
        'X-KIX-FollowUp-ArticleValue' => 'ArticleFreeText',
        );
    for my $Item ( sort keys %Values ) {
        for my $Count ( 1 .. 16 ) {
            my $Key = $Item . $Count;
            if (
                defined $GetParam{$Key}
                && length $GetParam{$Key}
                && $DynamicFieldListReversed{ $Values{$Item} . $Count }
                )
            {
                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ $Values{$Item} . $Count },
                );
                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $ArticleID,
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketKey$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    $TicketObject->EventHandler(
        Event => 'ArticleCreateFollowUpReject',
        Data  => {
            ArticleID     => $ArticleID,
            TicketID      => $Param{TicketID},
            OldTicketData => \%Ticket,
        },
        UserID => $Param{InmailUserID},
    );

    # write log
    $Kernel::OM->Get('Log')->Log(
        Priority => 'notice',
        Message  => "Reject FollowUp Article to Ticket [$Param{Tn}] created "
            . "(TicketID=$Param{TicketID}, ArticleID=$ArticleID). $Comment"
    );

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
