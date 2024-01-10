# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailFilter::MailFilterGet - API MailFilter Get Operation backend

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
        'MailFilterID' => {
            Type     => 'ARRAY',
            Required => 1
            }
    };
}

=item Run()

perform MailFilterGet Operation. This function is able to return
one or more mail filter in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MailFilterID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            MailFilter => [
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

    my @MailFilterList;

    # start loop
    foreach my $MailFilterID ( @{ $Param{Data}->{MailFilterID} } ) {

        # get the MailFilter data
        my %MailFilterData = $Kernel::OM->Get('PostMaster::Filter')->FilterGet( ID => $MailFilterID, );

        if ( !IsHashRefWithData( \%MailFilterData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
                Message => "The requested item ($MailFilterID) cannot be found."
            );
        }
        $Self->_PrepareFilter( Filter => \%MailFilterData );

        # add
        push( @MailFilterList, \%MailFilterData );
    }

    if ( scalar(@MailFilterList) == 1 ) {
        return $Self->_Success( MailFilter => $MailFilterList[0], );
    }

    # return result
    return $Self->_Success( MailFilter => \@MailFilterList, );
}

sub _PrepareFilter {
    my ( $Self, %Param ) = @_;

    my @MatchData;
    if ( IsHashRefWithData( $Param{Filter}->{Match} ) ) {
        for my $Key ( keys %{ $Param{Filter}->{Match} } ) {
            my $Not = $Param{Filter}->{Not} ? $Param{Filter}->{Not}->{$Key} : 0;
            push(
                @MatchData,
                {
                    Key   => $Key,
                    Value => $Param{Filter}->{Match}->{$Key},
                    Not   => $Not || 0
                }
            );
        }

    }
    $Param{Filter}->{Match} = \@MatchData;

    my @SetData;
    if ( IsHashRefWithData( $Param{Filter}->{Set} ) ) {
        for my $Key ( keys %{ $Param{Filter}->{Set} } ) {
            push(
                @SetData,
                {
                    Key   => $Key,
                    Value => $Param{Filter}->{Set}->{$Key}
                }
            );
        }

    }
    $Param{Filter}->{Set} = \@SetData;
    delete $Param{Filter}->{Not}
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
