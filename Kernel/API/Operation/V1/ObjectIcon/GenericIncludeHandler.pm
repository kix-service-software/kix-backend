# --
# Kernel/API/Operation/ObjectIcon/ObjectIconCreate.pm - API ObjectIcon Create operation backend
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

package Kernel::API::Operation::V1::ObjectIcon::GenericIncludeHandler;

use strict;
use warnings;

use Kernel::API::Operation::V1::ObjectIcon::ObjectIconSearch;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ObjectIcon::GenericIncludeHandler - API Handler

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

This will return a ObjectIcon ID.

    my $Result = $Object->Run(
        Object     => '...',        # required
        ObjectID   => '...'         # required
    );

    $Result = 123

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check required parameters
    foreach my $Key ( qw(Object ObjectID UserID) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # perform ObjectIcon search
    my $IconIDs = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconList(
        Object   => $Param{Object},
        ObjectID => $Param{ObjectID},
        UserID   => $Param{UserID},
    );

    if ( !IsArrayRefWithData($IconIDs) ) {
        return;
    }

    # return result
    return $IconIDs->[0];
}

1;