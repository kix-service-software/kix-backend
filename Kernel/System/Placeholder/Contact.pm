# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
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

our @ObjectDependencies = (
    'Contact',
    'Log',
    'Organisation',
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

    my %Contact;
    if ( $Param{Ticket}->{ContactID} || $Param{Data}->{ContactID} ) {

        my $ContactID = $Param{Data}->{ContactID} || $Param{Ticket}->{ContactID};

        %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID,
        );
        if (IsHashRefWithData(\%Contact)) {
            $Contact{Login} = $Contact{AssignedUserID} ? $Kernel::OM->Get('User')->UserLookup(
                UserID => $Contact{AssignedUserID},
            ) : '',
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

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Contact );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    # TODO: should have its own module - currently for CUSTOMERDATA placeholder and its cleanup
    # replace organisation placeholder
    $Tag = $Self->{Start} . 'KIX_ORG_';

    my %Organisation;
    if ( $Param{Ticket}->{OrganisationID} || $Param{Data}->{OrganisationID} ) {

        my $OrganisationID = $Param{Data}->{OrganisationID} || $Param{Ticket}->{OrganisationID};

        %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $OrganisationID,
        );

        # HTML quoting of content
        if ( $Param{RichText} ) {
            for my $Attribute ( keys %Organisation ) {
                next if !$Organisation{$Attribute};
                $Organisation{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                    String => $Organisation{$Attribute},
                );
            }
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Organisation );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    # TODO: deprecated - keep old placeholders for backward compatibility until refactoring
    # get customer data and replace it with <KIX_CUSTOMER_DATA_...
    my $CustomerTag    = $Self->{Start} . 'KIX_CUSTOMERDATA_';
    my $OldCustomerTag = $Self->{Start} . 'KIX_CUSTOMER_DATA_';

    if (IsHashRefWithData(\%Contact)) {
        for my $Attribute ( keys %Contact ) {
            next if !$Contact{$Attribute};
            $Contact{'User' . $Attribute} = $Contact{$Attribute};
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$CustomerTag|$OldCustomerTag", %Contact );
    }
    if (IsHashRefWithData(\%Organisation)) {
        for my $Attribute ( keys %Organisation ) {
            next if !$Organisation{$Attribute};
            $Organisation{'CustomerCompany' . $Attribute} = $Organisation{$Attribute};
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$CustomerTag|$OldCustomerTag", %Organisation );
    }

    # cleanup
    $Param{Text} =~ s/(?:$CustomerTag|$OldCustomerTag).+?$Self->{End}/$Param{ReplaceNotFound}/gi;

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
