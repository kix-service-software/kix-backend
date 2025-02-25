# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ObjectTagLink;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ObjectTagLink - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init object tag join counter with 0
    $Param{Flags}->{ObjectTagLinkJoinCounter} = 0;

    # check fields
    return $Self->_CheckFields(
        %Param
    );
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['otl.id', 'otl.name','otl.object_id', 'otl.object_type'],
        From    => ['object_tags otl'],
        OrderBy => ['otl.name ASC', 'otl.object_type ASC', 'otl.object_id ASC' ]
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid Search! Search type has to provide an array.",
                );
            }
            return;
        }

        for my $SearchItem ( @{$Param{Search}->{$Type}} ) {
            if (
                ref( $SearchItem ) ne 'HASH'
                || !defined( $SearchItem->{Field} )
                || !defined( $SearchItem->{Value} )
            ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Invalid Search! Entry has to be a hash with Field and Value.",
                    );
                }
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
