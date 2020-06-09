 Feature: GET request to the /system/ticket/queues/:QueueID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing ticket queue
    Given a ticket queue
    Then the response code is 201
    When I get this ticket queue
    Then the response code is 200
    And the attribute "Queue.Comment" is "Postmaster queue."
#    And the response object is QueueResponse
    When I delete this ticket queue
    Then the response code is 204
    
  Scenario: get a existing ticket queue Service Desk include subqueue Monitoring
    When I get the ticket queue include subqueues with ID 1
    Then the response code is 200
    Then the response contains the following queueid of type "SubQueue"
      | SubQueue |
      | 2        |    
    
  Scenario: get a existing ticket queue Service Desk include subqueue Monitoring
    When I get the ticket queue include and expand subqueues with ID 1
    Then the response code is 200
    Then the response contains the following queue items of type "SubQueue" 
      | Name       | Fullname                 | Comment                       | QueueID |
      | Monitoring | Service Desk::Monitoring | Incoming monitoring messages. | 2       |         
    
    
    
    