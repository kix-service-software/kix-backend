# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use CGI;
use Kernel::System::WebRequest;

{
    local %ENV = (
        REQUEST_METHOD => 'GET',
        QUERY_STRING   => 'a=4;b=5',
    );

    CGI->initialize_globals();
    my $Request = Kernel::System::WebRequest->new();

    my @ParamNames = $Request->GetParamNames();
    $Self->IsDeeply(
        [ sort @ParamNames ],
        [qw/a b/],
        'ParamNames',
    );

    $Self->Is(
        $Request->GetParam( Param => 'a' ),
        4,
        'SingleParam',
    );

    $Self->Is(
        $Request->GetParam( Param => 'aia' ),
        undef,
        'SingleParam - not defined',
    );

    local $CGI::POST_MAX = 1024;    ## no critic

    $Request->{Query}->{'.cgi_error'} = 'Unittest failed ;-)';

    $Self->Is(
        $Request->Error(),
        'Unittest failed ;-) - POST_MAX=1KB',
        'Error()',
    );

}

{
    my $PostData = 'a=4&b=5;d=2';
    local %ENV = (
        REQUEST_METHOD => 'POST',
        CONTENT_LENGTH => length($PostData),
        QUERY_STRING   => 'c=4;c=5;b=6',
    );

    local *STDIN;
    open STDIN, '<:utf8', \$PostData;    ## no critic

    CGI->initialize_globals();
    my $Request = Kernel::System::WebRequest->new();

    my @ParamNames = $Request->GetParamNames();
    $Self->IsDeeply(
        [ sort @ParamNames ],
        [qw/a b c d/],
        'ParamNames',
    );

    $Self->IsDeeply(
        [ $Request->GetArray( Param => 'a' ) ],
        [4],
        'Param a, from POST',
    );

    $Self->IsDeeply(
        [ $Request->GetArray( Param => 'b' ) ],
        [5],
        'Param b, from POST (GET ignored)',
    );
    $Self->IsDeeply(
        [ $Request->GetArray( Param => 'c' ) ],
        [ 4, 5 ],
        'Param c, from GET',
    );
    $Self->IsDeeply(
        [ $Request->GetArray( Param => 'd' ) ],
        [2],
        'Param d, from POST',
    );

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
