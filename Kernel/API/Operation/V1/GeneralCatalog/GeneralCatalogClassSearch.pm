# --
# Kernel/API/Operation/GeneralCatalog/GeneralCatalogClassSearch.pm - API GeneralCatalogClass Search operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::GeneralCatalog::GeneralCatalogClassSearch - API GeneralCatalogClass Search Operation backend

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

perform GeneralCatalogClassSearch Operation. This will return a GeneralCatalogItem list.

    my $Result = $OperationObject->Run(
        Data => {
        	Class = 'ITSM::ConfigItem::Location::Type';                         # optional
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            GeneralCatalog => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebServiceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }
    
    my @GeneralCatalogDataList;

    my $GeneralCatalogClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ClassList();
    
    foreach my $Class ( @$GeneralCatalogClassList ){
     	
	    my $GeneralCatalogItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
	        Class => $Class,
	    );
   
	    # get already prepared GeneralCatalog data from GeneralCatalogGet operation
	    if ( IsHashRefWithData($GeneralCatalogItemList) ) {   
	        my $GeneralCatalogGetResult = $Self->ExecOperation(
	            OperationType => 'V1::GeneralCatalog::GeneralCatalogClassGet',
	            Data      => {
	                GeneralCatalogItemID => join(',', sort keys %$GeneralCatalogItemList),
	            }
	        );    
	
	        if ( !IsHashRefWithData($GeneralCatalogGetResult) || !$GeneralCatalogGetResult->{Success} ) {
	            return $GeneralCatalogGetResult;
	        }
	        push @GeneralCatalogDataList,IsArrayRefWithData($GeneralCatalogGetResult->{Data}->{GeneralCatalog}) ? @{$GeneralCatalogGetResult->{Data}->{GeneralCatalog}} : ( $GeneralCatalogGetResult->{Data}->{GeneralCatalog} );
	    }	            	
    }

    if ( IsArrayRefWithData(\@GeneralCatalogDataList) ) {
        return $Self->_Success(
            GeneralCatalog => \@GeneralCatalogDataList,
        )
    }
    
    # return result
    return $Self->_Success(
        GeneralCatalog => {},
    );
}

1;