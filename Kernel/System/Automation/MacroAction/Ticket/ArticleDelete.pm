# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::ArticleDelete;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'User',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::ArticleDelete - A module to delete an article

=head1 SYNOPSIS

All ArticleDelete functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Deletes an article of a ticket. Inlcuding dynamic fields, attachments, flags and accounted time.'));
    $Self->AddOption(
        Name        => 'ArticleID',
        Label       => Kernel::Language::Translatable('ArticleID'),
        Description => Kernel::Language::Translatable('(Required) ID of the article which should be deleted.'),
        Required    => 1,
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

    # replace placeholders in non-richtext attributes
    for my $Attribute ( qw(ArticleID) ) {
        next if !defined $Param{Config}->{$Attribute};

        $Param{Config}->{$Attribute} = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value => $Param{Config}->{$Attribute}
        );
    }

    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID => $Param{Config}->{ArticleID}
    );

    if ( !%Article ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't delete article $Article{ArticleID} - article not found!",
            UserID   => $Param{UserID}
        );
        return;
    }
    elsif ( $Article{TicketID} ne $Param{TicketID} ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't delete article $Article{ArticleID} - article not part of ticket $Param{TicketID}!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Ticket')->ArticleDelete(
        ArticleID => $Article{ArticleID},
        UserID    => $Param{UserID}
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't delete article $Article{ArticleID} - deleting article failed!",
            UserID   => $Param{UserID}
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
