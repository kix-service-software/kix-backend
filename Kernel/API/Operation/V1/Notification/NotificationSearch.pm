# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Notification::NotificationSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Notification::NotificationGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Notification::NotificationSearch - API Notification Search Operation backend

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

perform NotificationSearch Operation. This will return a Notification list.

    my $Result = $OperationObject->Run(
        Data => { }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Notification => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Notification search
    my %NotificationList = $Kernel::OM->Get('Kernel::System::NotificationEvent')->NotificationList(
        Details => 1,
        All     => 1
    );

    # get already prepared Notification data from NotificationGet operation
    if ( IsHashRefWithData( \%NotificationList ) ) {
        my $NotificationGetResult = $Self->ExecOperation(
            OperationType => 'V1::Notification::NotificationGet',
            Data          => {
                NotificationID => join( ',', sort keys %NotificationList )
            }
        );

        if (
            !IsHashRefWithData($NotificationGetResult)
            || !$NotificationGetResult->{Success}
            ) {
            return $NotificationGetResult;
        }

        my @NotificationDataList = IsArrayRefWithData( $NotificationGetResult->{Data}->{Notification} )
            ? @{ $NotificationGetResult->{Data}->{Notification} }
            : ( $NotificationGetResult->{Data}->{Notification} );

        if ( IsArrayRefWithData( \@NotificationDataList ) ) {
            return $Self->_Success( Notification => \@NotificationDataList, );
        }
    }

    # return result
    return $Self->_Success( Notification => [], );
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
