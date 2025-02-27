# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Contact;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = qw(
    Contact
    Log
    Organisation
    HTMLUtils
);

=head1 NAME

Kernel::System::Placeholder::Contact

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

    # replace contact placeholders
    my $Tag = $Self->{Start} . 'KIX_CONTACT_';

    if ($Param{Text} =~ m/$Tag/) {
        if (!$Param{Data}->{ContactID} && $Param{ObjectType} eq 'Contact' && $Param{ObjectID}) {
            $Param{Data}->{ContactID} = $Param{ObjectID};
        }

        my %Contact;
        if ( $Param{Data}->{ContactID} || $Param{Ticket}->{ContactID} ) {

            my $ContactID = $Param{Data}->{ContactID} || $Param{Ticket}->{ContactID};

            %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                ID => $ContactID,
            );
            if (IsHashRefWithData(\%Contact)) {
                $Contact{Login} = $Contact{AssignedUserID} ? $Kernel::OM->Get('User')->UserLookup(
                    UserID => $Contact{AssignedUserID},
                ) : '',
                $Contact{UserLogin} = $Contact{Login};
            }

            # HTML quoting of content
            if ( $Param{RichText} ) {
                for my $Attribute ( keys %Contact ) {
                    next if !$Contact{$Attribute};
                    $Contact{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                        String => $Contact{$Attribute},
                    );
                }
            }

            if ($Contact{PrimaryOrganisationID}) {
                my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
                    ID => $Contact{PrimaryOrganisationID}
                );
                if (%Organisation) {
                    $Contact{PrimaryOrganisation} = $Organisation{Name};
                    $Contact{PrimaryOrganisationNumber} = $Organisation{Number};
                }
            }

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Contact );
        }

        # cleanup
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    return $Param{Text};
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
