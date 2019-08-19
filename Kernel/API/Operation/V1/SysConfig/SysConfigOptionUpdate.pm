# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigOptionUpdate - API SysConfigOption Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SysConfigOptionUpdate');

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
        'Option' => {
            Required => 1
        },
        'SysConfigOption' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform SysConfigOptionUpdate Operation. This will return the updated SysConfigOptionID.

    my $Result = $OperationObject->Run(
        Data => {
            Option => 'DefaultLanguage',
            SysConfigOption => {
                Value   => ...                # optional 
                ValidID => 1                  # optional  
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            Option  => 123,                     # ID of the updated SysConfigOption 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate SysConfigOption parameter
    my $SysConfigOption = $Param{Data}->{SysConfigOption};    

    # get option
    my %OptionData = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionGet(
        Name => $Param{Data}->{Option},
    );

    # update option
    my $Success = $Kernel::OM->Get('Kernel::System::SysConfig')->OptionUpdate(
        %OptionData,
        Value   => exists $SysConfigOption->{Value} ? $SysConfigOption->{Value} : $OptionData{Value},
        ValidID => $SysConfigOption->{ValidID} || $OptionData{ValidID},
        UserID  => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SysConfig option, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Option => $Param{Data}->{Option},
    );
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut