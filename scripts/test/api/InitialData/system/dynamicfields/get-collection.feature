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
      | Name                         | Label                   | FieldTypeDisplayName    | FieldType               | ObjectType   | InternalField | CustomerVisible |
      | AcknowledgeName              | System Acknowledge Name | Text                    | Text                    | Ticket       | 0             | 0               |
      | AffectedAsset                | Affected Asset          | AssetReference          | ITSMConfigItemReference | Ticket       | 0             | 1               |
      | MobileProcessingChecklist010 | Checklist 01            | Checklist               | CheckList               | Ticket       | 0             | 0               |
      | MobileProcessingChecklist020 | Checklist 02            | Checklist               | CheckList               | Ticket       | 0             | 0               |
      | MobileProcessingState        | Mobile Processing       | Selection               | Multiselect             | Ticket       | 1             | 0               |
      | PlanBegin                    | Plan Begin              | Date / Time             | DateTime                | Ticket       | 0             | 0               |
      | PlanEnd                      | Plan End                | Date / Time             | DateTime                | Ticket       | 0             | 0               |
      | RelatedAssets                | Related Assets          | AssetReference          | ITSMConfigItemReference | FAQArticle   | 0             | 0               |
      | RiskAssumptionRemark         | Risk Assumption Remark  | Textarea                | TextArea                | Ticket       | 0             | 0               |
      | Source                       | Source                  | Text                    | Text                    | Contact      | 0             | 0               |
      | SysMonXAddress               | System Address          | Text                    | Text                    | Ticket       | 0             | 0               |
      | SysMonXAlias                 | System Alias            | Text                    | Text                    | Ticket       | 0             | 0               |
      | SysMonXHost                  | System Host             | Text                    | Text                    | Ticket       | 0             | 0               |
      | SysMonXService               | System Service          | Text                    | Text                    | Ticket       | 0             | 0               |
      | SysMonXState                 | System State            | Text                    | Text                    | Ticket       | 0             | 0               |
      | Type                         | Type                    | Selection               | Multiselect             | Organisation | 0             | 0               |
      | WorkOrder                    | Work Order              | Textarea                | TextArea                | Ticket       | 0             | 0               |





