package main

import (
	"fmt"
	"os"

	"github.com/neovim/go-client/msgpack/rpc"

	config "backend/config"
	db "backend/db"
)

type NakshaServer struct {
	sessionManager *db.SessionService
}

func NewNakshaServer() *NakshaServer {
	return &NakshaServer{
		sessionManager: db.NewSessionService(),
	}
}

func (s *NakshaServer) HandlePutConnectionConfig(params map[string]interface{}) (interface{}, error) {
	name, _ := params["name"].(string)
	host, _ := params["host"].(string)
	port, _ := params["port"].(float64)
	database, _ := params["database"].(string)
	username, _ := params["username"].(string)
	password, _ := params["password"].(string)
	clusterType, _ := params["clusterType"].(string)

	dbConfig := config.DBConfig{
		Name:        name,
		Host:        host,
		Port:        port,
		Database:    database,
		Username:    username,
		Password:    password,
		ClusterType: clusterType,
	}

	err := config.PutConnectionConfig(dbConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to put connection config: %v", err)
	}
	return map[string]interface{}{"status": "success"}, nil
}

func (s *NakshaServer) HandleListConnectionConfigs() (interface{}, error) {
	configs, err := config.ListConnectionConfigs()
	if err != nil {
		return nil, fmt.Errorf("failed to list connection configs: %v", err)
	}
	return map[string]interface{}{"configlist": configs}, nil
}

func (s *NakshaServer) HandleCreateSession(params map[string]interface{}) (interface{}, error) {
	connectionConfigName, _ := params["connectionConfigName"].(string)
	sessionId, err := s.sessionManager.CreateSession(connectionConfigName)
	if err != nil {
		return nil, fmt.Errorf("failed to create session: %v", err)
	}
	return map[string]interface{}{"session_id": sessionId}, nil
}

func (s *NakshaServer) HandleRunQuery(params map[string]interface{}) (interface{}, error) {
	sessionId, _ := params["session_id"].(string)
	query, _ := params["query"].(string)

	results, err := s.sessionManager.RunQuery(sessionId, query)
	if err != nil {
		return nil, fmt.Errorf("failed to run query: %v", err)
	}
	return map[string]interface{}{
		"session_id": sessionId,
		"query":      query,
		"status":     "success",
		"results":    results,
	}, nil
}

func main() {
	if len(os.Args) > 1 {
		config.SetConfigFilename(os.Args[1] + "/dbconfig.json")
	}

	server := NewNakshaServer()

	endpoint, err := rpc.NewEndpoint(os.Stdin, os.Stdout, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating endpoint: %v\n", err)
		os.Exit(1)
	}

	endpoint.Register("put_connection_config", server.HandlePutConnectionConfig)
	endpoint.Register("list_connection_configs", server.HandleListConnectionConfigs)
	endpoint.Register("create_session", server.HandleCreateSession)
	endpoint.Register("run_query", server.HandleRunQuery)

	if err := endpoint.Serve(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	}
}
