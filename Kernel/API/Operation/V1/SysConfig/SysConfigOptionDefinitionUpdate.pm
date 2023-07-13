# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionUpdate - API SysConfigOptionDefinitionUpdate Operation backend

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

    my @SupportedTypes = $Kernel::OM->Get('SysConfig')->OptionTypeList();

    return {
        'Option' => {
            Required => 1
        },
        'SysConfigOptionDefinition' => {
            Type => 'HASH',
            Required => 1
        },
        'SysConfigOptionDefinition::Description' => {
            RequiresValueIfUsed => 1,
        },
        'SysConfigOptionDefinition::AccessLevel' => {
            RequiresValueIfUsed => 1,
        },
        'SysConfigOptionDefinition::IsRequired' => {
            RequiresValueIfUsed => 1,
            OneOf               => [ 0, 1 ]
        },
        'SysConfigOptionDefinition::Type' => {
            RequiresValueIfUsed => 1,
            OneOf               => \@SupportedTypes
        },
    }
}

=item Run()

perform SysConfigOptionDefinitionUpdate Operation. This will return the updated Option.

    my $Result = $OperationObject->Run(
        Data => {
            Option => 'test',
        SysConfigOptionDefinition   => {
                ...
            },
        }
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            Option  => '',                      # Option
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim SysConfigOptionDefinition parameter
    my $SysConfigOptionDefinition = $Self->_Trim(
        Data => $Param{Data}->{SysConfigOptionDefinition}
    );

    # check if SysConfigOptionDefinition exists
    my $Exists = $Kernel::OM->Get('SysConfig')->Exists(
        Name => $Param{Data}->{Option},
    );

    if ( !$Exists ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
        );
    }

    # get SysConfigOptionDefinition
    my %OptionData = $Kernel::OM->Get('SysConfig')->OptionGet(
        Name => $Param{Data}->{Option},
    );

    # update SysConfigOptionDefinition
    my $Success = $Kernel::OM->Get('SysConfig')->OptionUpdate(
        %OptionData,
        %{$SysConfigOptionDefinition},
        Name   => $Param{Data}->{Option},
        UserID => $Self->{Authorization}->{UserID},

        # keep current value and valid id
        Value => $OptionData{IsModified} ? $OptionData{Value} : undef
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
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
