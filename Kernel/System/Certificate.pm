# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Certificate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    Cache
    FileTemp
);

use MIME::Base64 qw();

=head1 NAME

Kernel::System::Certificate - Certificate backend lib

=head1 SYNOPSIS

This is a sub module of Kernel::System::Certificate contains all Certificate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'Certificate';
    $Self->{CacheTTL}  = 60 * 60 * 24;

    return 0 if !$Self->_Init();

    return $Self;
}


=item CertificateCreate()

create a local certificate

    my $Success = $CryptObject->CertificateCreate(
        ## TODO: filling with parameters
    );

    return boolean?

=cut

sub CertificateCreate {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckCertificate(%Param);

    my $Attributes = $Self->_GetCertificateAttributes(
        File => $Param{File}
    );

    return if !$Attributes;

    my $Filename = 'Certificate'
        . q{/}
        . $Param{ObjectType}
        . q{/}
        . $Attributes->{Fingerprint};

    my @Exists = $Self->CertificateSearch(
        Filename => $Filename
    );

    if ( scalar(@Exists) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate already exists!'
            );
        }
        return;
    }

    my %Preferences;
    for my $Key ( sort keys %{$Attributes} ) {
        $Preferences{$Key} = $Attributes->{$Key};
    }

    my $Content = $Param{File}->{Content};

    my $FileID = $Kernel::OM->Get('VirtualFS')->Write(
        Content     => \$Content,
        Filename    => $Filename,
        Mode        => 'binary',
        Preferences => \%Preferences,
        Silent      => $Param{Silent}
    );

    if ( !$FileID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be create!'
            );
        }
        return;
    }

    my $Path = $Self->{CertPath};
    if ( $Preferences{Type} eq 'Private') {
        $Path = $Self->{PrivatePath};
    }

    $Path .= '/KIX_'
        . $Preferences{Type}
        . q{_}
        . $FileID;

    my $Success = $Kernel::OM->Get('Main')->FileWrite(
        Location => $Path,
        Content  => \$Content,
        Mode     => 'binmode'
    );

    if ( !$Success ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be create!'
            );
        }
        $Self->CertificateDelete(
            ID     => $FileID,
            Silent => $Param{Silent}
        );

        return;
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return $FileID;
}

=item CertificateGet()

get a local certificate

    my $Certificate = $CryptObject->CertificateGet(

    );

=cut

sub CertificateGet {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need ID!'
            );
        }
        return;
    }

    my $Mode = 'Preferences';
    if ( $Param{Include} eq 'Content' ) {
        $Mode = 'binary';
    }

    my $CacheKey = 'Certificate::'
        . $Param{ID}
        . q{::}
        . $Mode;

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );

    # return if cache found,
    return $Cache if ref $Cache eq 'HASH';

    my %File = $Kernel::OM->Get('VirtualFS')->Read(
        ID       => $Param{ID},
        Mode     => $Mode,
        Silent   => $Param{Silent}
    );

    if ( !%File ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be found!'
            );
        }
        return;
    }
    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Certificate = $File{Preferences};
    $Certificate->{FileID}   = $Param{ID};
    $Certificate->{Filename} = $Filename;

    # remove unnessary datas
    for my $Key ( qw(Filesize FilesizeRaw) ) {
        delete $Certificate->{$Key};
    }

    if ( $Param{Include} eq 'Content' ) {
        $Certificate->{Content} = ${$File{Content}};
    }

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Certificate,
            TTL   => $Self->{CacheTTL},
        );
    }

    return $Certificate;
}

=item CertificateDelete()

remove a local certificate

    $CryptObject->CertificateDelete(
        ID => 1
    );

=cut

sub CertificateDelete {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need ID!"
            );
        }
        return;
    }

    my %File = $Kernel::OM->Get('VirtualFS')->Read(
        ID     => $Param{ID},
        Silent => $Param{Silent},
        Mode   => 'Preferences'
    );

    if ( !%File ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No certificate found!"
            );
        }
        return;
    }

    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Path = $Self->{CertPath};
    if ( $File{Preferences}->{Type} eq 'Private' ) {
        $Path = $Self->{PrivatePath};
    }

    $Path .= "/$Filename";

    my $Success;
    if ( -e $Path ) {
        $Success = $Kernel::OM->Get('Main')->FileDelete(
            Location        => $Path,
            DisableWarnings => $Param{Silent}
        );

        if ( !$Success ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Couldn't delete certificate!"
                );
            }
            return;
        }
    }

    $Success = $Kernel::OM->Get('VirtualFS')->Delete(
        ID              => $Param{ID},
        DisableWarnings => $Param{Silent}
    );

    if ( !$Success ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Couldn't delete certificate!"
            );
        }
        return;
    }

    return 1;
}

