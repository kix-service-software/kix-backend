# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Cache::Redis;

use strict;
use warnings;

use Redis;
use Storable qw();
use MIME::Base64;
use Digest::MD5 qw();
use Time::HiRes;
use utf8;

umask 002;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'Main',
);

use vars qw(@ISA);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Kernel::OM->ObjectParamAdd(
        'Config' => {
            NoCache => 1
        },
    );

    # get the config
    $Self->{Config} = $Kernel::OM->Get('Config')->Get('Cache::Module::Redis');

    $Kernel::OM->ObjectsDiscard( Objects => ['Config'] );

    return $Self;
}

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);
    return if !$PreparedKey;

    my $TTL = $Param{TTL} // 0;
    if ( IsHashRefWithData($Self->{Config}->{OverrideTTL}) ) {
        foreach my $TypePattern (keys %{$Self->{Config}->{OverrideTTL}}) {
            if ($Param{Type} =~ /^$TypePattern$/g) {
                $TTL = $Self->{Config}->{OverrideTTL}->{$TypePattern};
                last;
            }
        }
    }

    # prepare value for Redis
    my $Value = $Param{Value};
    if ( ref $Value ) {
        $Value = '__b64+nf::'.MIME::Base64::encode_base64( Storable::nfreeze( $Param{Value} ) );
    }
    elsif ( !utf8::downgrade($Value, 1) ) {
        utf8::encode($Value);
        $Value = '__b64raw::'.MIME::Base64::encode_base64( $Value );
    }

    if ( $TTL > 0 ) {
        $Self->_RedisCall('hset', $Param{Type}, $PreparedKey, $Value);
        $Self->_RedisCall('expire', $Param{Type}, $TTL);
    }
    else {
        $Self->_RedisCall('hset', $Param{Type}, $PreparedKey, $Value);
    }

    return 1;
}

sub Get {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);
    return if !$PreparedKey;

    my $Value = $Self->_RedisCall('hget', $Param{Type}, $PreparedKey);

    return $Value if !$Value || index($Value, '__b64') != 0;

    # restore Value
    my $Result;
    if ( index($Value, '__b64+nf') == 0 ) {
        $Value = substr($Value, 10);
        $Result = eval { Storable::thaw( MIME::Base64::decode_base64($Value) ) };
    }
    else {
        $Value = substr($Value, 10);
        $Result = MIME::Base64::decode_base64($Value);
        utf8::decode($Result);
    }

    return $Result;
}

sub GetMulti {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Keys)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @PreparedKeys = map { $Param{UseRawKey} ? $_ : $Self->_PrepareRedisKey($_) } @{$Param{Keys}};

    my @Values = @{$Self->_RedisCall('hmget', $Param{Type}, @PreparedKeys) || []};

    return @Values if !@Values;

    foreach my $Value ( @Values ) {
        next if !$Value;
        next if index($Value, '__b64') != 0;

        # restore Value
        if ( index($Value, '__b64+nf') == 0 ) {
            $Value = substr($Value, 10);
            $Value = eval { Storable::thaw( MIME::Base64::decode_base64($Value) ) };
        }
        else {
            $Value = substr($Value, 10);
            $Value = MIME::Base64::decode_base64($Value);
            utf8::decode($Value);
        }
    }

    return @Values;
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);
    return if !$PreparedKey;

    return $Self->_RedisCall('hdel', $Param{Type}, $PreparedKey);
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    if ( $Param{Type} ) {
        # delete type
        return $Self->_RedisCall('del', $Param{Type});
    }
    else {
        if ( $Param{KeepTypes} ) {
            my %KeepTypeLookup = map { $_ => 1 } @{ $Param{KeepTypes} || [] };

            # get all types
            my @Types = $Self->GetKeysForType(Type => '*');

            for my $Type ( @Types ) {
                next if $KeepTypeLookup{$Type};
                $Self->CleanUp( Type => $Type );
            }
        }
        else {
            return $Self->_RedisCall('flushall');
        }
    }
}

sub GetKeysForType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @Result;
    my $Keys;
    my $Cursor = 0;
    do {
        if ( $Param{Type} ne '*' ) {
            ($Cursor, $Keys) = @{$Self->_RedisCall('hscan', $Param{Type}, $Cursor) || []};
            # remove the values in this case
            my $Index=0;
            $Keys = [ grep { $Index++ % 2 == 0 } @{$Keys} ];
        }
        else {
            ($Cursor, $Keys) = @{$Self->_RedisCall('scan', $Cursor) || []};
        }
        push @Result, @{$Keys};
    } while ( $Cursor );

    return @Result;
}

=item _InitRedis()

initialize connection to Redis

    my $Value = $RedisObject->_InitRedis();

=cut

sub _InitRedis {
    my ( $Self, %Param ) = @_;

    my %InitParams = (
        server => $Self->{Config}->{Server},
        %{ $Self->{Config}->{Parameters} || {} },
    );

    $Self->{RedisObject} = Redis->new(%InitParams)
        || die "Unable to initialize Redis connection!";

    return 1;
}

=item _PrepareRedisKey()

Use MD5 digest of Key (to prevent special and possibly unsupported characters in key);
we use here algo similar to original one from FileStorable.pm.
(thanks to Informatyka Boguslawski sp. z o.o. sp.k., http://www.ib.pl/ for testing and contributing the MD5 change)

    my $PreparedKey = $Self->_PrepareRedisKey(
        'SomeKey',
    );

=cut

sub _PrepareRedisKey {
    my ( $Self, %Param ) = @_;

    if ($Param{Raw}) {
        return $Param{Key};
    }

    my $Key;
    eval {
        $Key = Digest::MD5::md5_hex($Param{Key});
    };
    if ( $@ ) {
        print STDERR "($$) Redis: error in preparing cache key (Key: $Param{Key})\n";
    }
    return $Key;
}

=item _RedisCall()

execute a call to redis. This is a wrapper to centralize communication and prevent execptions to bubble up

    my $Result = $Self->_RedisCall(
        'command',
        @Parameters
    );

=cut

sub _RedisCall {
    my ( $Self, $Command, @Param ) = @_;

    # check needed stuff
    if ( !defined $Command ) {
        $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need Command!" );
        return;
    }

    my $MaxTries = $Self->{Config}->{'max_tries'} || 3;
    my $WaitBetweenTries = $Self->{Config}->{'wait_between_tries'} || 100;
    my $Result;
    my $Reconnect;

    return if $Self->{StopReconnect};

    TRYLOOP:
    eval {
        if ( $Reconnect || ( !$Self->{RedisObject} && $Self->{Config}) ) {
            $Reconnect = 0;
            $Self->_InitRedis();
        }
        $Result = $Self->{RedisObject}->$Command(@Param);
    };
    if ( defined $@ && $@ ) {
        print STDERR "($$) Redis exception: $@\n";
        if ( --$MaxTries > 0 ) {
            print STDERR "($$) Redis: reconnecting and trying again\n";
            Time::HiRes::sleep($WaitBetweenTries/1000);
            # force a reconnect on retry
            $Reconnect = 1;
            goto TRYLOOP;
        }
        else {
            print STDERR "($$) Redis: giving up\n";
            $Self->{StopReconnect} = 1;
        }
    };

    return $Result;
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
