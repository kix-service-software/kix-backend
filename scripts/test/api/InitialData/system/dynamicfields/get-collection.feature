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
    Then the response contains 17 items of type "DynamicField"
    And the response contains the following items of type DynamicField
      | Name                         |  |  | Label                   | FieldType               | ObjectType   | InternalField | CustomerVisible |
      | AcknowledgeName              |  |  | System Acknowledge Name | Text                    | Ticket       | 0             | 0               |
      | AffectedAsset                |  |  | Affected Asset          | ITSMConfigItemReference | Ticket       | 0             | 1               |
      | MobileProcessingChecklist010 |  |  | Checklist 01            | CheckList               | Ticket       | 0             | 0               |
      | MobileProcessingChecklist020 |  |  | Checklist 02            | CheckList               | Ticket       | 0             | 0               |
      | MobileProcessingState        |  |  | Mobile Processing       | Multiselect             | Ticket       | 1             | 0               |
      | PlanBegin                    |  |  | Plan Begin              | DateTime                | Ticket       | 0             | 0               |
      | PlanEnd                      |  |  | Plan End                | DateTime                | Ticket       | 0             | 0               |
      | RelatedAssets                |  |  | Related Assets          | ITSMConfigItemReference | FAQArticle   | 0             | 0               |
      | RiskAssumptionRemark         |  |  | Risk Assumption Remark  | TextArea                | Ticket       | 0             | 0               |
      | Source                       |  |  | Source                  | Text                    | Contact      | 0             | 0               |
      | SysMonXAddress               |  |  | System Address          | Text                    | Ticket       | 0             | 0               |
      | SysMonXAlias                 |  |  | System Alias            | Text                    | Ticket       | 0             | 0               |
      | SysMonXHost                  |  |  | System Host             | Text                    | Ticket       | 0             | 0               |
      | SysMonXService               |  |  | System Service          | Text                    | Ticket       | 0             | 0               |
      | SysMonXState                 |  |  | System State            | Text                    | Ticket       | 0             | 0               | 
      | Type                         |  |  | Type                    | Multiselect             | Organisation | 0             | 0               |
      | WorkOrder                    |  |  | Work Order              | TextArea                | Ticket       | 0             | 0               |






