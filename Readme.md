# Google sheets (basic auth) proxy

Simple POC of adding basic auth protection to google sheets exports (as this is not provided natively). Can be deployed as a cloud function or to be serverless. A slightly better alternative to publishing documents completely open.

## License
Copyright 2020 Mikael Rapp

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Usage
To share an access to a document through this service, there is a double opt-in required. 1 Granting the service access to read the whole document. 2) defining what ranges different (BasicAuth) users should be able to access.

1) In the document you want to share; add the service-account email as an (viewer) user; the default service-account email is `google-sheets-proxy@${GCP_PROJECT}.iam.gserviceaccount.com`
2) Query the endpoint with `?sheetId=........` set to the ID of the google sheet you want to make public under Basic Auth. Provide any BasicAuth Credientials 

`curl test:test@https://europe-west3-${GCP_PROJECT}.cloudfunctions.net/GoogleSheetProxy?sheedId=............`

3) The endpoint will likely return an error `unable to find password-tab: 9a94f6.......ca7087_allowed_logins` ;
4) ensure the tab-name from #4 it exists. The name is unique to each document id; changing the document ID (as with copies) requires a new tab; The tab must contains 3 columns "User", "Password", "Range". Password must be a valid [bcrypt](https://bcrypt-generator.com/) password and the Range must be a valid reference (e.g. `Sheet1!A:C`). The service will return the first use/pass match and export the range. 

Output format default to JSON but can be changed to csv with an `Accept-Content: application/csv` - Header

Not tested for production use; only a proof of concept.


## Example
This document is public for demo-purposes but the export would work the same if it was not. As long as the service-account email has acccess to the document it will work.
[https://docs.google.com/spreadsheets/d/1xUf5-FQBig7eJHjVG0DHdnREltn4bNeTNMxAgtJ6SHs/edit#gid=0](https://docs.google.com/spreadsheets/d/1xUf5-FQBig7eJHjVG0DHdnREltn4bNeTNMxAgtJ6SHs/edit#gid=0
)

Basic auth protected export are available (controlled by the tab `5a418c78f531a18aca5c4733ec665b93_allowed_logins` in the above document) with users test:test(exposes col A:C) and test2:test(exposes column C:C)
[https://europe-west3-kvantic-dev-rapp.cloudfunctions.net/GoogleSheetProxy?sheetId=1xUf5-FQBig7eJHjVG0DHdnREltn4bNeTNMxAgtJ6SHs](https://europe-west3-kvantic-dev-rapp.cloudfunctions.net/GoogleSheetProxy?sheetId=1xUf5-FQBig7eJHjVG0DHdnREltn4bNeTNMxAgtJ6SHs
)


## Installation - Google Cloud functions

0) Enable the sheets API in you GCP project
1) Deploy the service (requires an authenticated google cloud cli)
`make service-account`
`make deploy-gcp-cloud-function`

## NB
THIS IS A PRROF OF CONCEPT

1) No rate limits implemented so brute force attacks could rack up high (sheets) API costs or hit rate limits causing DOS.
2) No domain lock, the service will access any document that is shared with it no matter who owns it in whoever organization.
3) Ensure your passwords are random, at least 20 characters alpha-numeric length, this is mean for machine to machine communication, no point in having weak passwords.
4) Yes, "export" users and passwords are vissible (though bcrypted) to all who have access to the exported document. This is a flexibility/security tradeoff you might want to consider if it works in your context.