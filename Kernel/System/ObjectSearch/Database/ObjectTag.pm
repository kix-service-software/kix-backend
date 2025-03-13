# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ObjectTag;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ObjectTag - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init object tag join counter with 0
    $Param{Flags}->{ObjectTagJoinCounter} = 0;

    # check fields
    return $Self->_CheckFields(
        %Param
    );
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['DISTINCT( ot.name )'],
        From    => ['object_tags ot'],
        OrderBy => ['ot.name ASC']
    };
}


=begin Internal:

=cut

sub _CheckFields {
    my ($Self, %Param) = @_;

    my $HasObjectType = 0;
    my $HasObjectID   = 0;
    for my $Type ( keys %{$Param{Search}} ) {
        if ( ref( $Param{Search}->{ $Type } ) ne 'ARRAY' ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Search! Search type has to provide an array.",
                Silent   => $Param{Silent}
            );
            return;
        }

        for my $SearchItem ( @{$Param{Search}->{$Type}} ) {
            if (
                ref( $SearchItem ) ne 'HASH'
                || !defined( $SearchItem->{Field} )
                || !defined( $SearchItem->{Value} )
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid Search! Entry has to be a hash with Field and Value.",
                    Silent   => $Param{Silent}
                );
                return;
            }
            if ( $SearchItem->{Field} eq 'ObjectType' ) {
                $HasObjectType = 1;
            }
            elsif ( $SearchItem->{Field} eq 'ObjectID' ) {
                $HasObjectID = 1;
            }
        }
    }

    if ( $HasObjectID && !$HasObjectType ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid search! Search of ObjectID requires an object type assignment.",
            Silent   => $Param{Silent}
        );
        return;
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
