# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Reporting::Helper::ParameterConsumer
);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common - output handler base class for reporting lib data source GenericSQL

=head1 SYNOPSIS

Provides the base class methods for GenericSQL output handler modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $Object = $Kernel::OM->Get('Automation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->Init();
    $Self->Describe();

    return $Self;
}

=item Init()

Initialize this output handler module.

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->{Definition} = {};

    return 1;
}

=item DefinitionGet()

get the definition of this output handler module.

Example:
    my %Definition = $Object->DefinitionGet();

=cut

sub DefinitionGet {
    my ( $Self ) = @_;

    return %{$Self->{Definition}};
}

=item Description()

Add a description for this output handler module.

Example:
    $Self->Description('This is just a test');

=cut

sub Description {
    my ( $Self, $Description ) = @_;

    $Self->{Definition}->{Description} = $Description;

    return 1;
}

=item AddOption()

Add a new option for this output handler module.

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
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }

    $Self->{Definition}->{Options}->{$Param{Name}} = \%Param;

    return 1;
}

=item ValidateConfig()

Validates the required config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Config!',
        );
        return;
    }

    foreach my $Option ( sort keys %{$Self->{Definition}->{Options}} ) {
        next if !$Self->{Definition}->{Options}->{$Option}->{Required};

        if ( !exists $Param{Config}->{$Option} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Required option \"$Option\" missing!",
            );
            return;
        }
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
