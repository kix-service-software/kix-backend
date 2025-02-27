# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Organisation;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Log',
    'Organisation'
);

=head1 NAME

Kernel::System::Placeholder::Organisation

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

    # replace organisation placeholder
    my $Tag = $Self->{Start} . 'KIX_(?:ORG|ORGANISATION)_';

    if ($Param{Text} =~ m/$Tag/) {
        if (!$Param{Data}->{OrganisationID} && $Param{ObjectType} eq 'Organisation' && $Param{ObjectID}) {
            $Param{Data}->{OrganisationID} = $Param{ObjectID};
        }
        if ( $Param{Data}->{OrganisationID} || $Param{Ticket}->{OrganisationID} ) {

            my $OrganisationID = $Param{Data}->{OrganisationID} || $Param{Ticket}->{OrganisationID};

            my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
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
