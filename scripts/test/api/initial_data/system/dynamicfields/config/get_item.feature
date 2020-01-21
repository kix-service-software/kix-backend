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
    And the response contains the following attributes
      | CountMin | CountMax | CountDefault | PossibleNone |
      | 0        | 1        | 0            | 1            |      

  Scenario: get an existing dynamicfield MobileProcessingState PossibleValues
    When I query the collection of dynamicfield MobileProcessingState
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
    And the response contains the following PossibleValues
      | assigned | downloaded | rejected | accepted | processing | suspended | completed | partially | executed | cancelled | TranslatableValues |
      | assigned | downloaded | rejected | accepted | processing | suspended | completed | partially | executed | cancelled | TranslatableValues | 

  Scenario: get an existing dynamicfield RiskAssumptionRemark
    When I query the collection of dynamicfield RiskAssumptionRemark
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
#    Then the response contains 1 items of type "DynamicField"
    And the response contains the following attributes
      | CountDefault | CountMax | CountMin |
      | 0            | 1        | 0        |

  Scenario: get an existing dynamicfield MobileProcessingChecklist010
    When I query the collection of dynamicfield MobileProcessingChecklist010
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
#    Then the response contains 1 items of type "DynamicField"
   And the response contains the following attributes
      | Cols | CountDefault | CountMax | CountMin | DefaultValue | ItemSeparator | Link | RegEx | RegExError | Rows | Time-to-live |
      | -    | 1            | 1        | 1        | 0            | -             | n.a. | -     | 0          | -    | -            |

  Scenario: get an existing dynamicfield MobileProcessingChecklist020
    When I query the collection of dynamicfield MobileProcessingChecklist020
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
#    Then the response contains 1 items of type "DynamicFieldConfig"
    And the response contains the following attributes
      | Rows | CountMax | CountDefault | RegEx | RegExError | ItemSeparator | Link | Cols | DefaultValue | CountMin | Time-to-live |
      | -    | 1        | 1            | -     | -          | -             | n.a. | -    |              | 1        | -            |




    
