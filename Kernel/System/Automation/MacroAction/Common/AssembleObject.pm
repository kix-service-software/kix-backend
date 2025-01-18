# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common::AssembleObject;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::AssembleObject - A module to assemble a new object from a text with variables and placeholders

=head1 SYNOPSIS

All AssembleObject functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Assembles a new object to be used later in the execution.'));
    $Self->AddOption(
        Name        => 'Type',
        Label       => Kernel::Language::Translatable('Type'),
        Description => Kernel::Language::Translatable('The type of the object. Either JSON or YAML.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Definition',
        Label       => Kernel::Language::Translatable('Definition'),
        Description => Kernel::Language::Translatable('The definition (structure/content) of the object, i.e. the YAML string or the JSON. You can use variables and placeholders. IMPORTANT: due to the possible use of placeholders and variables, the definition can only be validated when this action gets executed. In case of an error you will find detailed information in the job log and the kix log.'),
        Required    => 1,
        Placeholder => {
            Richtext  => 0,
            Translate => 0,
        },
    );

    $Self->AddResult(
        Name        => 'Object',
        Description => Kernel::Language::Translatable('The assembled object containing the two attributes "Type" and "Definition", which is a string representation of the object.'),
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        ObjectID => 123,
        Config   => {
            Type       => 'JSON',
            Definition => '{ "Title": "${Title}" }',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    # create new instance of helper module
    my $Module = $Kernel::OM->GetModuleFor('Automation::Helper::Object');
    if ( !$Kernel::OM->Get('Main')->Require($Module) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't require helper object!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my $Object = $Module->new();
    if ( !IsObject($Object, $Module) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't create helper object!",
            UserID   => $Param{UserID}
        );
        return;
    }

    $Object->SetType($Param{Config}->{Type});
    $Object->SetDefinition($Param{Config}->{Definition});

    # return the object
    $Self->SetResult(
        Name   => 'Object',
        Value  => $Object,
        UserID => $Param{UserID}
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
