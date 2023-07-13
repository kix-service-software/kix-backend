# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Migration::MigrationGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Migration::MigrationGet - API Migration Get Operation backend

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
        'MigrationID' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform MigrationGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MigrationID => '...'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success => 1,            # 0 or 1
        Code    => '',           # In case of an error
        Message => '',           # In case of an error
        Data         => {
            Migration => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @Result;

    my %MigrationList = map { $_->{ID} => $_ } $Kernel::OM->Get('Installation')->MigrationList();

    # start loop
    foreach my $MigrationID ( @{$Param{Data}->{MigrationID}} ) {
        next if !$MigrationID;

        if ( !IsHashRefWithData( $MigrationList{$MigrationID} ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@Result, $MigrationList{$MigrationID});
    }

    if ( scalar(@Result) == 1 ) {
        return $Self->_Success(
            Migration => $Result[0],
        );
    }

    # return result
    return $Self->_Success(
        Migration => \@Result,
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
