package db

import (
	"backend/config"
	"database/sql"
	"fmt"
	_ "github.com/lib/pq"
	"os"
)

type PostgresConfig struct {
	Host     string
	Port     int32
	Username string
	Password string
	Database string
}

type PostgresDB struct {
	pgconfig *PostgresConfig
	pgconn   *sql.DB
}

func (p *PostgresDB) getConnectionDetails(connectionConfigName string) error {
	dbConfig, err := config.GetConnectionConfigByName(connectionConfigName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting connection config: %v\n", err)
		return err
	}
	if dbConfig == nil {
		fmt.Fprintf(os.Stderr, "No connection config found for name: %s\n", connectionConfigName)
		return fmt.Errorf("no connection config found for name: %s", connectionConfigName)
	}
	p.pgconfig = &PostgresConfig{
		Host:     dbConfig.Host,
		Port:     dbConfig.GetPort(),
		Username: dbConfig.Username,
		Password: dbConfig.Password,
		Database: dbConfig.Database,
	}
	return nil
}

func (p *PostgresDB) Connect(connectionConfigName string) error {
	if err := p.getConnectionDetails(connectionConfigName); err != nil {
		return err
	}
	uri := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", p.pgconfig.Host, p.pgconfig.Port, p.pgconfig.Username, p.pgconfig.Password, p.pgconfig.Database)

	db, err := sql.Open("postgres", uri)
	if err != nil {
		return err
	}
	p.pgconn = db
	return db.Ping()

}

func (p *PostgresDB) Query(query string) (*sql.Rows, error) {
	return p.pgconn.Query(query)
}

func (p *PostgresDB) FormatResults(results *sql.Rows) ([]map[string]any, error) {

	//Getting Columns
	columns, err := results.Columns()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to scan: %v\n", err)
		return nil, err
	}

	// Initialize the result map
	result := make(map[string][]any)
	for _, col := range columns {
		result[col] = []any{}
	}

	var formattedResults []map[string]any

	for results.Next() {
		values := make([]any, len(columns))
		valuesPtrs := make([]any, len(columns))

		for i := range values {
			valuesPtrs[i] = &values[i]
		}

		if err := results.Scan(valuesPtrs...); err != nil {
			fmt.Fprintf(os.Stderr, "failed to scan: %v\n", err)
			return nil, err
		}

		rowMap := make(map[string]any)
		for i, colName := range columns {
			val := values[i]
			switch v := val.(type) {
			case string:
				val = string(v)
			case []byte:
				val = string(v)
			default:
				val = v
			}
			rowMap[colName] = val
		}
		formattedResults = append(formattedResults, rowMap)
	}
	if err := results.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error iterating rows: %v\n", err)
		return nil, err
	}
	return formattedResults, nil
}

func (p *PostgresDB) PrintResults(results *sql.Rows) error {

	//Getting Columns
	columns, err := results.Columns()
	if err != nil {
		return err
	}
	fmt.Fprintln(os.Stderr, "Columns:", columns)

	//Printing Rows
	values := make([]any, len(columns))
	for i := range values {
		values[i] = new(any)
	}

	for results.Next() {
		if err := results.Scan(values...); err != nil {
			return err
		}

		for _, v := range values {
			val := *(v.(*any))
			switch v := val.(type) {
			case string:
				fmt.Fprintf(os.Stderr, "%s\t", v)
			case []byte:
				fmt.Fprintf(os.Stderr, "%s\t", v)
			default:
				fmt.Fprintf(os.Stderr, "%v\t", v)
			}
		}
		fmt.Fprintln(os.Stderr)
	}
	if err := results.Err(); err != nil {
		return err
	}
	return nil
}

func (p *PostgresDB) Close() error {
	return p.pgconn.Close()
}

func (p *PostgresDB) IsActive() bool {
	err := p.pgconn.Ping()
	if err != nil {
		return false
	}
	return true
}
