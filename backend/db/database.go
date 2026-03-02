package db

import "database/sql"

type Database interface {
  getConnectionDetails(connectionConfigName string) (error)
  Connect(uri string) error
  Query(query string) (*sql.Rows, error)
  FormatResults (results *sql.Rows) ([]map[string]any, error)
  PrintResults (results *sql.Rows) error
  Close() error
  IsActive() bool 
}
