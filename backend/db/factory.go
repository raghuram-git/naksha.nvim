package db

import "fmt"

func NewDatabase(dbType, connectionConfigName string) (Database, error) {
  var database Database

  switch dbType {
  case "postgres":
    database = &PostgresDB{}
  default:
    return nil, fmt.Errorf("unsupported database type: %s", dbType)
  }

  if err := database.Connect(connectionConfigName); err != nil {
    return nil, err
  }
  
  return database, nil
}
