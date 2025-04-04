 Feature: GET request to the /system/config resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
        
  Scenario: get the list of existing config
    When I query the collection of config "ITSMConfigItem::Hook"
    Then the response code is 200
    Then the response contains the following items type of SysConfigOption
        | Value |
        | A#    |

   Scenario: get the list of existing config (PostmasterDefaultQueue)
    When I query the collection of config "PostmasterDefaultQueue"
     Then the response code is 200
     Then the response contains the following items type of SysConfigOption
       | Name                   | Value         | AccessLevel |
       | PostmasterDefaultQueue | Service Desk  | internal    |

   Scenario: get the list of existing config (TicketStateWorkflow)
     When I query the collection of config "TicketStateWorkflow"
     Then the response code is 200
     Then the response contains the following items type of SysConfigOption
       | Name                | AccessLevel |
       | TicketStateWorkflow | internal    |

   Scenario: get the list of existing config (TicketStateWorkflow_value)
     When I get the attribute in config "TicketStateWorkflow"
     Then the response code is 200
     Then the response contains the following "TicketStateWorkflow" Values
       | merged | new   | pending auto close | pending reminder | removed |
       | _NONE_ | _ANY_ | _PREVIOUS_,closed  | _ANY_            | _NONE_  |

   Scenario: get the list of existing config (Ticket::StateAfterPending)
     When I query the collection of config "Ticket::StateAfterPending"
     Then the response code is 200
     Then the response contains the following items type of SysConfigOption
       | Name                      | AccessLevel |
       | Ticket::StateAfterPending | internal    |

   Scenario: get the list of existing config (Ticket::StateAfterPending_value)
     When I get the attribute in config "Ticket::StateAfterPending"
     Then the response code is 200
     Then the response contains the following "Ticket::StateAfterPending" Values
       | pending auto close |
       | closed             |

   Scenario: get the list of existing config (TicketStateWorkflow::PostmasterFollowUpState)
     When I query the collection of config "TicketStateWorkflow::PostmasterFollowUpState"
     Then the response code is 200
     Then the response contains the following items type of SysConfigOption
       | Name                                         | AccessLevel |
       | TicketStateWorkflow::PostmasterFollowUpState | internal    |

   Scenario: get the list of existing config (TicketStateWorkflow::PostmasterFollowUpState_value)
     When I get the attribute in config "TicketStateWorkflow::PostmasterFollowUpState"
     Then the response code is 200
     Then the response contains the following "TicketStateWorkflow::PostmasterFollowUpState" Values
       | closed | pending auto close | pending reminder |
       | open   | open               | open             |

  Scenario: get the list of existing config ForceOwnerAndResponsibleResetOnMissingPermission
    When I query the collection of sysconfig "Ticket::EventModulePost###100-ForceOwnerAndResponsibleResetOnMissingPermission"
    Then the response code is 200
    Then the response contains the following sysconfig entrys of "SysConfigOption"
      | Context | ContextMetadata | AccessLevel | ReadOnly | Name                    |
      |         |                 |             | 0        | Ticket::EventModulePost |

   Scenario: SysConfigOption ITSM::Core::IncidentLinkTypeDirection
     When I query this SysConfigOption "ITSM::Core::IncidentLinkTypeDirection"
     Then the response code is 200
     Then the response contains the following items type of SysConfigOption
       | Name                                  | AccessLevel |
       | ITSM::Core::IncidentLinkTypeDirection | internal    |

   Scenario: SysConfigOption ITSM::Core::IncidentLinkTypeDirection Value
     When I query this SysConfigOption "ITSM::Core::IncidentLinkTypeDirection"
     Then the response code is 200
     Then response contains the following items type of Value
       | ConnectedTo | DependsOn |
       | Both        | Source    |
      
      
      

