# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# Copyrigth (C) 2025 Alex Zey@EUF
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::FollowUpCheck::AttachmentsFilename;

use strict;
use warnings;

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our @ObjectDependencies = (
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get all attachments from the email
    my @Attachments = $Self->{ParserObject}->GetAttachments();

    # do not check inline attachments
    @Attachments = grep { defined $_->{ContentDisposition} && $_->{ContentDisposition} ne 'inline' } @Attachments;

    my @Result = ();

    ATTACHMENT:
    for my $Attachment (@Attachments) {
        my @TnArray = $Kernel::OM->Get('Ticket')->GetTNArrayByString( $Attachment->{Filename} );
        if (@TnArray) {
            push (@Result, @TnArray);
        }
    }

    return @Result;
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
