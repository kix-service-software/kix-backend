# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Macro::Synchronisation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::Macro::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation::Macro::Synchronisation - macro type for automation lib

=head1 SYNOPSIS

Handles sync macros.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

Run this macro module.

Example:
    my $Result = $Object->Run(
        ObjectID     => 123,
        ExecOrder    => [],
        UserID       => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ObjectID ExecOrder UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    
    # execute all macro action given in the execution order attribute
    foreach my $MacroActionID ( @{$Param{ExecOrder}} ) {
        my $Result = $Kernel::OM->Get('Kernel::System::Automation')->MacroActionExecute(
            ID        => $MacroActionID,
            ObjectID  => $Param{ObjectID},
            UserID    => $Param{UserID},
        );
        # we don't need error handling here since MacroActionExecute did that already and we don't have to abort here
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
