# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TextModule::TextModuleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TextModule::TextModuleUpdate - API TextModule Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TextModuleUpdate');

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

    # get system LanguageIDs
    my $Languages = $Kernel::OM->Get('Kernel::Config')->Get('DefaultUsedLanguages');
    my @LanguageIDs = sort keys %{$Languages};

    return {
        'TextModuleID' => {
            Required => 1
        },
        'TextModule' => {
            Type     => 'HASH',
            Required => 1
        },
        'TextModule::Language' => {
            RequiresValueIfUsed => 1,
            OneOf => \@LanguageIDs
        },
    }
}

=item Run()

perform TextModuleUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            TextModuleID => 123,
            TextModule  => {
                Name                => '...',       # optional
                Text                => '...',       # optional
                Language            => '...',       # optional
                Category            => '...',       # optional
                Comment             => '...',       # optional
                Keywords            => [
                    'some', 'keywords'
                ],                                  # optional
                Subject             => '...',       # optional
                ValidID             => 1            # optional
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            TextModuleID  => 123,              # ID of the updated TextModule 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim TextModule parameter
    my $TextModule = $Self->_Trim(
        Data => $Param{Data}->{TextModule}
    );
    
    # check if TextModule exists 
    my %TextModuleData = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleGet(
        ID     => $Param{Data}->{TextModuleID},
        UserID => $Self->{Authorization}->{UserID},
    );
 
    if ( !%TextModuleData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ( $TextModule->{Name} ) {
        # check if TextModule exists
        my $ExistingProfileIDs = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleList(
            Name        => $TextModule->{Name},
        );
        
        if ( IsArrayRefWithData($ExistingProfileIDs) && $ExistingProfileIDs->[0] != $TextModuleData{ID}) {
            return $Self->_Error(
                Code => 'Object.AlreadyExists',
            );
        }
    }

    # update TextModule
    my $Success = $Kernel::OM->Get('Kernel::System::TextModule')->TextModuleUpdate(
        ID                 => $Param{Data}->{TextModuleID},
        Name               => $TextModule->{Name} || $TextModuleData{Name},
        Text               => $TextModule->{Text} || $TextModuleData{Text},
        Category           => exists $TextModule->{Category} ? $TextModule->{Category} : $TextModuleData{Category},
        Language           => $TextModule->{Language} || $TextModuleData{Language},
        Subject            => exists $TextModule->{Subject} ? $TextModule->{Subject} : $TextModuleData{Subject},
        Keywords           => IsArrayRefWithData($TextModule->{Keywords}) ? join(' ', @{$TextModule->{Keywords}}) : $TextModuleData{Keywords},
        Comment            => exists $TextModule->{Comment} ? $TextModule->{Comment} : $TextModuleData{Comment},
        ValidID            => $TextModule->{ValidID} || $TextModuleData{ValidID},        
        UserID             => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        TextModuleID => $Param{Data}->{TextModuleID},
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
