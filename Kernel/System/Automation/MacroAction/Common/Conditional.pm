# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common::Conditional;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::Conditional - A module to loop over given values

=head1 SYNOPSIS

All Conditional functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Execute the depending macro if the logical expression is true.'));
    $Self->AddOption(
        Name        => 'If',
        Label       => Kernel::Language::Translatable('If'),
        Description => Kernel::Language::Translatable('The logical expression to evaluate.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'MacroID',
        Label       => Kernel::Language::Translatable('MacroID'),
        Description => Kernel::Language::Translatable('The ID of the macro to execute if the logical expression is true.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        ObjectID => 123,
        Config   => {
            If  => 'a && !b || c',
            MacroID => 123,
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $Values = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $Param{Config}->{If},
        TicketID => $Param{ObjectID},
        Data     => {},
        UserID   => $Param{UserID},
        Language => 'en' # to not translate values
    );

    # evaluate expression - we use a simple string eval a this time, because there are not that much alternatives
    my $EvalResult = eval $Param{Config}->{If};
    if ( $EvalResult ) {
        my $Result = $Kernel::OM->Get('Automation')->MacroExecute(
            ID       => $Param{Config}->{MacroID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID}
        );
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
