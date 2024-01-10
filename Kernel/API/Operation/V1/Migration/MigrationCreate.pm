# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Migration::MigrationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Migration::MigrationCreate - API Migration MigrationCreate Operation backend

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

    my @Sources;

    if ( IsHashRefWithData($Kernel::OM->Get('Config')->Get('Migration::Sources')) ) {
        @Sources = sort keys %{ $Kernel::OM->Get('Config')->Get('Migration::Sources') };
    }

    return {
        'Migration' => {
            Type     => 'HASH',
            Required => 1
        },
        'Migration::Source' => {
            Required => 1,
            OneOf    => \@Sources,
        },
        'Migration::SourceID' => {
            Required => 1
        },
    }
}

=item Run()

perform MigrationCreate Operation. This will return the created MigrationID.

    my $Result = $OperationObject->Run(
        Data => {
            Migration => (
                Source   => '...',
                SourceID => '...',
                Options  => {}
            },
        },
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      #
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            MigrationID  => '',                  # MigrationID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Migration parameter
    my $Migration = $Self->_Trim(
        Data => $Param{Data}->{Migration}
    );

    # check if a migration process is already running
    my @MigrationList = $Kernel::OM->Get('Installation')->MigrationList();
    my $Running;
    foreach my $MigrationData ( @MigrationList ) {

        if ( IsHashRefWithData( $MigrationData ) && $MigrationData->{Status} !~ /finished|aborted/ ) {
            $Running = 1;
            last;
        }
    }

    if ( $Running ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot start a new migration. A migration is already in progress.",
        );
    }

    # start new migration in background
    my $MigrationID = $Kernel::OM->Get('Installation')->MigrationStart(
        %{$Migration},
        Async => 1,
    );

    if ( !$MigrationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not start migration, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        MigrationID => $MigrationID,
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
