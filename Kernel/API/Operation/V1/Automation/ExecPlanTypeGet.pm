# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::ExecPlanTypeGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::ExecPlanTypeGet - API ExecPlanType Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Automation::ExecPlanGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Automation::ExecPlanTypeGet');

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
        'ExecPlanType' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform ExecPlanGet Operation. This function is able to return
one or more entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ExecPlanType => 'TimeBased'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ExecPlanType => [
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

    my @ExecPlanTypeList;

    my $ExecPlanTypes = $Kernel::OM->Get('Kernel::Config')->Get('Automation::ExecPlanType');

    # start loop
    foreach my $ExecPlanType ( @{$Param{Data}->{ExecPlanType}} ) {

	    # get the ExecPlanType data
	    my %ExecPlanTypeData = $Kernel::OM->Get('Kernel::System::Automation')->ExecPlanTypeGet(
	        Name => $ExecPlanType,
	    );

        if ( !%ExecPlanTypeData ) {         
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add some more data
        $ExecPlanTypeData{Name}        = $ExecPlanType;
        $ExecPlanTypeData{DisplayName} = $ExecPlanTypes->{$ExecPlanType}->{DisplayName};

        # add
        push(@ExecPlanTypeList, \%ExecPlanTypeData);
    }

    if ( scalar(@ExecPlanTypeList) == 1 ) {
        return $Self->_Success(
            ExecPlanType => $ExecPlanTypeList[0],
        );    
    }

    # return result
    return $Self->_Success(
        ExecPlanType => \@ExecPlanTypeList,
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
