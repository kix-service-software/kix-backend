# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Safe;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::Conditional - A module to evaluate a logical expression

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

    my $Expression = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{If}
    );

    # make it safe :)
    my $Compartment = new Safe;
    $Compartment->permit_only(qw(:base_core :base_mem :base_loop :base_orig :base_math));

    # evaluate expression - we use a simple Safe string reval atm - better than nothing
    my $EvalResult = $Compartment->reval($Expression, 1);
    if ( $EvalResult ) {

        # FIXME: use given instance
        my $AutomationObject = $Param{AutomationInstance} || $Kernel::OM->Get('Automation');

        my $Result = $AutomationObject->MacroExecute(
            ID       => $Param{Config}->{MacroID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},

            # keep event data if given
            EventData => $Self->{EventData} || $Param{EventData},

            # keep root object id
            RootObjectID => $Self->{RootObjectID} || $Param{ObjectID}
        );
    }
    if ( $@ ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "An error occured while evaluating the logical expression ($@)!",
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
