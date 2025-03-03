# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailAccount::MailAccountGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailAccount::MailAccountGet - API MailAccount Get Operation backend

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
        'MailAccountID' => {
            Type     => 'ARRAY',
            Required => 1
        }
    };
}

=item Run()

perform MailAccountGet Operation. This function is able to return
one or more mail accounts in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MailAccountID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            MailAccount => [
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

    my @MailAccountList;

    # start loop
    foreach my $MailAccountID ( @{ $Param{Data}->{MailAccountID} } ) {

        # get the MailAccount data
        my %MailAccountData = $Kernel::OM->Get('MailAccount')->MailAccountGet(
            ID => $MailAccountID,
        );

        if ( !IsHashRefWithData( \%MailAccountData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # remove password
        delete $MailAccountData{Password};

        # add
        push( @MailAccountList, \%MailAccountData );
    }

    if ( scalar(@MailAccountList) == 1 ) {
        return $Self->_Success(
            MailAccount => $MailAccountList[0],
        );
    }

    # return result
    return $Self->_Success(
        MailAccount => \@MailAccountList,
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
