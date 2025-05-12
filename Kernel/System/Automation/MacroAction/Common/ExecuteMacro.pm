# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common::ExecuteMacro;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::ExecuteMacro - A module to execute a given macro

=head1 SYNOPSIS

All ExecuteMacro functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Executes a given macro.'));
    $Self->AddOption(
        Name        => 'ObjectID',
        Label       => Kernel::Language::Translatable('ObjectID'),
        Description => Kernel::Language::Translatable('The ID of the object to run the macro for.'),
        Required    => 0,
        Placeholder => {
            Richtext  => 0,
            Translate => 0,
        },
    );
    $Self->AddOption(
        Name        => 'MacroID',
        Label       => Kernel::Language::Translatable('Macro'),
        Description => Kernel::Language::Translatable('The macro to execute.'),
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
            ObjectID => 1,
            MacroID  => 123,
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    # FIXME: use given instance
    my $AutomationObject = $Param{AutomationInstance} || $Kernel::OM->Get('Automation');

    my $Result = $AutomationObject->MacroExecute(
        ID       => $Param{Config}->{MacroID},
        ObjectID => $Param{Config}->{ObjectID},
        UserID   => $Param{UserID},

        # keep event data if given
        EventData => $Self->{EventData} || $Param{EventData},

        # keep additional data
        AdditionalData => $Param{AdditionalData},

        # keep root object id and type
        RootObjectID  => $Self->{RootObjectID} || $Param{ObjectID},
        RootMacroType => $Self->{RootMacroType} || $Param{MacroType},
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
