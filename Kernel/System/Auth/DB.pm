# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

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

    # get params
    my $User       = $Param{User}      || '';
    my $Pw         = $Param{Pw}        || '';
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';
    my $UserID     = '';
    my $GetPw      = '';

    # just a note
    if ( !$User ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::DB] No User given! "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
        return;
    }

    # just a note
    if ( !$Pw ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::DB] User '$User' authentication without Pw! "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
        return;
    }

    # get crypted password from database
    my $UserLogin = lc($User);
    my $SQL = "SELECT $Self->{UserTableUserPW}, $Self->{UserTableUserID}, $Self->{UserTableUser} "
        . " FROM "
        . " $Self->{UserTable} "
        . " WHERE "
        . " valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Valid')->ValidIDsGet())} ) AND "
        . " $Self->{Lower}($Self->{UserTableUser}) = ?";
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Bind  => [ \$UserLogin ],
        Limit => 1,
    );

    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $GetPw  = $Row[0];
        $UserID = $Row[1];
        $User   = $Row[2];
    }

    # encode output, needed by sha256_hex() only non utf8 signs
    $Kernel::OM->Get('Encode')->EncodeOutput( \$Pw );

    # crypt given password with sha 256
    my $SHAObject = Digest::SHA->new('sha256');
    $SHAObject->add($Pw);
    my $CryptedPw = $SHAObject->hexdigest();

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "[Auth::DB] User '$User' tried to authenticate. "
                . "(Data: '$UserID'/'$CryptedPw'/'$GetPw', REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
    }

    # compare password
    if ( ( ($GetPw) && ($User) && ($UserID) ) && $CryptedPw eq $GetPw ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::DB] User '$User' authentication ok. "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')",
        );
        return $User;
    }

    # just a note
    elsif ( ($UserID) && ($GetPw) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::DB] User '$User' authentication with wrong Pw. "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')"
        );
        return;
    }

    # just a note
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "[Auth::DB] User '$User' doesn't exist or is invalid. "
                . "(REMOTE_ADDR: '$RemoteAddr', Backend: '$Self->{Config}->{Name}')"
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
