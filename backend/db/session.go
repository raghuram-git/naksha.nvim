package db

import (
	"backend/config"
	"encoding/json"
	"fmt"
	"github.com/google/uuid"
	"os"
	"sync"
)

type SessionService struct {
	dbConnections map[string]Database
	mu            sync.Mutex
}

// Constructor for SessionService
func NewSessionService() *SessionService {
	return &SessionService{
		dbConnections: make(map[string]Database),
	}
}

func (s *SessionService) CreateSession(connectionConfigName string) (string, error) {
	sessionId := uuid.New().String()

	clusterType, err := config.GetConnectionConfigType(connectionConfigName)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error getting connection config:", err)
		return "", err
	}

	if clusterType == "" {
		fmt.Fprintln(os.Stderr, "No connection config found for name:", connectionConfigName)
		return "", fmt.Errorf("no connection config found for name: %s", connectionConfigName)
	}

	dbConn, err := NewDatabase(clusterType, connectionConfigName)
	if err != nil {
		return "", err
	}

	s.mu.Lock()
	s.dbConnections[sessionId] = dbConn
	s.mu.Unlock()

	return sessionId, nil
}

func (s *SessionService) GetConnection(sessionId string) (Database, error) {

	s.mu.Lock()
	dbConn, exists := s.dbConnections[sessionId]
	s.mu.Unlock()

	if !exists {
		fmt.Fprintln(os.Stderr, "Session Not Found")
		return nil, nil
	}

	if !dbConn.IsActive() {
		fmt.Fprintln(os.Stderr, "Session found but not active")
		return nil, nil
	}
	return dbConn, nil

}

func (s *SessionService) CloseSession(sessionId string) error {

	s.mu.Lock()
	dbConn, exists := s.dbConnections[sessionId]

	if !exists {
		s.mu.Unlock()
		fmt.Fprintln(os.Stderr, "Session Not Found")
		return nil
	}

	delete(s.dbConnections, sessionId)
	s.mu.Unlock()
	dbConn.Close()
	return nil
}

func (s *SessionService) RunQuery(sessionId string, query string) (string, error) {

	dbConn, err := s.GetConnection(sessionId)
	if err != nil {
		return "", err
	}

	if dbConn == nil {
		return "", fmt.Errorf("no active session found for id: %s", sessionId)
	}

	rows, err := dbConn.Query(query)
	if err != nil {
		return "", err
	}

	results, err := dbConn.FormatResults(rows)
	if err != nil {
		return "", err
	}
	data, err := json.MarshalIndent(results, "", "  ")
	if err != nil {
		return "", err
	}

	return string(data), nil

}
