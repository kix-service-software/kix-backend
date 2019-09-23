# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::GeneralCatalog::GeneralCatalogItemSearch - API GeneralCatalogItem Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform GeneralCatalogItemSearch Operation. This will return a GeneralCatalogItem list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            GeneralCatalogItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    my @GeneralCatalogDataList;

    my $GeneralCatalogClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ClassList();
    
    foreach my $Class ( @$GeneralCatalogClassList ){
     	
	    my $GeneralCatalogItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
	        Class => $Class,
            Valid => 0,
	    );
   
	    # get already prepared GeneralCatalog data from GeneralCatalogGet operation
	    if ( IsHashRefWithData($GeneralCatalogItemList) ) {   
	        my $GeneralCatalogGetResult = $Self->ExecOperation(
	            OperationType => 'V1::GeneralCatalog::GeneralCatalogItemGet',
	            Data      => {
	                GeneralCatalogItemID => join(',', sort keys %$GeneralCatalogItemList),
	            }
	        );    
	
	        if ( !IsHashRefWithData($GeneralCatalogGetResult) || !$GeneralCatalogGetResult->{Success} ) {
	            return $GeneralCatalogGetResult;
	        }
	        push @GeneralCatalogDataList,IsArrayRefWithData($GeneralCatalogGetResult->{Data}->{GeneralCatalogItem}) ? @{$GeneralCatalogGetResult->{Data}->{GeneralCatalogItem}} : ( $GeneralCatalogGetResult->{Data}->{GeneralCatalogItem} );
	    }	            	
    }

    if ( IsArrayRefWithData(\@GeneralCatalogDataList) ) {
        return $Self->_Success(
            GeneralCatalogItem => \@GeneralCatalogDataList,
        )
    }
    
    # return result
    return $Self->_Success(
        GeneralCatalogItem => [],
    );
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
