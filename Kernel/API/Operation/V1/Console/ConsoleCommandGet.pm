# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Console::ConsoleCommandGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Console::ConsoleCommandGet - API ConsoleFile Command Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            Command    => '...'
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'Command' => {
            Type     => 'ARRAY',
            Required => 1,
        },
        }
}

=item Run()

perform ConsoleCommandGet Operation. Returns its description and parameters

    my $Result = $OperationObject->Run(
        Data => {
            Command => '...'
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Description => '...'
            Parameters  => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @CommandList;

    # start loop
    foreach my $Command ( @{ $Param{Data}->{Command} } ) {

        # execute the command
        my %CommandData = $Kernel::OM->Get('Console')->CommandGet(
            Command => $Command,
        );

        push @CommandList, \%CommandData;
    }

    if ( scalar(@CommandList) == 1 ) {
        return $Self->_Success(
            ConsoleCommand => $CommandList[0],
        );
    }

    return $Self->_Success(
        ConsoleCommand => \@CommandList,
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
