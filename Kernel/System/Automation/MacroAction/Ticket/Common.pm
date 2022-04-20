# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::Common;

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'Queue',
    'TemplateGenerator',
    'Ticket',
    'Log',
);

=item _CheckParams()

Check if all required parameters are given.

Example:
    my $Result = $Object->_CheckParams(
        TicketID => 123,
        Config   => {
            ...
        }
    );

=cut

sub _ConvertScalar2ArrayRef {
    my ( $Self, %Param ) = @_;

    # FIXME: check if correct
    # BPMX-capeIT
    #    my @Data = split /,/, $Param{Data};
    my @Data = split( '/,/,', $Param{Data} );

    # EO BPMX-capeIT

    # remove any possible heading and tailing white spaces
    for my $Item (@Data) {
        $Item =~ s{\A\s+}{};
        $Item =~ s{\s+\z}{};
    }

    return \@Data;
}

=item _ReplaceValuePlaceholder()

replaces palceholders

Example:
    my $Value = $Self->_ReplaceValuePlaceholder(
        Value     => $SomeValue,
        Richtext  => 0             # optional: 0 will be used if omitted
        Translate => 0             # optional: 0 will be used if omitted
        UserID    => 1             # optional: 1 will be used if omitted
        Data      => {}            # optional: {} will be used
    );

=cut

sub _ReplaceValuePlaceholder {
    my ( $Self, %Param ) = @_;

    return $Param{Value} if (!$Param{Value} || $Param{Value} !~ m/(<|&lt;)KIX_/);

    return $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        Text      => $Param{Value},
        RichText  => $Param{Richtext} || 0,
        Translate => $Param{Translate} || 0,
        UserID    => $Param{UserID} || 1,
        Data      => $Param{Data} || {},
        TicketID  => $Self->{RootObjectID} || $Param{TicketID}
    );
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
