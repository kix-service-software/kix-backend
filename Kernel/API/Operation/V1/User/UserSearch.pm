# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::UserSearch - API User Search Operation backend

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

    $Self->{RequiredPermission} = {
        TicketRead => {
            Target => '/tickets',
            Permission => 'READ'
        },
        TicketCreate => {
            Target => '/tickets',
            Permission => 'CREATE'
        },
        # FIXME: currently with placeholder, until specific object permission are implemented
        TicketUpdate => {
            Target => '/tickets/placeholder',
            Permission => 'UPDATE'
        }
    };

    return $Self;
}

=item Run()

perform UserSearch Operation. This will return a User ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            User => [
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

    # perform user search
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Short',
        Valid => 0,
    );

    if (IsHashRefWithData(\%UserList)) {

        # check requested permissions (AND combined)
        my @GetUserIDs = sort keys %UserList;
        if( $Param{Data} && $Param{Data}->{requiredPermission} ) {
            my @Permissions = split(/, ?/, $Param{Data}->{requiredPermission});

            for my $Permission (@Permissions) {
                next if (!$Self->{RequiredPermission} || !$Self->{RequiredPermission}->{$Permission});

                my @AllowedUserIDs;
                for my $UserID (@GetUserIDs) {

                    my ($Granted) = $Kernel::OM->Get('Kernel::System::User')->CheckResourcePermission(
                        UserID              => $UserID,
                        Target              => $Self->{RequiredPermission}->{$Permission}->{Target},
                        RequestedPermission => $Self->{RequiredPermission}->{$Permission}->{Permission}
                    );

                    if ($Granted) {
                        push(@AllowedUserIDs, $UserID);
                    }
                }

                # set allowed ids for next permission
                @GetUserIDs = @AllowedUserIDs;
            }
        }

        # get already prepared user data from UserGet operation
        my $UserGetResult = $Self->ExecOperation(
            OperationType => 'V1::User::UserGet',
            Data          => {
                UserID => join(',', @GetUserIDs),
            }
        );
        if ( !IsHashRefWithData($UserGetResult) || !$UserGetResult->{Success} ) {
            return $UserGetResult;
        }

        my @ResultList = IsArrayRef($UserGetResult->{Data}->{User}) ? @{$UserGetResult->{Data}->{User}} : ( $UserGetResult->{Data}->{User} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                User => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        User => [],
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
