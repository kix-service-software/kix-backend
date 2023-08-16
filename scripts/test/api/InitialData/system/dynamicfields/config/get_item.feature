Feature: GET request to the /system/dynamicfields/:DynamicFieldID/config resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing dynamicfield MobileProcessingState
    When I query the collection of dynamicfield MobileProcessingState
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
    And the response contains the following items type of DynamicFieldConfig
      | CountMin | CountMax | CountDefault | PossibleNone |
      | 1        | 1        | 1            | 1            |

  Scenario: get an existing dynamicfield MobileProcessingState PossibleValues
    When I query the collection of dynamicfield MobileProcessingState
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
    And the response contains the following PossibleValues
      | partially executed | cancelled | completed | rejected | suspended | downloaded | accepted | processing | assigned |
      | partially executed | cancelled | completed | rejected | suspended | downloaded | accepted | processing | assigned |

  Scenario: get an existing dynamicfield RiskAssumptionRemark
    When I query the collection of dynamicfield RiskAssumptionRemark
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
#    Then the response contains 1 items of type "DynamicField"
    And the response contains the following Config
      | CountDefault | CountMax | CountMin |
      | 0            | 1        | 0        |

#  Scenario: get an existing dynamicfield PlanEnd
#    When I query the collection of dynamicfield PlanEnd
#    Then the response code is 200
#    When I get this dynamicfield config
#    Then the response code is 200
##    Then the response contains 1 items of type DynamicFieldConfig
#    And the response contains the following Config
#      | CountDefault | CountMax | CountMin | YearsInPast | YearsInFuture | DateRestriction | DefaultValue |
#      | 0            | 1        | 0        | 0           | 0             | none            | 0            |



    
