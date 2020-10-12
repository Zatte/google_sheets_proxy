# Google sheets (basic auth) proxy

Simple POC of adding basic auth protection to google sheets exports (as this is not provided natively). Can be deployed as a cloud function to be serverless.

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

## Usage / Installation

To use the service you need to:
0) Enable the sheets API in you GCP project
1) Deploy the service with a google application service account that have permissions to work with the Sheets API
2) Any document you want to share through the service; add the service-account email as an (viewer) user.
3) Query the endpoint with `?sheetId=........` set to the id
4) The endpoint will return an error `unable to find password-tab: 9a94f6.......ca7087_allowed_logins` ;
5) ensure the tab-name from #4 it exists (this is a document-specific opt in for public sharing); Create a tab with that name containging 3 columns "User", "Password", "Range". User will be the Basic Auth user-name; Password must be a valid [bcrypt](https://bcrypt-generator.com/) password and the range contains a range reference that will be exported, including sheetName, e.g `Sheet1!A:C`

Not tested for production use; only a proof of concept.
