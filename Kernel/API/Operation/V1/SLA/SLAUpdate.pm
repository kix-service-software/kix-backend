# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SLA::SLAUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SLA::SLAUpdate - API SLA Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SLAUpdate');

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
        'SLAID' => {
            Required => 1
        },
        'SLA' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform SLAUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SLAID => 123,
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
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SLAID  => 123,                     # ID of the updated SLA 
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
    my %SLAData = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
        SLAID => $Param{Data}->{SLAID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%SLAData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update SLA
    my $Success = $Kernel::OM->Get('Kernel::System::SLA')->SLAUpdate(
        SLAID                   => $Param{Data}->{SLAID},    
        Name                    => $SLA->{Name} || $SLAData{Name},
        Comment                 => exists $SLA->{Comment} ? $SLA->{Comment} : $SLAData{Comment},
        ValidID                 => $SLA->{ValidID} || $SLAData{ValidID},
        TypeID                  => $SLA->{TypeID} || $SLAData{TypeID},        
        Calendar                => $SLA->{Calendar} || $SLAData{Calendar},
        FirstResponseTime       => $SLA->{FirstResponseTime} || $SLAData{FirstResponseTime},
        FirstResponseNotify     => $SLA->{FirstResponseNotify} || $SLAData{FirstResponseNotify},
        UpdateTime              => $SLA->{UpdateTime} || $SLAData{UpdateTime},
        UpdateNotify            => $SLA->{UpdateNotify} || $SLAData{UpdateNotify},
        SolutionTime            => $SLA->{SolutionTime} || $SLAData{SolutionTime},
        SolutionNotify          => $SLA->{SolutionNotify} || $SLAData{SolutionNotify},
        MinTimeBetweenIncidents => $SLA->{MinTimeBetweenIncidents} || $SLAData{MinTimeBetweenIncidents},
        UserID                  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        SLAID => $Param{Data}->{SLAID},
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
