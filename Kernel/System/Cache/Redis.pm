# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    $Self->{Config} = $ConfigObject->Get('Cache::Module::Redis');
    if ( $Self->{Config} ) {
        $Self->_InitRedis();
    }

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

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    my $PreparedKey = $Self->_PrepareRedisKey(%Param);
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
        $Self->{RedisObject}->hset(
            $Param{Type},
            $PreparedKey,
            $Value,
        );
        $Self->{RedisObject}->expire($Param{Type}, $TTL);
    }
    else {
        $Self->{RedisObject}->hset(
            $Param{Type},
            $PreparedKey, 
            $Value,
        );
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

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);

    my $Value = $Self->{RedisObject}->hget(
        $Param{Type},
        $PreparedKey,
    );

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

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    my @PreparedKeys = map { $Param{UseRawKey} ? $_ : $Self->_PrepareRedisKey($_) } @{$Param{Keys}};

    my @Values = $Self->{RedisObject}->hmget(
        $Param{Type},
        @PreparedKeys,
    );

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

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);

    return $Self->{RedisObject}->hdel(
        $Param{Type},
        $PreparedKey
    );
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    if ( $Param{Type} ) {
        # delete type
        return $Self->{RedisObject}->del($Param{Type});
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
            return $Self->{RedisObject}->flushall();
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

    return if !$Self->{RedisObject};

    # make sure we have an active connection
    $Self->{RedisObject}->connect() if !$Self->{RedisObject}->ping();

    my @Result;
    my $Keys;
    my $Cursor = 0;
    do {
        if ( $Param{Type} ne '*' ) {
            ($Cursor, $Keys) = $Self->{RedisObject}->hscan($Param{Type}, $Cursor);
        }
        else {
            ($Cursor, $Keys) = $Self->{RedisObject}->scan($Cursor);
        }
        push @Result, @{$Keys};
    } while ( $Cursor );

    return @Result;
}

=item _InitRedis()

initialize connection to Redis

    my $Value = $CacheInternalObject->_InitRedis();

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

    my $PreparedKey = $CacheInternalObject->_PrepareRedisKey(
        'SomeKey',
    );

=cut

sub _PrepareRedisKey {
    my ( $Self, %Param ) = @_;

    if ($Param{Raw}) {
        return $Param{Key};
    }

    my $Key = $Param{Key};
    $Kernel::OM->Get('Encode')->EncodeOutput( \$Key );
    $Key = Digest::MD5::md5_hex($Key);
    return $Key;
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
