# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common;

use strict;
use warnings;

use utf8;

use Hash::Flatten;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'Queue',
    'TemplateGenerator',
    'Ticket',
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common - macro action base class for automation lib

=head1 SYNOPSIS

Provides the base class methods for macro action modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MacroActionObject = $Kernel::OM->Get('Automation::MacroAction::Common');

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

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->{Definition} = {};

    return 1;
}

=item DefinitionGet()

get the definition of this macro action module.

Example:
    my %Config = $Object->DefinitionGet();

=cut

sub DefinitionGet {
    my ( $Self ) = @_;

    return %{$Self->{Definition}};
}

=item Description()

Add a description for this macro action module.

Example:
    $Self->Description('This is just a test');

=cut

sub Description {
    my ( $Self, $Description ) = @_;

    $Self->{Definition}->{Description} = $Description;

    return 1;
}

=item AddOption()

Add a new option for this macro action module.

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

    $Self->{Definition}->{Options} //= {};
    $Param{Order} = scalar(keys %{$Self->{Definition}->{Options}}) + 1;
    $Self->{Definition}->{Options}->{$Param{Name}} = \%Param;

    return 1;
}

=item AddResult()

Add a new result definition for this macro action module.

Example:
    $Self->AddResult(
        Name        => 'TicketID',
        Description => 'This is the ID of the created ticket.',
    );

=cut

sub AddResult {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }

    $Self->{Definition}->{Results} //= {};
    $Self->{Definition}->{Results}->{$Param{Name}} = \%Param;

    return 1;
}

=item SetResult()

Assign a value for a result variable.

Example:
    $Self->SetResult(
        Name  => 'TicketID',
        Value => 123,
    );

=cut

sub SetResult {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }
    
    $Self->{Results} //= {};

    my $VariableName = $Self->{ResultVariables}->{$Param{Name}} || $Param{Name};

    $Self->{Results}->{$VariableName} = $Param{Value};

    # include all data of an object as separate values
    if ( IsHashRefWithData($Param{Value}) || IsObject($Param{Value}, $Kernel::OM->GetModuleFor('Automation::Helper::Object')) ) {
        my $FlatData = Hash::Flatten::flatten(
            $Param{Value}
        );
        if ( IsHashRefWithData($FlatData) ) {
            # combine with existing results
            my %TmpHash = map { $VariableName.'.'.$_ => $FlatData->{$_} } keys %{$FlatData};
            $Self->{Results} = {
                %{$Self->{Results}},
                %TmpHash,
            };
        }

        foreach my $Key ( keys %{$Param{Value}} ) {
            $Self->SetResult(
                Name  => $VariableName.'.'.$Key,
                Value => $Param{Value}->{$Key},
            )
        }
    }
    elsif ( IsArrayRefWithData($Param{Value}) ) {
        my $Index = 0;
        foreach my $Item ( @{$Param{Value}} ) {
            $Self->SetResult(
                Name  => $VariableName.':'.$Index++,
                Value => $Item,
            )
        }
    }

    # merge results
    if (IsHashRefWithData($Self->{Results})) {
        %{$Self->{MacroResults}} = (
            %{$Self->{MacroResults}},
            %{$Self->{Results}}
        );
    }

    return 1;
}

=item ValidateConfig()

Validates the required parameters of the config.

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

    return if (ref $Param{Config} ne 'HASH');

    foreach my $Option ( sort keys %{$Self->{Definition}->{Options}} ) {
        if ( IsArrayRefWithData($Self->{Definition}->{Options}->{$Option}->{PossibleValues}) ) {
            # check the value
            if ( exists $Param{Config}->{$Option} ) {
                my %PossibleValues = map { $_ => 1 } @{$Self->{Definition}->{Options}->{$Option}->{PossibleValues}};
                foreach my $Value ( IsArrayRefWithData($Param{Config}->{$Option}) ? @{$Param{Config}->{$Option}} : ( $Param{Config}->{$Option} ) ) {
                    if ( !$PossibleValues{$Value} ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => "Invalid value for parameter \"$Option\"! Possible values: " . join(', ', @{$Self->{Definition}->{Options}->{$Option}->{PossibleValues}}),
                        );
                        return;
                    }
                }
            }
        }

        next if !$Self->{Definition}->{Options}->{$Option}->{Required};

        if ( !exists $Param{Config}->{$Option} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Required parameter \"$Option\" missing!",
            );
            return;
        }
    }

    return 1;
}

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if (ref $Param{Config} ne 'HASH') {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Config is no object!",
        );
        return;
    }

    my %Definition = $Self->DefinitionGet();

    if (IsHashRefWithData(\%Definition) && IsHashRefWithData($Definition{Options})) {
        for my $Option ( values %{$Definition{Options}}) {
            if ($Option->{Required} && !defined $Param{Config}->{$Option->{Name}}) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Option->{Name} in Config!",
                );
                return;
            }
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
