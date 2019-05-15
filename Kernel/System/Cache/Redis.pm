# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache::Redis;

use strict;
use warnings;

use Redis;
use Storable qw();
use MIME::Base64;
use Digest::MD5 qw();
umask 002;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

use vars qw(@ISA);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config} = $ConfigObject->Get('Cache::Module::Redis');
    if ( $Self->{Config} ) {
        $Self->_initRedis();
    }

    return $Self;
}

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value TTL)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return if !$Self->{RedisObject};

    my $PreparedKey = $Self->_prepareMemCacheKey(%Param);
    my $TTL = $Param{TTL};
    if ($Self->{Config}->{OverrideTTL}) {
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

    my $Result = $Self->{RedisObject}->setex(
        $PreparedKey, 
        $TTL, 
        $Value,
    );

    $Kernel::OM->Get('Kernel::System::Cache')->_Debug(0, "    Redis: executed setex() for key \"$PreparedKey\" (Result=$Result)");

    return $Result;
}

sub Get {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if !$Self->{RedisObject};

    my $PreparedKey = $Self->_prepareMemCacheKey(%Param);

    my $Value = $Self->{RedisObject}->get(
        $PreparedKey,
    );

    #$Kernel::OM->Get('Kernel::System::Cache')->_Debug(0, "    Redis: executed get() for key \"$PreparedKey\" (Value=$Value)");

    return $Value if !$Value || substr($Value, 0, 10) ne '__base64::';

    # restore Value
    $Value = substr($Value, 10);
    return eval { Storable::thaw( MIME::Base64::decode_base64($Value) ) };
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if ( !$Self->{RedisObject} );

    return $Self->{RedisObject}->del(
        $Self->_prepareMemCacheKey(%Param)
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

        # delete keys
        my $OK = $Self->{RedisObject}->del(@Keys);

        $Kernel::OM->Get('Kernel::System::Cache')->_Debug(0, "    Redis: executed del() for $KeyCount keys of type \"$Param{Type}\" (deleted $OK/$KeyCount)");
        $Kernel::OM->Get('Kernel::System::Cache')->_Debug(0, "    Redis: cleaned up type \"$Param{Type}\"");
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
            $Kernel::OM->Get('Kernel::System::Cache')->_Debug(0, "    Redis: executing flushall()");
            return $Self->{RedisObject}->flushall();
        }        
    }
}

=item _initMemCache()

initialize connection to Redis

    my $Value = $CacheInternalObject->_initRedis();

=cut

sub _initRedis {
    my ( $Self, %Param ) = @_;

    my %InitParams = (
        server => $Self->{Config}->{Server},
        %{ $Self->{Config}->{Parameters} || {} },
    );

    $Self->{RedisObject} = Redis->new(%InitParams)
        || die "Unable to initialize Redis connection!";

    return 1;
}

=item _prepareMemCacheKey()

Use MD5 digest of Key for memcached key (memcached key max length is 250);
we use here algo similar to original one from FileStorable.pm.
(thanks to Informatyka Boguslawski sp. z o.o. sp.k., http://www.ib.pl/ for testing and contributing the MD5 change)

    my $PreparedKey = $CacheInternalObject->_prepareMemCacheKey(
        'SomeKey',
    );

=cut

sub _prepareMemCacheKey {
    my ( $Self, %Param ) = @_;

    if ($Param{Raw}) {
        return $Param{Type}.'::'.$Param{Key};
    }

    my $Key = $Param{Key};
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Key );
    $Key = Digest::MD5::md5_hex($Key);
    $Key = $Param{Type} . '::' . $Key;
    return $Key;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
