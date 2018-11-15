# --
# Kernel/API/Operation/V1/Valid/ValidGet.pm - API Valid Get operation backend
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

package Kernel::API::Operation::V1::Valid::ValidGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Valid::ValidGet - API Valid Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Valid::ValidGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Valid::ValidGet');

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
        'ValidID' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform ValidGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ValidID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Valid => [
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

    my @ValidList;

    # start loop
    foreach my $ValidID ( @{$Param{Data}->{ValidID}} ) {

        # get the Valid data
        my $ValidName = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            ValidID => $ValidID,
        );

        if ( !$ValidName ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for ValidID $ValidID.",
            );
        }
       
        my %Valid;
        
        $Valid{ID} = $ValidID;
        $Valid{Name} = $ValidName;

        
        # add
        push(@ValidList, \%Valid);
    }

    if ( scalar(@ValidList) == 1 ) {
        return $Self->_Success(
            Valid => $ValidList[0],
        );    
    }

    # return result
    return $Self->_Success(
        Valid => \@ValidList,
    );
}

1;
