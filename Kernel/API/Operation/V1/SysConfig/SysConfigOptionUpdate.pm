# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigOptionUpdate - API SysConfigOption Update Operation backend

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
        'Option' => {
            Required => 1
        },
        'SysConfigOption' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform SysConfigOptionUpdate Operation. This will return the updated SysConfigOptionID.

    my $Result = $OperationObject->Run(
        Data => {
            Option => 'DefaultLanguage',
            SysConfigOption => {
                Value   => ...                # optional
                ValidID => 1                  # optional
            }
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            Option  => 123,                     # ID of the updated SysConfigOption
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate SysConfigOption parameter
    my $SysConfigOption = $Param{Data}->{SysConfigOption};

    # get option
    my %OptionData = $Kernel::OM->Get('SysConfig')->OptionGet(
        Name => $Param{Data}->{Option},
    );

    # update option
    my $Success = $Kernel::OM->Get('SysConfig')->OptionUpdate(
        %OptionData,
        Value   => exists $SysConfigOption->{Value} ? $SysConfigOption->{Value} : $OptionData{Value},
        ValidID => exists $SysConfigOption->{ValidID} ? $SysConfigOption->{ValidID} : $OptionData{ValidID},
        UserID  => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SysConfig option, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Option => $Param{Data}->{Option},
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
