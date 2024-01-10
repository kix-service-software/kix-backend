# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfig::OptionType::Base;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::SysConfig::OptionType::Base - Basic type lib

=head1 SYNOPSIS

Basic functions for all SysConfig option types.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $OptionTypeObject = $Kernel::OM->Get('SysConfig::OptionType::xyz');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set the debug flag
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=item ValidateSetting()

Base method to be overridden in type modules.

    my $Success = $OptionTypeObject->ValidateSetting(
        Setting => {...},
    );

=cut

sub ValidateSetting {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Setting)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    if ( !$Self->{OptionTypeModules}->{$Param{Type}} ) {
        my $Backend = 'Kernel::System::SysConfig::OptionType::' . $Param{Type};

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
        }

        $Self->{OptionTypeModules}->{$Param{Type}} = $BackendObject;
    }

    # check type
    if ( !$Self->{OptionTypeModules}->{$Param{Type}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Item has unknown type \"$Param{Type}\".",
        );
        return;
    }

    return $Self->{OptionTypeModules}->{$Param{Type}}->ValidateSetting(
        Setting => $Param{Setting}
    );
}

=item Extend()

Base method to be overridden in type modules.

    my $Success = $OptionTypeObject->Extend(
        Value  => ...,
        Extend => ...,
    );

=cut

sub Extend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Setting)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    if ( !$Self->{OptionTypeModules}->{$Param{Type}} ) {
        my $Backend = 'Kernel::System::SysConfig::OptionType::' . $Param{Type};

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
        }

        $Self->{OptionTypeModules}->{$Param{Type}} = $BackendObject;
    }

    # check type
    if ( !$Self->{OptionTypeModules}->{$Param{Type}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Item has unknown type \"$Param{Type}\".",
        );
        return;
    }

    if ( $Self->{OptionTypeModules}->{$Param{Type}}->can('Extend') ) {
        return $Self->{OptionTypeModules}->{$Param{Type}}->Extend(
            %Param
        );
    }

    return;
}

=item Encode()

Base method to be overridden in type modules if needed.

    my $EncodedDataValue = $OptionTypeObject->Encode(
        Data => '...',
    );

=cut

sub Encode {
    my ( $Self, %Param ) = @_;

    return $Param{Data};
}

=item Decode()

Base method to be overridden in type modules if needed.

    my $DecodedData = $OptionTypeObject->Decode(
        Data => '...',
    );

=cut

sub Decode {
    my ( $Self, %Param ) = @_;

    return $Param{Data};
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
