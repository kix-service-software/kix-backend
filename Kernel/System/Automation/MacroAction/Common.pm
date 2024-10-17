# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common;

use strict;
use warnings;

use utf8;

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

=item Init()

Initialize this macro action module.

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    return 1;
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

    $Self->{MacroResults} //= {};

    my $VariableName = $Self->{ResultVariables}->{$Param{Name}} || $Param{Name};

    $Self->{MacroResults}->{$VariableName} = $Param{Value};

    return 1;
}

=item SetRepeatExecution()

Set repeat execution of backend.

Example:
    $Self->SetRepeatExecution();

=cut

sub SetRepeatExecution {
    my ( $Self, %Param ) = @_;

    $Self->{RepeatExecution} = 1;

    return 1;
}

=item UnsetRepeatExecution()

Unset repeat execution of backend.

Example:
    $Self->UnsetRepeatExecution();

=cut

sub UnsetRepeatExecution {
    my ( $Self, %Param ) = @_;

    $Self->{RepeatExecution} = 0;

    return 1;
}

=item RepeatExecution()

Returns state of repeat execution of backend.

Example:
    $Self->RepeatExecution();

=cut

sub RepeatExecution {
    my ( $Self, %Param ) = @_;

    return $Self->{RepeatExecution};
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
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Config!',
            );
        }
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
                        if ( !$Param{Silent} ) {
                            $Kernel::OM->Get('Log')->Log(
                                Priority => 'error',
                                Message  => "Invalid value \"$Value\" for parameter \"$Option\"! Possible values: " . join(', ', @{$Self->{Definition}->{Options}->{$Option}->{PossibleValues}}),
                            );
                        }
                        return;
                    }
                }
            }
        }

        next if !$Self->{Definition}->{Options}->{$Option}->{Required};

        if ( !exists $Param{Config}->{$Option} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Required parameter \"$Option\" missing!",
                );
            }
            return;
        }
    }

    return 1;
}

=item SetDefaults()

Uses defaults of action options (if given) to set empty parameters in config

Example:
    my $Result = $Self->SetDefaults(
        Config => {}                # required
    );

=cut

sub SetDefaults {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config)) {
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

            # set default value if not given
            if ( !exists $Param{Config}->{$Option->{Name}} && defined $Option->{DefaultValue} ) {
                $Param{Config}->{$Option->{Name}} = $Option->{DefaultValue};
            }
        }
    }

    return 1;

}

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Config UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
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

            # check if the value is given, if required
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

=item _ReplaceValuePlaceholder()

replaces palceholders

Example:
    my $Value = $Self->_ReplaceValuePlaceholder(
        Value     => $SomeValue,
        Richtext  => 0,                  # optional: 0 will be used if omitted
        Translate => 0,                  # optional: 0 will be used if omitted
        UserID    => 1,                  # optional: 1 will be used if omitted
        Data      => {},                 # optional: {} will be used
        HandleKeyLikeObjectValue => 0    # optional: 0 will be used if omitted - if 1 and "Value" is just a "_Key" placeholder it will considered just like a "_ObjectValue" placeholder (needed for backward compatibility)
    );

=cut

sub _ReplaceValuePlaceholder {
    my ( $Self, %Param ) = @_;

    return $Param{Value} if (!$Param{Value} || $Param{Value} !~ m/(<|&lt;)KIX_/);

    my $Data = $Param{EventData} || $Self->{EventData} || {};
    if(IsHashRefWithData($Param{Data})) {
        $Data = {
            %{$Data},
            %{$Param{Data}}
        }
    };
    if(IsHashRefWithData($Param{AdditionalData})) {
        $Data = {
            %{$Data},
            %{$Param{AdditionalData}}
        }
    };

    # handle DF "_Key" placeholder like "_ObjectValue" if value is just this placeholder (no surrounding text) and param is active
    if ($Param{HandleKeyLikeObjectValue} && $Param{Value} =~ m/^<KIX_(?:\w|^>)+_DynamicField_(?:\w+?)_Key>$/) {
        $Param{Value} =~ s/(.+)Key>/${1}ObjectValue>/;
    }

    return $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        Text            => $Param{Value},
        RichText        => $Param{Richtext} || 0,
        Translate       => $Param{Translate} || 0,
        UserID          => $Param{UserID} || 1,
        Data            => $Data,
        ReplaceNotFound => $Param{ReplaceNotFound},

        # FIXME: use correct object id for typ (could be a sub macro of other type)
        # or get and use job type by JobID in $Self
        ObjectType => $Param{MacroType},
        ObjectID   => $Self->{RootObjectID} || $Param{ObjectID}
    );
}

sub _ConvertScalar2ArrayRef {
    my ( $Self, %Param ) = @_;

    my @Data = split( /,/, $Param{Data} );

    # remove any possible heading and tailing white spaces
    for my $Item (@Data) {
        $Item =~ s{\A\s+}{};
        $Item =~ s{\s+\z}{};
    }

    return \@Data;
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
