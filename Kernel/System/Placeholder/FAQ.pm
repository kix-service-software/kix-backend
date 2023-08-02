# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::FAQ;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'HTMLUtils',
    'Log',
    'FAQ',
);

=head1 NAME

Kernel::System::Placeholder::FAQ

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # replace article placeholders
    my $Tag = $Self->{Start} . 'KIX_FAQ_';

    return $Param{Text} if ($Param{Text} !~ m/$Tag/);

    return $Param{Text} if ($Param{ObjectType} ne 'FAQ' || !$Param{ObjectID});

    $Self->{FAQObject} = $Kernel::OM->Get('FAQ');

    if ( $Self->{FAQObject} ) {
        my %FAQArticle = $Self->{FAQObject}->FAQGet(
            ItemID     => $Param{ObjectID},
            ItemFields => ( $Param{Text} =~ m/$Tag Field.+? $Self->{End}/x ) ? 1 : 0,
            UserID     => $Param{UserID}
        );

        if (IsHashRefWithData(\%FAQArticle)) {
            $Self->_PrepareFAQAttributes(
                %Param,
                Tag     => $Tag,
                Article => \%FAQArticle
            );

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$Tag", %FAQArticle );
        }
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    return $Param{Text};
}

sub _PrepareFAQAttributes {
    my ( $Self, %Param ) = @_;

    $Param{Article}->{ID} = $Param{Article}->{ItemID};

    $Param{Article}->{CustomerVisible} = $Param{Article}->{Visibility} &&
        ($Param{Article}->{Visibility} eq 'external' || $Param{Article}->{Visibility} eq 'public' ) ?
        "Yes" : "No";

    if ( $Param{Article}->{CategoryID} ) {
        my %Category = $Self->{FAQObject}->CategoryGet(
            CategoryID => $Param{Article}->{CategoryID},
            UserID     => $Param{UserID}
        );
        if (IsHashRefWithData(\%Category)) {
            $Param{Article}->{Category} = $Category{Name};
            $Param{Article}->{CategoryFullname} = $Category{Fullname};
        }
    }

    # html quoting of content
    if ( $Param{RichText} ) {
        for ( keys %{$Param{Article}} ) {
            next if !$Param{Article}->{$_};
            $Param{Article}->{$_} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $Param{Article}->{$_},
            );
        }
    }

    my $FieldsGiven;
    for my $Field ( 1..6 ) {
        if ($Param{Article}->{"Field$Field"}) {
            $FieldsGiven = 1;
            last;
        }
    }

    if ($FieldsGiven) {
        for my $Field ( 1..6 ) {
            if ( $Param{Article}->{"Field$Field"} && $Param{Text} =~ m/$Param{Tag} Field$Field NoInline $Self->{End}/x ) {
                $Param{Article}->{"Field$Field" . "NoInline"} = $Param{Article}->{"Field$Field"};
                $Param{Article}->{"Field$Field" . "NoInline"} =~ s/<img.+?src="cid:.+?>//g;
            }
        }

        if ( $Param{Text} =~ m/$Param{Tag} Field\d $Self->{End}/x ) {
            $Self->_PrepareImages(%Param);
        }
    }
}

sub _PrepareImages {
    my ( $Self, %Param ) = @_;

    my @AttachmentIndex = $Self->{FAQObject}->AttachmentIndex(
        ItemID => $Param{Article}->{ID},
        UserID => $Param{UserID}
    );

    if (IsArrayRefWithData(\@AttachmentIndex)) {
        my @InlineAttachments;

        for my $Attachment ( @AttachmentIndex ) {
            if (
                $Attachment->{Disposition} &&
                $Attachment->{Disposition} eq 'inline' &&
                $Attachment->{ContentID}
            ) {
                my %Attachment = $Self->{FAQObject}->AttachmentGet(
                    ItemID => $Param{Article}->{ID},
                    FileID => $Attachment->{FileID},
                    UserID => $Param{UserID}
                );
                if (IsHashRefWithData(\%Attachment)) {
                    push(@InlineAttachments, \%Attachment);
                }
            }
        }

        if (scalar @InlineAttachments) {
            for my $Attachment ( @InlineAttachments ) {
                my $Content = MIME::Base64::encode_base64( $Attachment->{Content}, '' );

                my $ContentType = $Attachment->{ContentType};
                $ContentType =~ s/"/\'/g;

                my $ReplaceString = "data:$ContentType;base64,$Content";

                # remove < and > arround id (eg. <123456> ==> 1323456)
                my $ContentID = substr($Attachment->{ContentID}, 1, -1);

                for my $Field ( 1..6 ) {
                    $Param{Article}->{"Field$Field"} =~ s/cid:$ContentID/$ReplaceString/g;
                }
            }
        }
    }
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
