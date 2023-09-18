package google_sheets_proxy

import (
	"crypto/sha256"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/sheets/v4"
)

// something random
const defaultHashSalt = "fd1l01nx707ösa0<,öqåU1"

// GoogleSheetProxy is an HTTP Cloud Function interface; can be deployeed serverless in GCP
func GoogleSheetProxy(w http.ResponseWriter, r *http.Request) {
	// Require Auth
	user, password, ok := r.BasicAuth()
	if !ok {
		w.Header().Set("WWW-Authenticate", `Basic realm="Google Sheet Proxy"`)
		w.WriteHeader(401)
		w.Write([]byte("Unauthorised.\n"))
		return
	}

	// Require ?sheetId=....
	queryParams := r.URL.Query()
	spreadsheetID := queryParams.Get("sheetId")
	if spreadsheetID == "" {
		fmt.Fprintf(w, "error: no sheetId parameter")
		return
	}

	srv, err := sheets.NewService(r.Context())
	if err != nil {
		log.Fatalf("Unable to retrieve Sheets client: %v", err)
	}

	// Check password
	passwordSheet := getPasswordSheetName(r.URL.Path)
	readRange := passwordSheet + "!A1:C" //TODO: move to const
	resp, err := srv.Spreadsheets.Values.Get(spreadsheetID, readRange).Do()
	if err != nil {
		if strings.Contains(err.Error(), "403") { // TODO: introspect the error rather than string search...uck
			// TODO: Read out SVC_ACC_EMAIL from environment context (GOOGLE_APPLICATION_CREDENTIALS file)
			fmt.Fprintf(w, "error: no access to sheet, ensure that %s have reader access to the document", getEnvOrDefault("SVC_ACC_EMAIL", "service account"))
			return
		}
		fmt.Fprintf(w, "unable to find password-tab: "+passwordSheet+"; ensure it exists to grant read access: %v", err)
		return
	}
	if len(resp.Values) == 0 {
		w.WriteHeader(403)
		fmt.Println("no password sheet found, no users exists")
		return
	}
	for index, row := range resp.Values {
		if index == 0 {
			if len(row) != 3 || row[0] != "User" || row[1] != "Password" || row[2] != "Range" {
				w.WriteHeader(401)
				fmt.Fprintf(w, "incorrect username headers; expected User/Password/Range (Exactly)")
				return
			}
		} else if row[0] == user && bcrypt.CompareHashAndPassword([]byte(row[1].(string)), []byte(password)) == nil {
			exportSheet(w, r, srv, spreadsheetID, fmt.Sprintf("%s", row[2]))
			return
		}
	}

	// Default case 403
	w.WriteHeader(403)
	fmt.Fprintf(w, "incorrect username/password")
	return
}

// exportSheet is responsible for outputting a designated range in the correct format. Must only be invoked after
// authentication & authorization have passed successfully.
func exportSheet(w http.ResponseWriter, r *http.Request, srv *sheets.Service, spreadsheetID, readRange string) {
	resp, err := srv.Spreadsheets.Values.Get(spreadsheetID, readRange).Do()
	if err != nil || resp.Values == nil {
		fmt.Fprintf(w, "Unable to retrieve data from sheet: %v", err)
		return
	}

	format := ""
	if r.Header.Get("Accept") != "" {
		format = r.Header.Get("Accept")
	}

	if r.URL.Query().Get("export_format") != "" {
		format = r.URL.Query().Get("export_format")
	}

	// TODO: More export formats?
	switch format {
	case "application/csv":
		w.Header().Add("Content-Type", "application/csv")
		w := csv.NewWriter(w)
		for _, row := range resp.Values {
			stringRow := make([]string, len(row))
			for i, cell := range row {
				stringRow[i] = string(fmt.Sprintf("%s", cell))
			}
			w.Write(stringRow)
		}
		w.Flush()

	case "json":
		if len(resp.Values) == 0 {
			w.Header().Add("Content-Type", "application/json")
			w.Write([]byte("[]"))
			return
		}
		res := make([]map[string]string, len(resp.Values)-1)
		headerRow := make([]string, len(resp.Values[0]))
		for idx, row := range resp.Values {
			if idx == 0 {
				for i, cell := range row {
					headerRow[i] = string(fmt.Sprintf("%s", cell))
				}
			} else {
				jsonObjRow := map[string]string{}
				for i, header := range headerRow {
					if i < len(row) && row[i] != nil {
						jsonObjRow[header] = string(fmt.Sprintf("%s", row[i]))
					} else {
						jsonObjRow[header] = ""
					}
				}
				res[idx-1] = jsonObjRow
			}
		}
		w.Header().Add("Content-Type", "application/json")
		enc := json.NewEncoder(w)
		enc.Encode(res)
		return

	case "json_arr":
		fallthrough
	case "application/json":
		fallthrough
	default:
		w.Header().Add("Content-Type", "application/json")
		enc := json.NewEncoder(w)
		enc.Encode(resp.Values)
	}
}

// Generate a ~random sheet-name for each spreadhseet so that copied sheets aren't by default exported.
func getPasswordSheetName(sheetID string) string {
	h := sha256.New()
	h.Write([]byte(sheetID + getEnvOrDefault("SALT", defaultHashSalt)))
	return fmt.Sprintf("%x_allowed_logins", h.Sum(nil)[:16])
}

func getEnvOrDefault(key, defaultValue string) string {
	val := os.Getenv(key)
	if len(val) == 0 {
		return defaultValue
	}
	return val
}
