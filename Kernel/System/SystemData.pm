# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SystemData;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    Log
);

=head1 NAME

Kernel::System::SystemData - key/value store for system data

=head1 SYNOPSIS

Provides key/value store for system data

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SystemDataObject = $Kernel::OM->Get('SystemData');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('DB');

    # create additional objects
    $Self->{CacheType} = 'SystemData';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item SystemDataSet()

set a systemdata value, replace an exising one. Value can be a scalar, a hashref or an arrayref

    my $Result = $SystemDataObject->SystemDataSet(
        Key    => 'SomeKey',
        Value  => 'Some Value',
        UserID => 123,
    );

=cut

sub SystemDataSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Key)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    if ( !defined $Param{Value} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Value!"
        );
        return;
    }

    # return if key does not already exists - then we can't do an update
    my $Result = $Self->SystemDataDelete( Key => $Param{Key} );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't delete existing key \"$Param{Key}\"!",
        );
        return;
    }

    my $UserID = $Param{UserID} // 1;

    # prepare the value
    my $Value = $Kernel::OM->Get('JSON')->Encode(
        Data => {
            Value => $Param{Value}
        }
    );

    # store data
    return if !$Self->{DBObject}->Do(
        SQL => '
            INSERT INTO system_data
                (data_key, data_value, create_time, create_by, change_time, change_by)
            VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)
            ',
        Bind => [ \$Param{Key}, \$Value, \$UserID, \$UserID ],
    );

    # delete cache
    $Self->_SystemDataCacheKeyDelete(
        Key => $Param{Key},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'SystemData',
        ObjectID  => $Param{Key},
    );

    return 1;
}

=item SystemDataGet()

get system data for key

    my $SystemData = $SystemDataObject->SystemDataGet(
        Key => 'KIX Version',
    );

returns value as a simple scalar, or undef if the key does not exist.
keys set to NULL return an empty string.

=cut

sub SystemDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Key} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Key!"
        );
        return;
    }

    # check cache
    my $CacheKey = 'SystemDataGet::' . $Param{Key};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    return if !$Self->{DBObject}->Prepare(
        SQL => '
            SELECT data_value
            FROM system_data
            WHERE data_key = ?
            ',
        Bind  => [ \$Param{Key} ],
        Limit => 1,
    );

    my $Value;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Value = $Data[0] // '';
    }

    if ( $Value ) {
        $Value = $Kernel::OM->Get('JSON')->Decode(
            Data => $Value
        );
        $Value = $Value->{Value};
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Value // '',
    );

    return $Value;
}

=item SystemDataDelete()

update system data

Returns true if delete was succesful or false if otherwise - for instance
if key did not exist.

    $SystemDataObject->SystemDataDelete(
        Key    => 'KIX Version',
    );

=cut

sub SystemDataDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Key)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # sql
    return if !$Self->{DBObject}->Do(
        SQL => '
            DELETE FROM system_data
            WHERE data_key = ?
            ',
        Bind => [ \$Param{Key} ],
    );

    # delete cache entry
    $Self->_SystemDataCacheKeyDelete(
        Key => $Param{Key},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'SystemData',
        ObjectID  => $Param{Key},
    );

    return 1;
}

=begin Internal:

=cut

=item _SystemDataCacheKeyDelete()

This will delete the cache for the given key and for all groups, if needed.

For a key such as 'Foo::Bar::Baz', it will delete the cache for 'Foo::Bar::Baz'
as well as for the groups 'Foo::Bar' and 'Foo'.

    $Success = $SystemDataObject->_SystemDataCacheKeyDelete(
        Key => 'SystemRegistration::Version::DB'
    );

=cut

sub _SystemDataCacheKeyDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Key} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "_SystemDataCacheKeyDelete: need 'Key'!"
        );
        return;
    }

    # delete cache entry
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => 'SystemDataGet::' . $Param{Key},
    );

    # delete cache for groups if needed
    my @Parts = split( '::', $Param{Key} );

    if ( scalar @Parts > 1 ) {

        # remove last value, delete cache
        PART:
        for my $Part (@Parts) {
            pop @Parts;
            my $CacheKey = join( '::', @Parts );
            $Kernel::OM->Get('Cache')->Delete(
                Type => $Self->{CacheType},
                Key  => 'SystemDataGetGroup::' . join( '::', @Parts ),
            );

            # stop if there is just one value left
            last PART if scalar @Parts == 1;
        }
    }

    return 1;
}

=end Internal:


1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
