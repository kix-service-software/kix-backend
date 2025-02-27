# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig::Event::AssignedMappingChanged;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Cache',
);

=head1 NAME

Kernel::System::SysConfig::Event::AssignedMappingChanged

=head1 SYNOPSIS

Cache updater after assigned mapping changed

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a SysConfig::Event::AssignedMappingChanged object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AssignedMappingChangedObject = $Kernel::OM->Get('SysConfig::Event::AssignedMappingChanged');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{LogObject}   = $Kernel::OM->Get('Log');
    $Self->{CacheObject} = $Kernel::OM->Get('Cache');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Event Data)) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    for my $Needed (qw(Name)) {
        if ( !$Param{Data}->{$Needed} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed in Data!" );
            return;
        }
    }

    if ($Param{Data}->{Name} eq 'AssignedObjectsMapping') {
        for my $ObjectType (qw(Ticket FAQ Organisation Contact)) { # Article not needed, part of Ticket
            my $Object = $Kernel::OM->Get($ObjectType);
            if ($Object) {
                $Self->{CacheObject}->CleanUp(
                    Type => $Object->{CacheType}
                );
                if ($Object->{OSCacheType}) {
                    $Self->{CacheObject}->CleanUp(
                        Type => $Object->{OSCacheType}
                    );
                }

                # notify client to delete their relevant caches
                $Kernel::OM->Get('ClientNotification')->NotifyClients(
                    Event     => 'UPDATE',
                    Namespace => $ObjectType eq 'FAQ' ? 'FAQ.Article' : $ObjectType
                );
            }
        }
    } elsif ($Param{Data}->{Name} eq 'AssignedConfigItemsMapping') {
        my $Object = $Kernel::OM->Get('ConfigItem');
        if ($Object) {
            $Self->{CacheObject}->CleanUp(
                Type => $Object->{CacheType}
            );
            if ($Object->{OSCacheType}) {
                $Self->{CacheObject}->CleanUp(
                    Type => $Object->{OSCacheType}
                );
            }

            # notify client to delete their relevant caches
            $Kernel::OM->Get('ClientNotification')->NotifyClients(
                Event     => 'UPDATE',
                Namespace => 'CMDB.ConfigItem'
            );
        }
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
