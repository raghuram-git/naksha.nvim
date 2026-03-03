//TODO: These can be removed, as frontend/lua handles creating connection Configs

package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
)

type DBConfig struct {
	Name        string      `json:"name"`
	Host        string      `json:"host"`
	Port        interface{} `json:"port"`
	Username    string      `json:"username"`
	Password    string      `json:"password"`
	Database    string      `json:"database"`
	ClusterType string      `json:"clusterType"`
}

func (c DBConfig) GetPort() int32 {
	switch v := c.Port.(type) {
	case float64:
		return int32(v)
	case string:
		p, _ := strconv.Atoi(v)
		return int32(p)
	}
	return 0
}

var configFilename string = ""

func getConfigFilename() string {
	if configFilename != "" {
		return configFilename
	}
	execPath, err := os.Executable()
	if err != nil {
		return "connections.json"
	}
	execDir := filepath.Dir(execPath)
	return filepath.Join(execDir, "connections.json")
}


func SetConfigFilename(path string) {
	configFilename = path
}

func PutConnectionConfig(config DBConfig) error {
	// Read existing configs
	var configs []DBConfig
	data, err := os.ReadFile(getConfigFilename())
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("config file does not exist")
		}
		return fmt.Errorf("error reading config file: %v", err)
	}
	if err == nil && len(data) > 0 {
		if err := json.Unmarshal(data, &configs); err != nil {
			return fmt.Errorf("error unmarshalling existing config: %v", err)
		}
	} else if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("error reading config file: %v", err)
	}

	// Check if config with the same name exists and update it, else append
	updated := false
	for i, existing := range configs {
		if existing.Name == config.Name {
			configs[i] = config
			updated = true
			break
		}
	}
	if updated {
		fmt.Fprintf(os.Stderr, "Updating existing config with name: %s\n", config.Name)
	} else {
		fmt.Fprintf(os.Stderr, "Adding new config with name: %s\n", config.Name)
		configs = append(configs, config)
	}

	// Marshal and overwrite file
	newData, err := json.MarshalIndent(configs, "", "  ")
	if err != nil {
		return fmt.Errorf("error marshalling config: %v", err)
	}

	err = os.WriteFile(getConfigFilename(), newData, 0644)
	if err != nil {
		return fmt.Errorf("error writing config to file: %v", err)
	}

	return nil
}

func GetConnectionConfigType(name string) (string, error) {
	var configs []DBConfig
	data, err := os.ReadFile(getConfigFilename())
	if err != nil {
		return "", fmt.Errorf("error reading config file: %v", err)
	}
	if err := json.Unmarshal(data, &configs); err != nil {
		return "", fmt.Errorf("error unmarshalling config: %v", err)
	}
	for _, cfg := range configs {
		if cfg.Name == name {
			return cfg.ClusterType, nil
		}
	}
	return "", fmt.Errorf("config with name %s not found", name)
}

func GetConnectionConfigByName(name string) (*DBConfig, error) {
	var configs []DBConfig
	data, err := os.ReadFile(getConfigFilename())
	if err != nil {
		return nil, fmt.Errorf("error reading config file: %v", err)
	}
	if err := json.Unmarshal(data, &configs); err != nil {
		return nil, fmt.Errorf("error unmarshalling config: %v", err)
	}
	for _, cfg := range configs {
		if cfg.Name == name {
			return &cfg, nil
		}
	}
	return nil, fmt.Errorf("config with name %s not found", name)
}

func ListConnectionConfigs() ([]DBConfig, error) {
	var configs []DBConfig
	data, err := os.ReadFile(getConfigFilename())
	if err != nil {
		return nil, fmt.Errorf("error reading config file: %v", err)
	}
	if err := json.Unmarshal(data, &configs); err != nil {
		return nil, fmt.Errorf("error unmarshalling config: %v", err)
	}
	return configs, nil
}
