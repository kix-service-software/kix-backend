# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Reporting::DataSourceGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Reporting::DataSourceGet - API Reporting Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'DataSource' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform DataSourceGet Operation. This function is able to return
one or more entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            DataSource => 'TimeBased'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            DataSource => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @Result;

    my $DataSources = $Kernel::OM->Get('Config')->Get('Reporting::DataSource');

    # start loop
    foreach my $DataSource ( @{$Param{Data}->{DataSource}} ) {

	    # get the DataSource data
	    my %DataSourceData = $Kernel::OM->Get('Reporting')->DataSourceGet(
	        Name => $DataSource,
	    );

        if ( !%DataSourceData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add some more data
        $DataSourceData{Name}        = $DataSource;
        $DataSourceData{DisplayName} = $DataSources->{$DataSource}->{DisplayName};

        # add
        push(@Result, \%DataSourceData);
    }

    if ( scalar(@Result) == 1 ) {
        return $Self->_Success(
            DataSource => $Result[0],
        );
    }

    # return result
    return $Self->_Success(
        DataSource => \@Result,
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
