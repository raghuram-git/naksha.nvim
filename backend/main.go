package main

import (
	"encoding/json"
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
	callbackId, _ := params["callback_id"].(string)

	go func() {
		sessionId, err := s.sessionManager.CreateSession(connectionConfigName)
		response := map[string]interface{}{}
		if err != nil {
			response["error"] = err.Error()
		} else {
			response["session_id"] = sessionId
		}
		callbackData := map[string]interface{}{
			"callback_id": callbackId,
			"result":      response,
		}
		jsonData, _ := json.Marshal(callbackData)
		fmt.Fprintf(os.Stderr, "NAKSHA_CALLBACK:%s\n", jsonData)
	}()

	return nil, nil
}

func (s *NakshaServer) HandleRunQuery(params map[string]interface{}) (interface{}, error) {
	sessionId, _ := params["session_id"].(string)
	query, _ := params["query"].(string)
	callbackId, _ := params["callback_id"].(string)

	go func() {
		results, err := s.sessionManager.RunQuery(sessionId, query, callbackId)
		response := map[string]interface{}{
			"session_id": sessionId,
			"query":      query,
		}
		if err != nil {
			response["error"] = err.Error()
		} else {
			response["results"] = results
		}
		callbackData := map[string]interface{}{
			"callback_id": callbackId,
			"result":      response,
		}
		jsonData, _ := json.Marshal(callbackData)
		fmt.Fprintf(os.Stderr, "NAKSHA_CALLBACK:%s\n", jsonData)
	}()

	return nil, nil
}

func (s *NakshaServer) HandleCancelQuery(params map[string]interface{}) (interface{}, error) {
	callbackId, ok := params["callback_id"].(string)
	if !ok || callbackId == "" {
		return map[string]interface{}{"error": "invalid callback_id"}, nil
	}

	err := s.sessionManager.CancelQuery(callbackId)
	if err != nil {
		return map[string]interface{}{"error": err.Error()}, nil
	}

	return map[string]interface{}{"status": "cancelled"}, nil
}

func main() {
	if len(os.Args) > 1 {
		config.SetConfigFilename(os.Args[1] + "/connections.json")
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
	endpoint.Register("cancel_query", server.HandleCancelQuery)

	if err := endpoint.Serve(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	}
}
