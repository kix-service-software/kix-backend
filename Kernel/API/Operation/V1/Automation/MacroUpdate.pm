# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::MacroUpdate - API Macro Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::MacroUpdate');

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
        'MacroID' => {
            Required => 1
        },
        'Macro' => {
            Type => 'HASH',
            Required => 1
        },   
    }
}

=item Run()

perform MacroUpdate Operation. This will return the updated MacroID.

    my $Result = $OperationObject->Run(
        Data => {
            MacroID => 123,
            Macro  => {
                Type          => 'Ticket',                  # (optional)
                Name          => 'Item Name',               # (optional)
                ExecOrder     => [],                        # (optional)
                Comment       => 'Comment',                 # (optional)
                ValidID       => 1,                         # (optional)
            },
        },
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            MacroID  => 123,       # ID of the updated Macro 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Macro parameter
    my $Macro = $Self->_Trim(
        Data => $Param{Data}->{Macro}
    );

    # check if Macro exists 
    my %MacroData = $Kernel::OM->Get('Kernel::System::Automation')->MacroGet(
        ID => $Param{Data}->{MacroID},
    );

    if ( !%MacroData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if job with the same name already exists
    if ( $Macro->{Name} ) {
        my $MacroID = $Kernel::OM->Get('Kernel::System::Automation')->MacroLookup(
            Name => $Macro->{Name},
        );
        if ( $MacroID && $MacroID != $Param{Data}->{MacroID} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot update macro. Another macro with the same name '$Macro->{Name}' already exists.",
            );
        }
    }

    # update Macro
    my $Success = $Kernel::OM->Get('Kernel::System::Automation')->MacroUpdate(
        ID        => $Param{Data}->{MacroID},    
        Type      => $Macro->{Type} || $MacroData{Type},
        Name      => $Macro->{Name} || $MacroData{Name},
        ExecOrder => exists $Macro->{ExecOrder} ? $Macro->{ExecOrder} : $MacroData{ExecOrder},
        Comment   => exists $Macro->{Comment} ? $Macro->{Comment} : $MacroData{Comment},
        ValidID   => exists $Macro->{ValidID} ? $Macro->{ValidID} : $MacroData{ValidID},
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        MacroID => 0 + $Param{Data}->{MacroID},
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