=item CertificateSearch()

get list of local certificates filenames

    my @CertList = $CryptObject->CertificateSearch();

=cut

sub CertificateSearch {
    my ( $Self, %Param ) = @_;

    my %SearchWhat;
    for my $Key ( qw(ObjectType Type) ) {
        next if !$Param{$Key};
        $SearchWhat{Preferences}->{$Key} = $Param{$Key};
    }

    if ( $Param{Filename} ) {
        $SearchWhat{Filename} = $Param{Filename};
    }
    else {
        $SearchWhat{Filename} = 'Certificate/*';
    }

    my $CacheKey = 'CertificateSearch';
    for my $Key ( qw(ObjectType Type Filename) ) {
        next if !$Param{$Key};
        $CacheKey .= q{::}
            . $Key
            . q{::}
            . $Param{$Key};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # return if cache found,
    return @{$Cache} if ref $Cache eq 'ARRAY';
print STDERR Data::Dumper::Dumper(\%SearchWhat);
    my @CertIDs = $Kernel::OM->Get('VirtualFS')->Find(
        %SearchWhat,
        ReturnIDs => 1
    );
print STDERR Data::Dumper::Dumper(\@CertIDs);

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => \@CertIDs,
            TTL   => $Self->{CacheTTL},
        );
    }

    return @CertIDs;
}

sub _CheckCertificate {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(File Type) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    for my $Needed ( qw(Content FilesizeRaw ContentType Filename) ) {
        if ( !$Param{File}->{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed in File!"
                );
            }
            return;
        }
    }

    if (
        $Param{Type} eq 'Private'
        && !$Param{Passphrase}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need Passphrase!"
            );
        }
        return;
    }

    return 1;
}

sub _GetCertificateAttributes {
    my ( $Self, %Param ) = @_;

    if ( !$Param{File} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need File!'
        );
        return;
    }

    my $File = $Param{File};

    my $Content = MIME::Base64::decode_base64( $File->{Content} );

    my $CacheKey = 'Certificate::'
        . ( $Param{ObjectType} ? $Param{ObjectType} . q{::} : q{} )
        . 'Attributes::Filename::'
        . $File->{Filename};

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # return if cache found,
    return $Cache if ref $Cache eq 'HASH';

    # get temp file
    my ( $FH, $Filename ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print {$FH} $Content;
    close $FH or return;

    if ( !-e $Filename ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Filename!",
        );
        return;
    }
    my $Attributes = $Self->_FetchAttributes( Filename => $Filename );

    if ( $Attributes->{Hash} ) {
        # my ($Private) = $Self->PrivateGet($Attributes);
        # if ($Private) {
        #     $Attributes->{Private} = 'Yes';
        # }
        # else {
        #     $Attributes->{Private} = 'No';
        # }
        $Attributes->{Type} = 'Cert';
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t add invalid certificate!'
        );
        return;
    }

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Attributes,
            TTL   => $Self->{CacheTTL}
        );
    }

    return $Attributes;
}

