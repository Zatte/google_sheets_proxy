// ## License
// Copyright 2020 Mikael Rapp
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and

package main

import (
	"log"
	"net/http"
	"time"

	"github.com/zatte/google_sheets_proxy"
)

var Version = "SNAPSHOT"

func main() {
	s := &http.Server{
		Addr:           ":8085",
		Handler:        http.HandlerFunc(google_sheets_proxy.GoogleSheetProxy),
		ReadTimeout:    30 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	log.Fatal(s.ListenAndServe())
}
