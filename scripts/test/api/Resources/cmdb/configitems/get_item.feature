Feature: GET request to the /cmdb/configitems resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing configitem
    Given a configitem
    When I get this configitem
    Then the response code is 200
    And the attribute "ConfigItem.CurDeplState" is "Production"
#    And the response object is ConfigItemResponse
    When I delete this configitem
    Then the response code is 204
    And the response has no content

#  Scenario: get an existing configitem include images
#    Given a configitem
#    When I get this configitem include images
#    Then the response code is 200
#    And the response contains the following items of type Organisation
#      | Comment  | ConfigItemID            | ContentType | Filename | ID |
#      | MY_ORGA | My Organisation |
#    When I delete this configitem
#    Then the response code is 204
#    And the response has no content
    
