# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::DB;

use strict;
use warnings;

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Encode',
    'Log',
    'Main',
    'Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug} = $Param{Config}->{Debug} || 0;

    # get user table
    $Self->{UserTable} = $Param{Config}->{Table} || 'users';
    $Self->{UserTableUserID} = $Param{Config}->{Columns}->{ID} || 'id';
    $Self->{UserTableUserPW} = $Param{Config}->{Columns}->{Password} || 'pw';
    $Self->{UserTableUser} = $Param{Config}->{Columns}->{Login} || 'login';

    return $Self;
}

sub GetAuthMethod {
    my ( $Self, %Param ) = @_;

    return {
        Type    => 'LOGIN',
        PreAuth => 0
    };
}

sub Auth {
    my ( $Self, %Param ) = @_;

    # do nothing if we have no relevant data for us
    return if !$Param{User};

    # get params
    my $User       = $Param{User}      || '';
    my $Pw         = $Param{Pw}        || '';
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';
    my $UserID     = '';
    my $GetPw      = '';
    my $Method;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql query
    my $SQL = "SELECT $Self->{UserTableUserPW}, $Self->{UserTableUserID}, $Self->{UserTableUser} "
        . " FROM "
        . " $Self->{UserTable} "
        . " WHERE "
        . " valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet())} ) AND "
        . " $Self->{UserTableUser} = '" . $DBObject->Quote($User) . "'";
    $DBObject->Prepare( SQL => $SQL );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $GetPw  = $Row[0];
        $UserID = $Row[1];
        $User   = $Row[2];
    }

    # get needed objects
    my $EncodeObject = $Kernel::OM->Get('Encode');
    my $ConfigObject = $Kernel::OM->Get('Config');

    # crypt given pw
    my $CryptedPw = '';
    my $Salt      = $GetPw;
    if (
        $ConfigObject->Get('AuthModule::DB::CryptType')
        && $ConfigObject->Get('AuthModule::DB::CryptType') eq 'plain'
        )
    {
        $CryptedPw = $Pw;
        $Method    = 'plain';
    }

    # md5, bcrypt or sha pw
    elsif ( $GetPw !~ /^.{13}$/ ) {

        # md5 pw
        if ( $GetPw =~ m{\A \$.+? \$.+? \$.* \z}xms ) {

            # strip Salt
            $Salt =~ s/^(\$.+?\$)(.+?)\$.*$/$2/;
            my $Magic = $1;

            # encode output, needed by unix_md5_crypt() only non utf8 signs
            $EncodeObject->EncodeOutput( \$Pw );
            $EncodeObject->EncodeOutput( \$Salt );

            if ( $Magic eq '$apr1$' ) {
                $CryptedPw = apache_md5_crypt( $Pw, $Salt );
                $Method = 'apache_md5_crypt';
            }
            else {
                $CryptedPw = unix_md5_crypt( $Pw, $Salt );
                $Method = 'unix_md5_crypt';
            }

        }

        # sha256 pw
        elsif ( $GetPw =~ m{\A .{64} \z}xms ) {

            my $SHAObject = Digest::SHA->new('sha256');

            # encode output, needed by sha256_hex() only non utf8 signs
            $EncodeObject->EncodeOutput( \$Pw );

            $SHAObject->add($Pw);
            $CryptedPw = $SHAObject->hexdigest();
            $Method    = 'sha256';
        }

        elsif ( $GetPw =~ m{^BCRYPT:} ) {

            # require module, log errors if module was not found
            if ( !$Kernel::OM->Get('Main')->Require('Crypt::Eksblowfish::Bcrypt') )
            {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "User: '$User' tried to authenticate with bcrypt but 'Crypt::Eksblowfish::Bcrypt' is not installed!",
                );
                return;
            }

            # get salt and cost from stored PW string
            my ( $Cost, $Salt, $Base64Hash ) = $GetPw =~ m{^BCRYPT:(\d+):(.{16}):(.*)$}xms;

            # remove UTF8 flag, required by Crypt::Eksblowfish::Bcrypt
            $EncodeObject->EncodeOutput( \$Pw );

            # calculate password hash with the same cost and hash settings
            my $Octets = Crypt::Eksblowfish::Bcrypt::bcrypt_hash(
                {
                    key_nul => 1,
                    cost    => $Cost,
                    salt    => $Salt,
                },
                $Pw
            );

            $CryptedPw = "BCRYPT:$Cost:$Salt:" . Crypt::Eksblowfish::Bcrypt::en_base64($Octets);
            $Method    = 'bcrypt';
        }

        # fallback: sha1 pw
        else {

            my $SHAObject = Digest::SHA->new('sha1');

            # encode output, needed by sha1_hex() only non utf8 signs
            $EncodeObject->EncodeOutput( \$Pw );

            $SHAObject->add($Pw);
            $CryptedPw = $SHAObject->hexdigest();
            $Method    = 'sha1';
        }
    }

    # crypt pw
    else {

        # strip Salt only for (Extended) DES, not for any of Modular crypt's
        if ( $Salt !~ /^\$\d\$/ ) {
            $Salt =~ s/^(..).*/$1/;
        }

        # encode output, needed by crypt() only non utf8 signs
        $EncodeObject->EncodeOutput( \$Pw );
        $EncodeObject->EncodeOutput( \$Salt );
        $CryptedPw = crypt( $Pw, $Salt );
        $Method = 'crypt';
    }

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message =>
                "User: '$User' tried to authenticate with Pw: '$Pw' ($UserID/$Method/$CryptedPw/$GetPw/$Salt/$RemoteAddr)",
        );
    }

    # just a note
    if ( !$Pw ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User without Pw!!! (REMOTE_ADDR: $RemoteAddr)",
        );
        return;
    }

    # login note
    elsif ( ( ($GetPw) && ($User) && ($UserID) ) && $CryptedPw eq $GetPw ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User authentication ok (Method: $Method, REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\").",
        );
        return $User;
    }

    # just a note
    elsif ( ($UserID) && ($GetPw) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message =>
                "User: $User authentication with wrong Pw!!! (Method: $Method, REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\")"
        );
        return;
    }

    # just a note
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $User doesn't exist or is invalid!!! (REMOTE_ADDR: $RemoteAddr, Backend: \"$Self->{Config}->{Name}\")"
        );
        return;
    }
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
