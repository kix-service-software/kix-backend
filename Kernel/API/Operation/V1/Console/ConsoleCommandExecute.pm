# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Console::ConsoleCommandExecute;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Console::ConsoleCommandExecute - API ConsoleFile Command Execute Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            Command    => '...'
            Parameters => [
                '...',
                '...'
            ]
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'ConsoleExecute' => {
            Type     => 'HASH',
            Required => 1,
        },
        'ConsoleExecute::Command' => {
            Required => 1,
        },
        'ConsoleExecute::Parameters' => {
            Type => 'ARRAY',
            }
        }
}

=item Run()

perform ConsoleCommandExecute Operation.

    my $Result = $OperationObject->Run(
        Data => {
            ConsoleExecute => {
                Command    => '...',
                Parameters => [                      # optional

                ]
            }
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Output   => '...',                       # the STDOUT and STDERR output of the command
            ExitCode => 1                            # the exit code
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my $ExitCode;
    my $Execute = $Param{Data}->{ConsoleExecute};

    $Self->{OutputBuffer} = '';

    # copy STDOUT and STDERR to another filehandle
    open( my $OriginalSTDOUT, '>&', STDOUT );
    open( my $OriginalSTDERR, '>&', STDERR );
    close STDOUT;
    close STDERR;

    # redirect STDOUT and STDERR to variable
    open( STDOUT, '>:utf8', \$Self->{OutputBuffer} );
    open( STDERR, '>:utf8', \$Self->{OutputBuffer} );

    # make sure to have autoflush enabled
    select STDOUT;
    $| = 1;
    select STDERR;
    $| = 1;
    print STDERR $Execute->{Command} . "   :" . Data::Dumper::Dumper($Execute);

    # execute the command
    $ExitCode = $Kernel::OM->Get('Console')->Run(
        $Execute->{Command},
        IsArrayRefWithData( $Execute->{Parameters} ) ? @{ $Execute->{Parameters} } : (),
    );

    # restore STDOUT and STDERR
    open( STDOUT, '>&', $OriginalSTDOUT );
    open( STDERR, '>&', $OriginalSTDERR );

    print STDERR "OutputBuffer: $Self->{OutputBuffer}\n";

    # return result
    return $Self->_Success(
        ExitCode => $ExitCode,
        Output   => $Self->{OutputBuffer},
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
