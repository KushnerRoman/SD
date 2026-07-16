package securitydepot

import (
	"fmt"
	"net/url"
	"strings"
)

type RTSPTemplate struct {
	ID          string `json:"id"`
	Vendor      string `json:"vendor"`
	Description string `json:"description"`
}

func RTSPTemplatesForVendor(vendor string) []RTSPTemplate {
	switch strings.ToLower(strings.TrimSpace(vendor)) {
	case "hikvision", "hik":
		return []RTSPTemplate{{
			ID:          "hikvision-streaming-channels",
			Vendor:      "hikvision",
			Description: "/Streaming/Channels/{channel}{1 main, 2 sub}",
		}}
	default:
		return nil
	}
}

func HikvisionRTSPURL(nvr NVRConfig, channel int, stream StreamKind) string {
	suffix := 1
	if stream == StreamSub {
		suffix = 2
	}

	user := url.UserPassword(nvr.Username, nvr.Password).String()
	return fmt.Sprintf("rtsp://%s@%s:%d/Streaming/Channels/%d%02d", user, nvr.Address, nvr.RTSPPort, channel, suffix)
}
