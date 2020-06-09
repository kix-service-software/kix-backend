Feature: GET request to the /system/slas/:SLAID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing slas
    Given a sla
    Then the response code is 201
    When I get this sla
    Then the response code is 200
#    And the response object is SlaResponse
    And the attribute "SLA.Comment" is "SLATest1Comment"
    When I delete this sla
    Then the response code is 204

    
