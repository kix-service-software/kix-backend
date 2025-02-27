# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::Job::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Job::Common - job type base class for automation lib

=head1 SYNOPSIS

Provides the base class methods for job type modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $Object = $Kernel::OM->Get('Automation::Job::Common');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

Run this job module.

Example:
    my $Result = $Object->Run(
        Filter    => {}         # optional, filter for objects
        Data      => {},        # optional, contains the relevant data given by an event or otherwise
        SortOrder => {},        # optional, sorting for objects - if supported by specific type
        UserID    => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if (IsHashRefWithData($Param{Filter})) {
        $Param{Filter} = [$Param{Filter}];
    }

    # prepare sort if given
    my $Sort;
    if (IsHashRefWithData($Param{SortOrder}) && $Param{SortOrder}->{Field}) {
        $Param{SortOrder}->{Direction} ||= 'ascending';
        $Sort = [
            {
                Field     => $Param{SortOrder}->{Field},
                Direction => $Param{SortOrder}->{Direction}
            }
        ];
    }

    my @IDs = $Self->_Run(%Param, Sort => $Sort);

    return @IDs;
}

sub _Run {
    my ( $Self, %Param ) = @_;

    return;
}

sub _ExtendFilter {
    my ( $Self, %Param ) = @_;

    return $Param{Filters} if ( !IsHashRefWithData($Param{Extend}) );

    my $Filters = $Param{Filters};

    if (!IsArrayRef($Filters)) {
        $Filters = [];
    }
    if ( !scalar(@{$Filters}) || (scalar(@{$Filters}) == 1 && !IsHashRef($Filters->[0])) ) {
        $Filters->[0] = {};
    }

    for my $Filter ( @{$Filters} ) {
        if (IsHashRef($Filter)) {
            $Filter->{AND} //= [];
            push( @{$Filter->{AND}}, $Param{Extend} );
        }
    }
    return $Filters;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
