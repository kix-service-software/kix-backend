# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Event::UpdateCounters;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::AsynchronousExecutor
);

our @ObjectDependencies = (
    'ITSMConfigItem',
    'Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::Event::UpdateCounters - Event handler to update class counters

=head1 SYNOPSIS

All event handler functions for class counters.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UpdateCountersObject = $Kernel::OM->Get('ITSMConfigItem::Event::UpdateCounters');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

This method handles the event.

    $DoHistoryObject->Run(
        Event => 'ConfigItemCreate',
        Data  => {
            Comment      => 'new value: 1',
            ConfigItemID => 123,
        },
        UserID => 1,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Class = $Param{Data}->{Class};
    if ( !$Class && $Param{Data}->{ConfigItemID} ) {
        # get the class from the configitem
        my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
            ConfigItemID => $Param{Data}->{ConfigItemID},
            Silent       => 1,
        );
        if ( IsHashRefWithData($ConfigItem) ) {
            $Class = $ConfigItem->{Class};
        }
    }

    $Self->_UpdateCounters(
        Class => $Class
    );

    return 1;
}

sub _UpdateCounters {
    my ( $Self, %Param ) = @_;

    if ( !$ENV{UnitTest} ) {
        $Self->AsyncCall(
            ObjectName               => $Kernel::OM->GetModuleFor('ITSMConfigItem'),
            FunctionName             => 'UpdateCounters',
            FunctionParams           => {
                UserID  => 1,
                Classes => $Param{Class} ? [ $Param{Class} ] : undef,
                Silent  => 1,
            },
            MaximumParallelInstances => 1,
        );
    }
    else {
        # we need to do that synchronously in case we are executed in a unittest
        $Kernel::OM->Get('ITSMConfigItem')->UpdateCounters(
            UserID  => 1,
            Classes => $Param{Class} ? [ $Param{Class} ] : undef,
            Silent  => 1,
        );
    }

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



