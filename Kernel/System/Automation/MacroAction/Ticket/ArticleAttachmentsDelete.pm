# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::ArticleAttachmentsDelete;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Automation',
    'Ticket',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::ArticleAttachmentsDelete - A module to delete attachments of articles

=head1 SYNOPSIS

All ArticleAttachmentsDelete functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Deletes attachments of all articles of a ticket. All pattern of a rule have to match. Any keep rule has to match to ignore file for deletion. Any delete rule has to match for a file to be deleted.'));
    $Self->AddOption(
        Name         => 'KeepRules',
        Label        => Kernel::Language::Translatable('Keep Rules'),
        Description  => Kernel::Language::Translatable('Rules for keeping a file. Pattern are in the order Filename, ContentType and Disposition.'),
        Required     => 0,
        DefaultValue => [
            ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
            ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
        ]
    );
    $Self->AddOption(
        Name         => 'DeleteRules',
        Label        => Kernel::Language::Translatable('Delete Rules'),
        Description  => Kernel::Language::Translatable('Rules to delete a file. Pattern are in the order Filename, ContentType and Disposition.'),
        Required     => 1,
        DefaultValue => [
            ['.+','.+','^attachment$']
        ]
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','(?:text/(?:plain|html))','^inline$'],
                ['smime','(?:application\/(?:x-pkcs7|pkcs7))','.+']
            ],
            DeleteRules => [
                ['.+','.+','^attachment$']
            ]
        },
        UserID   => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    # get articles of ticket
    my @ArticleIDs = $Kernel::OM->Get('Ticket')->ArticleIndex(
        TicketID => $Param{TicketID},
    );
    return 1 if ( !@ArticleIDs ) ;

    # process articles
    ARTICLE:
    for my $ArticleID ( @ArticleIDs ) {
        # get attachment index
        my %ArticleAttachmentIndex = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndexRaw(
            ArticleID => $ArticleID,
            UserID    => $Param{UserID},
        );
        next ARTICLE if ( !%ArticleAttachmentIndex );

        # process attachments
        ATTACHMENT:
        for my $AttachmentID ( keys( %ArticleAttachmentIndex ) ) {
            if (
                !$ArticleAttachmentIndex{ $AttachmentID }->{ID}
                || !$ArticleAttachmentIndex{ $AttachmentID }->{Filename}
                || !$ArticleAttachmentIndex{ $AttachmentID }->{ContentType}
                || !$ArticleAttachmentIndex{ $AttachmentID }->{Disposition}
            ) {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Invalid attachment with AttachmentID $AttachmentID!",
                    UserID   => $Param{UserID}
                );

                next ATTACHMENT;
            }

            # check if attachment should be kept
            if ( IsArrayRefWithData( $Param{Config}->{KeepRules} ) ) {
                KEEPRULE:
                for my $KeepRule ( @{ $Param{Config}->{KeepRules} } ) {
                    if (
                        !IsArrayRefWithData( $KeepRule )
                        || !IsStringWithData( $KeepRule->[0] )
                        || !IsStringWithData( $KeepRule->[1] )
                        || !IsStringWithData( $KeepRule->[2] )
                    ) {
                        $Kernel::OM->Get('Automation')->LogError(
                            Referrer => $Self,
                            Message  => "Invalid keep rule!",
                            UserID   => $Param{UserID}
                        );

                        next ATTACHMENT;
                    }

                    if (
                        $ArticleAttachmentIndex{ $AttachmentID }->{Filename} =~ m/$KeepRule->[0]/
                        && $ArticleAttachmentIndex{ $AttachmentID }->{ContentType} =~ m/$KeepRule->[1]/
                        && $ArticleAttachmentIndex{ $AttachmentID }->{Disposition} =~ m/$KeepRule->[2]/
                    ) {
                        if ( $Param{Config}->{Debug} ) {
                            $Kernel::OM->Get('Automation')->LogDebug(
                                Referrer => $Self,
                                Message  => "Kept file \"$ArticleAttachmentIndex{ $AttachmentID }->{Filename}\" from ArticleID $ArticleID!",
                                UserID   => $Param{UserID}
                            );
                        }

                        next ATTACHMENT;
                    }
                }
            }

            # check if attachment should be deleted
            if ( IsArrayRefWithData( $Param{Config}->{DeleteRules} ) ) {
                DELETERULE:
                for my $DeleteRule ( @{ $Param{Config}->{DeleteRules} } ) {
                    if (
                        !IsArrayRefWithData( $DeleteRule )
                        || !IsStringWithData( $DeleteRule->[0] )
                        || !IsStringWithData( $DeleteRule->[1] )
                        || !IsStringWithData( $DeleteRule->[2] )
                    ) {
                        $Kernel::OM->Get('Automation')->LogError(
                            Referrer => $Self,
                            Message  => "Invalid delete rule!",
                            UserID   => $Param{UserID}
                        );

                        next DELETERULE;
                    }

                    if (
                        $ArticleAttachmentIndex{ $AttachmentID }->{Filename} =~ m/$DeleteRule->[0]/
                        && $ArticleAttachmentIndex{ $AttachmentID }->{ContentType} =~ m/$DeleteRule->[1]/
                        && $ArticleAttachmentIndex{ $AttachmentID }->{Disposition} =~ m/$DeleteRule->[2]/
                    ) {
                        my $Success = $Kernel::OM->Get('Ticket')->ArticleDeleteAttachment(
                            AttachmentID => $AttachmentID,
                            ArticleID    => $ArticleID,
                            UserID       => $Param{UserID}
                        );

                        if ( $Success ) {
                            $Kernel::OM->Get('Automation')->LogInfo(
                                Referrer => $Self,
                                Message  => "Deleted file \"$ArticleAttachmentIndex{ $AttachmentID }->{Filename}\" from ArticleID $ArticleID!",
                                UserID   => $Param{UserID}
                            );
                        }
                        else {
                            $Kernel::OM->Get('Automation')->LogError(
                                Referrer => $Self,
                                Message  => "Error deleting AttachmentID $AttachmentID!",
                                UserID   => $Param{UserID}
                            );
                        }

                        last DELETERULE;
                    }
                }
            }
        }
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
