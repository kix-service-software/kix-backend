# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SLA::SLACreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SLA::SLACreate - API SLA SLACreate Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'SLA' => {
            Type     => 'HASH',
            Required => 1
        },
        'SLA::Name' => {
            Required => 1
        },
        'SLA::TypeID' => {
            Required => 1
        },            
    }
}

=item Run()

perform SLACreate Operation. This will return the created SLAID.

    my $Result = $OperationObject->Run(
        Data => {
            SLA  => {
                Name                    => '...',
                Calendar                => '...',        # (optional)
                FirstResponseTime       => 120,          # (optional)
                FirstResponseNotify     => 60,           # (optional) notify agent if first response escalation is 60% reached
                UpdateTime              => 180,          # (optional)
                UpdateNotify            => 80,           # (optional) notify agent if update escalation is 80% reached
                SolutionTime            => 580,          # (optional)
                SolutionNotify          => 80,           # (optional) notify agent if solution escalation is 80% reached
                ValidID                 => 1,
                Comment                 => '...',        # (optional)
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443,     # (optional)
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            SLAID  => '',                         # ID of the created SLA
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim SLA parameter
    my $SLA = $Self->_Trim(
        Data => $Param{Data}->{SLA},
    );

    # check if SLA exists
    my $Exists = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
        Name => $SLA->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create SLA. SLA with the name '$SLA->{Name}' already exists.",
        );
    }

    # create sla
    my $SLAID = $Kernel::OM->Get('Kernel::System::SLA')->SLAAdd(
        Name                    => $SLA->{Name},
        Comment                 => $SLA->{Comment} || '',
        ValidID                 => $SLA->{ValidID} || 1,
        TypeID                  => $SLA->{TypeID},        
        Calendar                => $SLA->{Calendar} || '',
        FirstResponseTime       => $SLA->{FirstResponseTime} || '',
        FirstResponseNotify     => $SLA->{FirstResponseNotify} || '',
        UpdateTime              => $SLA->{UpdateTime} || '',
        UpdateNotify            => $SLA->{UpdateNotify} || '',
        SolutionTime            => $SLA->{SolutionTime} || '',
        SolutionNotify          => $SLA->{SolutionNotify} || '',
        MinTimeBetweenIncidents => $SLA->{MinTimeBetweenIncidents} || '',
        UserID                  => $Self->{Authorization}->{UserID},               
    );

    if ( !$SLAID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create SLA, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        SLAID => $SLAID,
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
