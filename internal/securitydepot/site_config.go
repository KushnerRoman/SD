package securitydepot

import (
	"errors"
	"fmt"
	"strings"
)

type StreamKind string

const (
	StreamMain StreamKind = "main"
	StreamSub  StreamKind = "sub"
)

type SiteConfig struct {
	Site      SiteInfo        `json:"site" yaml:"site"`
	NVR       NVRConfig       `json:"nvr" yaml:"nvr"`
	Channels  []ChannelConfig `json:"channels" yaml:"channels"`
	Emulation EmulationConfig `json:"emulation" yaml:"emulation"`
	Fallback  FallbackConfig  `json:"fallback" yaml:"fallback"`
}

type SiteInfo struct {
	Name  string `json:"name" yaml:"name"`
	Notes string `json:"notes,omitempty" yaml:"notes,omitempty"`
}

type NVRConfig struct {
	Vendor       string `json:"vendor" yaml:"vendor"`
	Address      string `json:"address" yaml:"address"`
	HTTPPort     int    `json:"http_port" yaml:"http_port"`
	RTSPPort     int    `json:"rtsp_port" yaml:"rtsp_port"`
	ONVIFPort    int    `json:"onvif_port" yaml:"onvif_port"`
	Username     string `json:"username" yaml:"username"`
	Password     string `json:"password,omitempty" yaml:"password,omitempty"`
	Model        string `json:"model,omitempty" yaml:"model,omitempty"`
	Firmware     string `json:"firmware,omitempty" yaml:"firmware,omitempty"`
	ChannelCount int    `json:"channel_count" yaml:"channel_count"`
}

type ChannelConfig struct {
	Enabled     bool   `json:"enabled" yaml:"enabled"`
	Number      int    `json:"number" yaml:"number"`
	Name        string `json:"name" yaml:"name"`
	CameraModel string `json:"camera_model,omitempty" yaml:"camera_model,omitempty"`
	MainRTSP    string `json:"main_rtsp,omitempty" yaml:"main_rtsp,omitempty"`
	SubRTSP     string `json:"sub_rtsp,omitempty" yaml:"sub_rtsp,omitempty"`
	Codec       string `json:"codec,omitempty" yaml:"codec,omitempty"`
	Resolution  string `json:"resolution,omitempty" yaml:"resolution,omitempty"`
}

type EmulationConfig struct {
	ProfileID    string `json:"profile_id" yaml:"profile_id"`
	Manufacturer string `json:"manufacturer,omitempty" yaml:"manufacturer,omitempty"`
	Model        string `json:"model,omitempty" yaml:"model,omitempty"`
	Firmware     string `json:"firmware,omitempty" yaml:"firmware,omitempty"`
}

type FallbackConfig struct {
	Enabled          bool   `json:"enabled" yaml:"enabled"`
	MediaPath        string `json:"media_path,omitempty" yaml:"media_path,omitempty"`
	CheckInterval    string `json:"check_interval" yaml:"check_interval"`
	PrimaryStableFor string `json:"primary_stable_for" yaml:"primary_stable_for"`
}

type ScanResult struct {
	Vendor       string              `json:"vendor"`
	Model        string              `json:"model"`
	Firmware     string              `json:"firmware"`
	ChannelCount int                 `json:"channel_count"`
	Channels     []ChannelSuggestion `json:"channels"`
	Warnings     []string            `json:"warnings,omitempty"`
}

type ChannelSuggestion struct {
	Number      int    `json:"number"`
	Name        string `json:"name,omitempty"`
	CameraModel string `json:"camera_model,omitempty"`
	MainRTSP    string `json:"main_rtsp,omitempty"`
	SubRTSP     string `json:"sub_rtsp,omitempty"`
	Codec       string `json:"codec,omitempty"`
	Resolution  string `json:"resolution,omitempty"`
}

func DefaultSiteConfig() SiteConfig {
	return SiteConfig{
		Site: SiteInfo{
			Name: "Security Depot Gateway",
		},
		NVR: NVRConfig{
			Vendor:       "hikvision",
			HTTPPort:     80,
			RTSPPort:     554,
			ONVIFPort:    80,
			ChannelCount: 16,
		},
		Emulation: EmulationConfig{
			ProfileID: "hikvision-ds7616ni-16",
		},
		Fallback: FallbackConfig{
			Enabled:          true,
			CheckInterval:    "10s",
			PrimaryStableFor: "20s",
		},
	}
}

func (c SiteConfig) Validate() error {
	var problems []string

	if strings.TrimSpace(c.NVR.Address) == "" {
		problems = append(problems, "nvr address is required")
	}
	if c.NVR.RTSPPort <= 0 {
		problems = append(problems, "nvr rtsp port is required")
	}

	enabledCount := 0
	for _, channel := range c.Channels {
		if !channel.Enabled {
			continue
		}

		enabledCount++
		if channel.Number <= 0 {
			problems = append(problems, "enabled channel number must be positive")
		}
		if channel.MainRTSP == "" && channel.SubRTSP == "" {
			problems = append(problems, fmt.Sprintf("channel %d needs main or sub rtsp url", channel.Number))
		}
	}
	if enabledCount == 0 {
		problems = append(problems, "at least one enabled channel is required")
	}

	if len(problems) > 0 {
		return errors.New(strings.Join(problems, "; "))
	}
	return nil
}

func MergeScanSuggestions(current SiteConfig, suggestions ScanResult) SiteConfig {
	merged := current

	if merged.NVR.Vendor == "" {
		merged.NVR.Vendor = suggestions.Vendor
	}
	if merged.NVR.Model == "" {
		merged.NVR.Model = suggestions.Model
	}
	if merged.NVR.Firmware == "" {
		merged.NVR.Firmware = suggestions.Firmware
	}
	if merged.NVR.ChannelCount == 0 {
		merged.NVR.ChannelCount = suggestions.ChannelCount
	}

	channelIndex := map[int]int{}
	for i, channel := range merged.Channels {
		channelIndex[channel.Number] = i
	}

	for _, suggestion := range suggestions.Channels {
		if idx, ok := channelIndex[suggestion.Number]; ok {
			mergeChannelSuggestion(&merged.Channels[idx], suggestion)
			continue
		}

		merged.Channels = append(merged.Channels, ChannelConfig{
			Enabled:     true,
			Number:      suggestion.Number,
			Name:        firstNonEmpty(suggestion.Name, fmt.Sprintf("Channel %d", suggestion.Number)),
			CameraModel: suggestion.CameraModel,
			MainRTSP:    suggestion.MainRTSP,
			SubRTSP:     suggestion.SubRTSP,
			Codec:       suggestion.Codec,
			Resolution:  suggestion.Resolution,
		})
	}

	return merged
}

func mergeChannelSuggestion(channel *ChannelConfig, suggestion ChannelSuggestion) {
	if channel.Name == "" {
		channel.Name = suggestion.Name
	}
	if channel.CameraModel == "" {
		channel.CameraModel = suggestion.CameraModel
	}
	if channel.MainRTSP == "" {
		channel.MainRTSP = suggestion.MainRTSP
	}
	if channel.SubRTSP == "" {
		channel.SubRTSP = suggestion.SubRTSP
	}
	if channel.Codec == "" {
		channel.Codec = suggestion.Codec
	}
	if channel.Resolution == "" {
		channel.Resolution = suggestion.Resolution
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}