sub _FetchAttributes {
    my ( $Self, %Param ) = @_;

    my $AttributesRef;
    my $Filename = $Param{Filename};

    # testing new solution
    my $OptionString = '-subject_hash '
        . '-issuer '
        . '-fingerprint -sha1 '
        . '-serial '
        . '-subject '
        . '-startdate '
        . '-enddate '
        . '-email '
        . '-modulus ';

    # call all attributes at same time
    my $Options = "x509 -in $Filename -noout $OptionString";

    # get the output string
    my $Output = qx{$Self->{Cmd} $Options 2>&1};

    # filters
    my %Filters = (
        Hash        => '(\w{8})',
        Issuer      => 'issuer=\s*(.*)',
        Fingerprint => 'SHA1\sFingerprint=(.*)',
        Serial      => 'serial=(.*)',
        Subject     => 'subject=\s*(.*)',
        StartDate   => 'notBefore=(.*)',
        EndDate     => 'notAfter=(.*)',
        Email       => '([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})',
        Modulus     => 'Modulus=(.*)',
    );

    # parse output string
    my @Attributes = split( /\n/sm, $Output );
    for my $Line (@Attributes) {

        # clean end spaces
        $Line =~ tr{\r\n}{}d;

        # look for every attribute by filter
        FILTER:
        for my $Filter ( sort keys %Filters ) {
            my @Matches = $Line =~ m{ \A $Filters{$Filter} \z }xms;

            next FILTER if !scalar(@Matches);

            my $Match = $Matches[0] || q{};

            # email filter is allowed to match multiple times for alternate names (SubjectAltName)
            if ( $Filter eq 'Email' ) {
                push @{ $AttributesRef->{$Filter} }, $Match;
            }

            # all other filters are one-time matches, so we exclude the filter from all remaining lines (performance)
            else {
                $AttributesRef->{$Filter} = $Match;
                delete $Filters{$Filter};
            }

            last FILTER;
        }
    }

    # prepare attributes data for use
    if ( ref $AttributesRef->{Email} eq 'ARRAY' ) {
        $AttributesRef->{Email} = join ', ', sort @{ $AttributesRef->{Email} };
    }
    if ( $AttributesRef->{Issuer} ) {
        $AttributesRef->{Issuer} =~ s{=}{= }xmsg;
    }
    if ( $AttributesRef->{Subject} ) {
        $AttributesRef->{Subject} =~ s{\/}{ }xmsg;
        $AttributesRef->{Subject} =~ s{=}{= }xmsg;
    }

    my %Month = (
        Jan => '01',
        Feb => '02',
        Mar => '03',
        Apr => '04',
        May => '05',
        Jun => '06',
        Jul => '07',
        Aug => '08',
        Sep => '09',
        Oct => '10',
        Nov => '11',
        Dec => '12',
    );

    for my $DateType ( 'StartDate', 'EndDate' ) {
        next if !$AttributesRef->{$DateType};
        my @Date = $AttributesRef->{$DateType} =~ /(.+?)\s(.+?)\s(\d\d:\d\d:\d\d)\s(\d\d\d\d)/sm;

        next if !@Date || scalar(@Date) < 4;

        my $D = sprintf('%02d', $Date[1]);
        my $M = q{};
        my $Y = $Date[3];

        MONTH_KEY:
        for my $MonthKey ( sort keys %Month ) {
            if ( $AttributesRef->{$DateType} =~ /$MonthKey/i ) {
                $M = $Month{$MonthKey};
                last MONTH_KEY;
            }
        }
        $AttributesRef->{"Short$DateType"} = "$Y-$M-$D";
    }

    return $AttributesRef;
}


sub _Init {
    my ( $Self, %Param ) = @_;

    $Self->{CertPath}    = '/etc/ssl/certs';
    $Self->{PrivatePath} = '/etc/ssl/private';
    $Self->{Bin}         = '/usr/bin/openssl';

    # make sure that we are getting POSIX (i.e. english) messages from openssl
    $Self->{Cmd} = "LC_MESSAGES=POSIX $Self->{Bin}";

    # ensure that there is a random state file that we can write to (otherwise openssl will bail)
    local $ENV{RANDFILE} = $Kernel::OM->Get('Config')->Get('TempDir') . '/.rnd';

    # prepend RANDFILE declaration to openssl cmd
    $Self->{Cmd} = "HOME="
        . $Kernel::OM->Get('Config')->Get('Home')
        . " RANDFILE=$ENV{RANDFILE} $Self->{Cmd}";

    return $Self->_Check();
}

=item Check()

check if environment is working

    my $Message = $CryptObject->Check();

=cut

sub _Check {
    my ( $Self, %Param ) = @_;

    my $Success = 1;
    if ( !-e $Self->{Bin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{Bin}!",
        );
        $Success = 0;
    }
    elsif ( !-x $Self->{Bin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{Bin} not executable!",
        );
        $Success = 0;
    }

    if ( !-e $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath}!",
        );
        $Success = 0;
    }
    elsif ( !-d $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath} directory!",
        );
        $Success = 0;
    }
    elsif ( !-w $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{CertPath} not writable!",
        );
        $Success = 0;
    }

    if ( !-e $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath}!",
        );
        $Success = 0;
    }
    elsif ( !-d $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath} directory!",
        );
        $Success = 0;
    }
    elsif ( !-w $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{PrivatePath} not writable!",
        );
        $Success = 0;
    }

    return $Success;
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
