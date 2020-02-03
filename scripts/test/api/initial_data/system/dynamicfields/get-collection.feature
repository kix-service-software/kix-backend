Feature: GET request to the /system/dynamicfields resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing dynamicfields
    When I query the collection of dynamicfields
    Then the response code is 200

  Scenario: get the list of existing dynamicfields 
    When I query the collection of dynamicfields
    Then the response code is 200
    Then the response contains 4 items of type "DynamicField"
    And the response contains the following items of type DynamicField
      | Name                         | Label                  | FieldType | ObjectType |
      | MobileProcessingState        | Mobile Processing      | Dropdown  | Ticket     |      
      | RiskAssumptionRemark         | Risk Assumption Remark | TextArea  | Ticket     |
      | MobileProcessingChecklist010 | Checklist 01           | TextArea  | Ticket     |
      | MobileProcessingChecklist020 | Checklist 02           | TextArea  | Ticket     |
      

      
      
      
      