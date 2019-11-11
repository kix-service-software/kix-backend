# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::ExecPlan::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation::ExecPlan::Common - execution plan type base class for automation lib

=head1 SYNOPSIS

Provides the base class methods for execution plan modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TimeBasedExecPlanObject = $Kernel::OM->Get('Kernel::System::Automation::ExecPlan::TimeBased');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->Describe();

    return $Self;
}

=item Describe()

Describe this execution plan module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->{Definition} = {};

    return 1;
}

=item DefinitionGet()

get the definition of this execution plan module.

Example:
    my $Config = $Object->DefinitionGet();

=cut

sub DefinitionGet {
    my ( $Self, $Description ) = @_;

    return %{$Self->{Definition}};
}

=item Description()

Add a description for this execution plan module.

Example:
    $Self->Description('This is just a test');

=cut

sub Description {
    my ( $Self, $Description ) = @_;

    $Self->{Definition}->{Description} = $Description;

    return 1;
}

=item AddOption()

Add a new option for this execution plan module.

Example:
    $Self->AddOption(
        Name        => 'Testoption',
        Description => 'This is just a test option.',
        Required    => 1
    );

=cut

sub AddOption {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }

    $Self->{Definition}->{Options}->{$Param{Name}} = \%Param;

    return 1;
}

=item Validate()

Validates the configuration hash. Returns 1 if the config is valid and nothing if not.

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

=item Run()

Check if the criteria are met, based on the given event. Returns 1 if the job can be executed and 0 if not.

Example:
    my $CanExecute = $Object->Run();

=cut

sub Run {
    my ( $Self, %Param ) = @_;

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
