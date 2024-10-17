//Prerequisites
// vIDM Server must be added as REST Host in vRealize Orchestrator
// vIDM username must be provided as action input
// vIDM password must be provided as action input
// Rest Host must be provided as action input 
if(username && password && restHost){
  // Get Token
  var requestType = "POST";
  var operationUrl = "SAAS/auth/oauthtoken?grant_type=client_credentials&client_id=" +username + "&client_secret=" + password;
  var request = restHost.createRequest(requestType, operationUrl, null);
  request.setHeader("Content-type","application/json");
  var response = request.execute();
  if(response.statusCode != 200) throw "REST request failed with staus code "+response.statusCode+"\r\nResponse is: "+response.contentAsString;
  var json = JSON.parse(response.contentAsString);
  idmToken = json.access_token;
}
if(idmToken) return idmToken;
return null;