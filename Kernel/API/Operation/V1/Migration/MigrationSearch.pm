# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Migration::MigrationSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Migration::MigrationSearch - API Migration Search Operation backend

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

    return $Self;
}

=item Run()

perform MigrationSearch Operation. This will return a Migration ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data         => {
            Migration => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @MigrationList = $Kernel::OM->Get('Installation')->MigrationList();
    
    if (IsArrayRefWithData(\@MigrationList)) {
        my $MigrationGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Migration::MigrationGet',
            SuppressPermissionErrors => 1,
            Data      => {
                MigrationID => join(',', map { $_->{ID} } @MigrationList),
            }
        );
 
        if ( !IsHashRefWithData($MigrationGetResult) || !$MigrationGetResult->{Success} ) {
            return $MigrationGetResult;
        }

        my @MigrationDataList = IsArrayRef($MigrationGetResult->{Data}->{Migration}) ? @{$MigrationGetResult->{Data}->{Migration}} : ( $MigrationGetResult->{Data}->{Migration} );

        if ( IsArrayRefWithData(\@MigrationDataList) ) {
            return $Self->_Success(
                Migration => \@MigrationDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Migration => [],
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
