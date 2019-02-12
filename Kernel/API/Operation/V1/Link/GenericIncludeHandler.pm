# --
# Kernel/API/Operation/Link/LinkCreate.pm - API Link Create operation backend
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

package Kernel::API::Operation::V1::Link::GenericIncludeHandler;

use strict;
use warnings;

use Kernel::API::Operation::V1::Link::LinkSearch;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Link::GenericIncludeHandler - API Handler

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

This will return a Link ID list.

    my $Result = $Object->Run(
        Object     => '...',        # required
        ObjectID   => '...'         # required
    );

    $Result = [
        {},
        {}
    ]

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @Result;

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

    # check if the requested object is supported
    my %PossibleObjects = $Kernel::OM->Get('Kernel::System::LinkObject')->PossibleObjectsList(
        Object => $Param{Object}
    );
    return if !%PossibleObjects;

    # perform Link search
    my $LinkListSource = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkSearch(
        SourceObject => $Param{Object},
        SourceKey    => $Param{ObjectID},
        UserID       => $Param{UserID},
    );
    my $LinkListTarget = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkSearch(
        TargetObject => $Param{Object},
        TargetKey    => $Param{ObjectID},
        UserID       => $Param{UserID},
    );

    # merge results
    @Result = (
        @{$LinkListSource},
        @{$LinkListTarget},
    );

    # sort result
    @Result = sort @Result;

    # return result
    return \@Result;
}

1;