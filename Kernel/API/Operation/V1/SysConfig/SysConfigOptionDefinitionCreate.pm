# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfigSysConfigOptionDefinitionCreate - API SysConfigOptionDefinitionCreate Operation backend

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
        'SysConfigOptionDefinition' => {
            Type     => 'HASH',
            Required => 1
        },
        'SysConfigOptionDefinition::Name' => {
            Required => 1,
        },
        'SysConfigOptionDefinition::Description' => {
            Required => 1,
        },
        'SysConfigOptionDefinition::AccessLevel' => {
            Required => 1,
        },
        'SysConfigOptionDefinition::IsRequired' => {
            RequiresValueIfUsed => 1,
            OneOf               => [ 0, 1 ]
        },
        'SysConfigOptionDefinition::Type' => {
            Required => 1,
            OneOf    => \@SupportedTypes
        },
    }
}

=item Run()

perform SysConfigOptionDefinitionCreate Operation. This will return the created Option.

    my $Result = $OperationObject->Run(
        Data => {
            SysConfigOptionDefinition => (
                Name    => '...',
                ...
            },
        },
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      #
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            Option  => '',                       # Option
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
        Name => $SysConfigOptionDefinition->{Name},
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create SysConfigOptionDefinition. SysConfigOptionDefinition with the name '$SysConfigOptionDefinition->{Name}' already exists.",
        );
    }

    # create SysConfigOptionDefinition
    my $Success = $Kernel::OM->Get('SysConfig')->OptionAdd(
        Name            => $SysConfigOptionDefinition->{Name},
        Type            => $SysConfigOptionDefinition->{Type},
        Context         => $SysConfigOptionDefinition->{Context},
        ContextMetadata => $SysConfigOptionDefinition->{ContextMetadata},
        Description     => $SysConfigOptionDefinition->{Description},
        Comment         => $SysConfigOptionDefinition->{Comment},
        AccessLevel     => $SysConfigOptionDefinition->{AccessLevel},
        ExperienceLevel => $SysConfigOptionDefinition->{ExperienceLevel},
        Group           => $SysConfigOptionDefinition->{Group},
        IsRequired      => $SysConfigOptionDefinition->{IsRequired},
        Setting         => $SysConfigOptionDefinition->{Setting},
        Default         => $SysConfigOptionDefinition->{Default},
        DefaultValidID  => $SysConfigOptionDefinition->{DefaultValidID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create SysConfigOptionDefinition, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        Option => $SysConfigOptionDefinition->{Name},
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
