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
        $Value = '__base64::'.MIME::Base64::encode_base64( Storable::nfreeze( $Param{Value} ) );
    }

    my $Result;
    if ( $TTL > 0 ) {
        $Result = $Self->{RedisObject}->setex(
            $PreparedKey, 
            $TTL, 
            $Value,
        );
    }
    else {
        $Result = $Self->{RedisObject}->set(
            $PreparedKey, 
            $Value,
        );
    }

    if ( $Self->{Config}->{Debug} ) {
        $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: executed setex() for key \"$PreparedKey\" (Result=$Result)");
    }

    return $Result;
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

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);

    my $Value = $Self->{RedisObject}->get(
        $PreparedKey,
    );

    if ($Value && $Self->{Config}->{Debug} ) {
        $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: get() for key \"$PreparedKey\" returned value");
    }

    return $Value if !$Value || substr($Value, 0, 10) ne '__base64::';

    # restore Value
    $Value = substr($Value, 10);
    return eval { Storable::thaw( MIME::Base64::decode_base64($Value) ) };
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

    my @PreparedKeys = map { $Param{UseRawKey} ? $_ : $Self->_PrepareRedisKey($_) } @{$Param{Keys}};

    my @Values = $Self->{RedisObject}->mget(
        @PreparedKeys,
    );

    if ( @Values && $Self->{Config}->{Debug} ) {
        $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: get() for keys \"".(Data::Dumper::Dumper(\@PreparedKeys))."\" returned value");
    }

    return @Values if !@Values;
    
    foreach my $Value ( @Values ) {
        next if substr($Value, 0, 10) ne '__base64::';
        # restore Value
        $Value = substr($Value, 10);
        $Value = eval { Storable::thaw( MIME::Base64::decode_base64($Value) ) };
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

    return if ( !$Self->{RedisObject} );

    my $PreparedKey = $Param{UseRawKey} ? $Param{Key} : $Self->_PrepareRedisKey(%Param);

    return $Self->{RedisObject}->del(
        $PreparedKey
    );
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return if ( !$Self->{RedisObject} );

    if ( $Param{Type} ) {
        # get keys for type 
        my @Keys = $Self->{RedisObject}->keys($Param{Type}.'::*');
        my $KeyCount = @Keys;
        return 1 if !$KeyCount;

        if ( $Self->{Config}->{Debug} ) {
            use Data::Dumper;
            $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: deleting keys of type \"$Param{Type}\": ".Dumper(\@Keys));
        }

        # delete keys
        my $OK = $Self->{RedisObject}->del(@Keys);

        if ( $Self->{Config}->{Debug} ) {
            $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: executed del() for $KeyCount keys of type \"$Param{Type}\" (deleted $OK/$KeyCount)");
            $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: cleaned up type \"$Param{Type}\"");
        }
        return 1;
    }
    else {
        if ( $Param{KeepTypes} ) {
            my %KeepTypeLookup;
            @KeepTypeLookup{ ( @{ $Param{KeepTypes} || [] } ) } = undef;

            # get all keys
            my @Keys = $Self->{RedisObject}->keys('*');

            for my $Key ( @Keys ) {                
                $Key =~ /^(.+?)::/;
                my $Type = $1;
                next if $KeepTypeLookup{$Type};
                $Self->CleanUp( Type => $Type );
            }        
        } 
        else {
            if ( $Self->{Config}->{Debug} ) {
                $Kernel::OM->Get('Cache')->_Debug(0, "    Redis: executing flushall()");
            }
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

    return $Self->{RedisObject}->keys($Param{Type}.'::*');
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
        return $Param{Type}.'::'.$Param{Key};
    }

    my $Key = $Param{Key};
    $Kernel::OM->Get('Encode')->EncodeOutput( \$Key );
    $Key = Digest::MD5::md5_hex($Key);
    $Key = $Param{Type} . '::' . $Key;
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
