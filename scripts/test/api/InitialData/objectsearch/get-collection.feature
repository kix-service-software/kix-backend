 Feature: GET request to the /objectsearch/:ObjectType resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as Agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing objectsearch ticket SupportedAttributes
    When I query the collection of objectsearch ticket SupportedAttributes
    Then the response code is 200
    Then the response content is
    And the response contains 85 items of type "SupportedAttributes"
    And the response contains the following items of type SupportedAttributes
      | IsSearchable | IsSortable | ObjectSpecifics | ObjectType | Property                                  | ValueType |
      | 1            | 1          |                 | Ticket     | AccountedTime                             | NUMERIC   |
      | 0            | 1          |                 | Ticket     | Age                                       | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | ArticleCreateTime                         | DATETIME  |
      | 1            | 0          |                 | Ticket     | ArticleFlag.Seen                          | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | ArticleID                                 | NUMERIC   |
      | 0            | 1          |                 | Ticket     | AttachmentCount                           | NUMERIC   |
      | 1            | 0          |                 | Ticket     | AttachmentName                            | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | Body                                      | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | Cc                                        | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | ChangeBy                                  | NUMERIC   |
      | 1            | 1          |                 | Ticket     | ChangeByID                                | NUMERIC   |
      | 1            | 0          |                 | Ticket     | ChangeTime                                | DATETIME  |
      | 1            | 0          |                 | Ticket     | Channel                                   | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | ChannelID                                 | NUMERIC   |
      | 1            | 0          |                 | Ticket     | CloseTime                                 | DATETIME  |
      | 1            | 1          |                 | Ticket     | Contact                                   | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | ContactID                                 | NUMERIC   |
      | 1            | 1          |                 | Ticket     | CreateBy                                  | NUMERIC   |
      | 1            | 1          |                 | Ticket     | CreateByID                                | NUMERIC   |
      | 1            | 0          |                 | Ticket     | CreatedPriorityID                         | NUMERIC   |
      | 1            | 0          |                 | Ticket     | CreatedQueueID                            | NUMERIC   |
      | 1            | 0          |                 | Ticket     | CreatedStateID                            | NUMERIC   |
      | 1            | 0          |                 | Ticket     | CreatedTypeID                             | NUMERIC   |
      | 1            | 1          |                 | Ticket     | CreateTime                                | DATETIME  |
      | 1            | 0          |                 | Ticket     | CustomerVisible                           | NUMERIC   |
      | 1            | 0          |                 | Ticket     | DynamicField_AffectedAsset                | NUMERIC   |
      | 0            | 0          |                 | Ticket     | DynamicField_MobileProcessingChecklist010 | TEXTUAL   |
      | 0            | 0          |                 | Ticket     | DynamicField_MobileProcessingChecklist020 | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_MobileProcessingState        | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_PlanBegin                    | DATETIME  |
      | 1            | 1          |                 | Ticket     | DynamicField_PlanEnd                      | DATETIME  |
      | 1            | 1          |                 | Ticket     | DynamicField_RiskAssumptionRemark         | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_SysMonXAddress               | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_SysMonXAlias                 | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_SysMonXHost                  | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_SysMonXService               | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_SysMonXState                 | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | DynamicField_WorkOrder                    | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | From                                      | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | Fulltext                                  | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | HistoricMyQueues                          | NUMERIC   |
      | 1            | 0          |                 | Ticket     | HistoricOwnerID                           | NUMERIC   |
      | 1            | 0          |                 | Ticket     | HistoricPriorityID                        | NUMERIC   |
      | 1            | 0          |                 | Ticket     | HistoricQueueID                           | NUMERIC   |
      | 1            | 0          |                 | Ticket     | HistoricStateID                           | NUMERIC   |
      | 1            | 0          |                 | Ticket     | HistoricTypeID                            | NUMERIC   |
      | 1            | 1          |                 | Ticket     | ID                                        | NUMERIC   |
      | 1            | 1          |                 | Ticket     | LastChangeTime                            | DATETIME  |
      | 1            | 1          |                 | Ticket     | Lock                                      | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | LockID                                    | NUMERIC   |
      | 1            | 0          |                 | Ticket     | MyQueues                                  | NUMERIC   |
      | 1            | 1          |                 | Ticket     | Organisation                              | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | OrganisationFulltext                      | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | OrganisationID                            | NUMERIC   |
      | 1            | 1          |                 | Ticket     | OrganisationNumber                        | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | Owner                                     | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | OwnerFulltext                             | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | OwnerID                                   | NUMERIC   |
      | 1            | 1          |                 | Ticket     | OwnerName                                 | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | OwnerOutOfOffice                          | NUMERIC   |
      | 1            | 1          |                 | Ticket     | PendingTime                               | DATETIME  |
      | 1            | 1          |                 | Ticket     | Priority                                  | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | PriorityID                                | NUMERIC   |
      | 1            | 1          |                 | Ticket     | Queue                                     | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | QueueID                                   | NUMERIC   |
      | 1            | 1          |                 | Ticket     | Responsible                               | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | ResponsibleFulltext                       | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | ResponsibleID                             | NUMERIC   |
      | 1            | 1          |                 | Ticket     | ResponsibleName                           | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | ResponsibleOutOfOffice                    | NUMERIC   |
      | 1            | 0          |                 | Ticket     | SenderType                                | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | SenderTypeID                              | NUMERIC   |
      | 1            | 1          |                 | Ticket     | State                                     | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | StateID                                   | NUMERIC   |
      | 1            | 0          |                 | Ticket     | StateType                                 | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | StateTypeID                               | NUMERIC   |
      | 1            | 0          |                 | Ticket     | Subject                                   | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | TicketFlag.Seen                           | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | TicketID                                  | NUMERIC   |
      | 1            | 1          |                 | Ticket     | TicketNumber                              | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | Title                                     | TEXTUAL   |
      | 1            | 0          |                 | Ticket     | To                                        | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | Type                                      | TEXTUAL   |
      | 1            | 1          |                 | Ticket     | TypeID                                    | NUMERIC   |
      | 1            | 0          |                 | Ticket     | WatcherUserID                             | NUMERIC   |









