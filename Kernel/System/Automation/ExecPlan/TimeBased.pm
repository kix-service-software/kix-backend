# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::ExecPlan::TimeBased;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::ExecPlan::Common
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

Kernel::System::Automation::ExecPlan::TimeBased - execution plan type for automation lib

=head1 SYNOPSIS

Provides a simple time based execution of jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this execution plan module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description('Allows a time based execution of automation jobs. At least one weekday and time must be configured.');
    $Self->AddOption(
        Name        => 'Weekday',
        Label       => 'Weekday',
        Description => 'An array of weekdays (Mon,Tue,Wed,Thu,Fri,Sat,Sun) when the job should be executed.',
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Time',
        Label       => 'Time',
        Description => 'An array of times when the job should be executed on every configured weekday.',
        Required    => 1,
    );

    return;
}

=item Validate()

Validates the configuration hash. Returns 1 if the config is valid and nothing is not.

Example:
    my $Result = $Object->Validate(Config => {});

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Config!',
        );
        return;
    }

    return 1;
}

=item Check()

Check if the criteria are met, based on the given date+time. Returns 1 if the job can be executed and 0 if not.

Example:
    my $CanExecute = $Object->Check(
        Time   => '2019-10-25 13:55:26',
        Config => {},
    );

=cut

sub Check {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Time} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Time!',
        );
        return;
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
