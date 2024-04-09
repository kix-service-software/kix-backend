 Feature: GET request to the /system/ticket/queues  resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

   Scenario Outline: check is the existing queues are consistent with the delivery defaults
     When I query the collection of ticket queues
     Then the response code is 200
     Then the queues output is "<Name>"

     Examples:
       | Name         | ValidID |
       | Service Desk | 1       |
       | Monitoring   | 1       |
       | Junk         | 1       |

  Scenario: check is the existing queues are consistent with the delivery defaults
    When I query the collection of ticket queues
    Then the response code is 200
#    And the response object is QueueCollectionResponse
    Then the response contains 3 items of type "Queue"
    And the response contains the following items of type Queue
      | Name         | ValidID |
      | Service Desk | 1       |
      | Monitoring   | 1       |
      | Junk         | 1       |

