 Feature: GET request to the /system/ticket/queues  resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing ticket queues  
    When I query the collection of ticket queues  
    Then the response code is 200
    And the response object is QueueCollectionResponse

  Scenario: get the list of existing ticket queues with filter  
    When I query the collection of ticket queues with filter of Monitoring  
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains the following items of type Queue
      | Name       | ValidID |
      | Monitoring | 1       | 
      
  Scenario: get the list of existing ticket queues with limit  
    When I query the collection of ticket queues with a limit of 2 
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains 2 items of type "Queue"
     
  Scenario: get the list of existing ticket queues with offset  
    When I query the collection of ticket queues with offset 2 
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains 1 items of type "Queue"
     
  Scenario: get the list of existing ticket queues with limit and offset  
    When I query the collection of ticket queues with limit 2 and offset 1 
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains 2 items of type "Queue"
     
  Scenario: get the list of existing ticket queues with sorted  
    When I query the collection of ticket queues with sorted by "Queue.-Name:textual" 
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains 3 items of type "Queue"
    And the response contains the following items of type Queue
      | Name         |
      | Service Desk |
      | Monitoring   | 
      | Junk         | 
           
  Scenario: get the list of existing ticket queues with sorted, limit and offset 
    When I query the collection of ticket queues with sorted by "Queue.-Name:textual" limit 2 and offset 1
    Then the response code is 200
    And the response object is QueueCollectionResponse
    And the response contains 2 items of type "Queue"
    And the response contains the following items of type Queue
      | Name         |
      | Monitoring   | 
      | Junk         |      
     
     
     