# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfigChangeLog;

use strict;
use warnings;

use Carp ();

our @ObjectDependencies = (
    'Config',
    'Encode',
);

=head1 NAME

Kernel::System::SysConfigChangeLog - global log interface

=head1 SYNOPSIS

All log functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a log object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'SysConfigChangeLog' => {
            LogPrefix => 'InstallScriptX',  # not required, but highly recommend
        },
    );
    my $SysConfigChangeLogObject = $Kernel::OM->Get('SysConfigChangeLog');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    if ( !$Kernel::OM ) {
        Carp::confess('$Kernel::OM is not defined, please initialize your object manager')
    }

    my $ConfigObject = $Kernel::OM->Get('Config');
    $Self->{ProductVersion} = $ConfigObject->Get('Product') . ' ';
    $Self->{ProductVersion} .= $ConfigObject->Get('Version');

    # get system id
    my $SystemID = $ConfigObject->Get('SystemID');

    # check log prefix
    $Self->{LogPrefix} = $Param{LogPrefix} || '?LogPrefix?';
    $Self->{LogPrefix} .= '-' . $SystemID;

    # load log backend
    # KIX4OTRS-capeIT
    my $GenericModule = $ConfigObject->Get('SysConfigChangeLog::LogModule')
        || 'Kernel::System::SysConfigChangeLog::SysLog';

    # EO KIX4OTRS-capeIT
    if ( !eval "require $GenericModule" ) {    ## no critic
        die "Can't load log backend module $GenericModule! $@";
    }

    # create backend handle
    $Self->{Backend} = $GenericModule->new(
        %Param,
    );

    return $Self if !eval "require IPC::SysV";    ## no critic

    # create the IPC options
    $Self->{IPC}     = 1;
    $Self->{IPCKey}  = '444423' . $SystemID;

    # KIX4OTRS-capeIT
    # $Self->{IPCSize} = $ConfigObject->Get('LogSystemCacheSize') || 32 * 1024;
    $Self->{IPCSize} = $ConfigObject->Get('SysConfigChangeLog::LogSystemCacheSize')
        || 32 * 1024;

    # EO KIX4OTRS-capeIT

    # init session data mem
    if ( !eval { $Self->{Key} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) ) } ) {
        $Self->{Key} = shmget( $Self->{IPCKey}, 1, oct(1777) );
        $Self->CleanUp();
        $Self->{Key} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) );
    }

    return $Self;
}

1;

=item Log()

log something. log priorities are 'debug', 'info', 'notice' and 'error'.

These are mapped to the SysLog priorities. Please use the appropriate priority level:

=over

=item debug

Debug-level messages; info useful for debugging the application, not useful during operations.

=item info

Informational messages; normal operational messages - may be used for reporting etc, no action required.

=item notice

Normal but significant condition; events that are unusual but not error conditions, no immediate action required.

=item error

Error conditions. Non-urgent failures, should be relayed to developers or admins, each item must be resolved.

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
