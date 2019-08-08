# --
# Kernel/API/Operation/V1/ConsoleFile/ConsoleCommandExec.pm - API ConsoleFile Get operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ConsoleFile::ConsoleCommandGet');

    return $Self;
}

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
        my %CommandData = $Kernel::OM->Get('Kernel::System::Console')->CommandGet(
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
