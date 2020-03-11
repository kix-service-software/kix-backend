# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectAction;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config'
);

=head1 NAME

Kernel::System::ObjectAction

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LockObject = $Kernel::OM->Get('Kernel::System::Lock');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ObjectActionList()

=cut

sub ObjectActionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Object)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return $Self->_LoadObjectActions(%Param);
}

sub _LoadObjectActions {
    my ( $Self, %Param ) = @_;

    my $ConfigValue = $Kernel::OM->Get('Kernel::Config')->Get('ObjectActions::Definitions');

    return if !$ConfigValue;

    my $AllActions = $Kernel::OM->Get('Kernel::System::JSON')->Decode(        
        Data => $ConfigValue
    );

    return if !IsHashRefWithData($AllActions);

    my @Result = ();

    if ( IsArrayRefWithData ($AllActions->{$Param{Object}}) ) {
        @Result = @{ $AllActions->{$Param{Object}} };
    }

    return @Result;
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