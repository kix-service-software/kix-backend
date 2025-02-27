# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::TextModule::TextModuleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TextModule::TextModuleCreate - API TextModule Create Operation backend

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

    # get system LanguageIDs
    my $Languages = $Kernel::OM->Get('Config')->Get('DefaultUsedLanguages');
    my @LanguageIDs = sort keys %{$Languages};

    return {
        'TextModule' => {
            Type     => 'HASH',
            Required => 1
        },
        'TextModule::Name' => {
            Required => 1
        },
        'TextModule::Text' => {
            Required => 1
        },
        'TextModule::Language' => {
            RequiresValueIfUsed => 1,
            OneOf => \@LanguageIDs
        },
        'TextModule::QueueIDs' => {
            Required => 0
        },
        'TextModule::TicketTypeIDs' => {
            Required => 0
        },
    }
}

=item Run()

perform TextModuleCreate Operation. This will return the created TextModuleID.

    my $Result = $OperationObject->Run(
        Data => {
            TextModule  => {
                Name                => '...',
                Text                => '...',
                Language            => '...',       # optional, if not given set to DefaultLanguage with fallback 'en'
                Category            => '...',       # optional
                Comment             => '...',       # optional
                Keywords            => [
                    'some', 'keyword'
                ],                                  # optional
                Subject             => '...',       # optional
                ValidID             => 1,           # optional
                QueueIDs            => [...],       # optional
                TicketTypeIDs       => [...]        # optional
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TextModuleID  => '',                    # ID of the created TextModule
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim TextModule parameter
    my $TextModule = $Self->_Trim(
        Data => $Param{Data}->{TextModule}
    );

    # check if TextModule exists
    my $ExistingTextModuleIDs = $Kernel::OM->Get('TextModule')->TextModuleList(
        Name => $TextModule->{Name},
    );

    if ( IsArrayRefWithData($ExistingTextModuleIDs) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create TextModule. A TextModule with the same name already exists.",
        );
    }

    # create TextModule
    my $TextModuleID = $Kernel::OM->Get('TextModule')->TextModuleAdd(
        Name               => $TextModule->{Name},
        Text               => $TextModule->{Text} || '',
        Category           => $TextModule->{Category} || '',
        Language           => $TextModule->{Language} || '',
        Subject            => $TextModule->{Subject} || '',
        Keywords           => IsArrayRefWithData($TextModule->{Keywords}) ? join(' ', @{$TextModule->{Keywords}}) : '',
        Comment            => $TextModule->{Comment} || '',
        QueueIDs           => $TextModule->{QueueIDs},
        TicketTypeIDs      => $TextModule->{TicketTypeIDs},
        ValidID            => $TextModule->{ValidID} || 1,
        UserID             => $Self->{Authorization}->{UserID},
    );

    if ( !$TextModuleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create TextModule, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        TextModuleID => $TextModuleID,
    );
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
