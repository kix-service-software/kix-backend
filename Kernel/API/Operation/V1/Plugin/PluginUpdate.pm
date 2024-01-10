# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Plugin::PluginUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Plugin::PluginUpdate - API Plugin Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'Product' => {
            Required => 1
        },
        'Plugin' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform UserUpdate Operation. This will return the updated UserID.

    my $Result = $OperationObject->Run(
        Data => {
            Plugin => {
                ... # plugin specific triggers
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            Product => '',                          # the product
            Error => {                              # should not return errors
                    Code    => 'some code'
                    Message => 'Error Description'
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim User parameter
    my $Plugin = $Self->_Trim(
        Data => $Param{Data}->{Plugin},
    );

    # check Plugin exists
    my $Exists = $Kernel::OM->Get('Installation')->PluginAvailable(
        Plugin => $Param{Data}->{Product},
        UserID => 1,
    );

    if ( !$Exists ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my @ActionList = $Kernel::OM->Get('Installation')->PluginActionList(
        Plugin => $Param{Data}->{Product},
        UserID => 1,
    );

    if ( !@ActionList ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Plugin $Param{Data}->{Product} does not support any actions!"
        );
    }

    # execute action function if given
    my $Found = 0;
    foreach my $Action ( @ActionList ) {
        next if !$Plugin->{'Exec'.$Action->{Name}};

        $Found = 1;
        my $Success = $Kernel::OM->Get('Installation')->PluginActionExecute(
            Plugin   => $Param{Data}->{Product},
            Action   => $Action->{Name},
            UserID   => $Self->{Authorization}->{UserID},
            %{$Plugin},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code => 'Object.UnableToUpdate',
            );
        }
    }

    if ( !$Found ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Requested action(s) not supported by plugin $Param{Data}->{Product}!"
        );
    }

    return $Self->_Success(
        Product => $Param{Data}->{Product},
    );
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
